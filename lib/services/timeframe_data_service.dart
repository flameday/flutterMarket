import 'dart:io';
import '../models/price_data.dart';
import '../models/timeframe.dart';
import '../models/trading_pair.dart';
import 'csv_data_service.dart';
import 'log_service.dart';

class TimeframeDataService {
  /// 時間周期に基づいてデータを読み込み
  /// 対応する時間周期のCSVファイルがない場合、5分データからマージして生成
  static Future<List<PriceData>> loadDataForTimeframe(Timeframe timeframe, {TradingPair? tradingPair, int? klineDataLimit}) async {
    final pair = tradingPair ?? TradingPair.eurusd;
    final directoryName = timeframe.getDirectoryName(pair);
    
    // まず対応する時間周期のCSVファイルを読み込もうと試行
    final csvFiles = await CsvDataService.findCsvFiles(directoryName);
    
    if (csvFiles.isNotEmpty) {
      Log.info('TimeframeDataService', '${pair.displayName} ${timeframe.displayName}CSVファイルを発見: ${csvFiles.length}件');
      // 这里应用数据限制，因为这是用于UI显示的数据加载
      final data = await CsvDataService.loadFromMultipleCsvs(csvFiles, klineDataLimit: klineDataLimit);
      Log.info('TimeframeDataService', '${pair.displayName} ${timeframe.displayName}データ読み込み完了: ${data.length}件');
      return data;
    }

    // 対応する時間周期のCSVファイルがない場合、5分データからマージして生成
    Log.info('TimeframeDataService', '${pair.displayName} ${timeframe.displayName}CSVファイルが見つからない、5分データからマージして生成...');
    // 数据合并生成不应用限制，读取所有5分钟数据
    return await _generateTimeframeData(timeframe, pair, klineDataLimit: null);
  }

  /// 5分データからマージして指定時間周期のデータを生成
  static Future<List<PriceData>> _generateTimeframeData(Timeframe targetTimeframe, TradingPair tradingPair, {int? klineDataLimit}) async {
    // 5分データを読み込み（数量制限なし、他の時間周期をマージ生成するため）
    final m5DirectoryName = targetTimeframe.getDirectoryName(tradingPair).replaceAll('/${targetTimeframe.dukascopyCode}', '/m5');
    final m5CsvFiles = await CsvDataService.findCsvFiles(m5DirectoryName);
    
    if (m5CsvFiles.isEmpty) {
      throw Exception('5分CSVファイルが見つからない、${targetTimeframe.displayName}データを生成できません');
    }

    Log.info('TimeframeDataService', '${targetTimeframe.displayName}データ生成のため5分データを読み込み...');
    // 数据合并生成不应用限制，读取所有5分钟数据
    final m5Data = await CsvDataService.loadFromMultipleCsvs(m5CsvFiles, klineDataLimit: null);
    Log.info('TimeframeDataService', '5分データ読み込み完了: ${m5Data.length}件（${targetTimeframe.displayName}データマージ生成用）');

    // 目標時間周期のデータをマージ生成
    final mergedData = _mergeToTimeframe(m5Data, targetTimeframe);
    Log.info('TimeframeDataService', '${targetTimeframe.displayName}データ生成完了: ${mergedData.length}件');

    // 生成されたデータをCSVファイルに保存
    await _saveGeneratedData(mergedData, targetTimeframe, tradingPair);

    return mergedData;
  }

  /// 5分データを指定時間周期のデータにマージ
  static List<PriceData> _mergeToTimeframe(List<PriceData> m5Data, Timeframe targetTimeframe) {
    if (m5Data.isEmpty) return [];

    // 5分足を5分足にマージする必要はない
    if (targetTimeframe.minutes == 5) {
      return m5Data;
    }

    final Map<int, List<PriceData>> groupedByTimeframe = {};
    final int timeframeMillis = targetTimeframe.minutes * 60 * 1000;

    for (final candle in m5Data) {
      // 各5分足キャンドルが属する時間枠の開始タイムスタンプを計算
      final int groupTimestamp = (candle.timestamp ~/ timeframeMillis) * timeframeMillis;
      
      if (!groupedByTimeframe.containsKey(groupTimestamp)) {
        groupedByTimeframe[groupTimestamp] = [];
      }
      groupedByTimeframe[groupTimestamp]!.add(candle);
    }

    final List<PriceData> mergedData = [];
    final sortedKeys = groupedByTimeframe.keys.toList()..sort();

    for (final timestamp in sortedKeys) {
      final candlesToMerge = groupedByTimeframe[timestamp]!;
      if (candlesToMerge.isNotEmpty) {
        // 複数のキャンドルを1つにマージ
        final PriceData mergedCandle = _mergeCandles(candlesToMerge);
        // タイムスタンプを時間枠の開始に設定して新しいPriceDataオブジェクトを作成
        mergedData.add(PriceData(
          timestamp: timestamp,
          open: mergedCandle.open,
          high: mergedCandle.high,
          low: mergedCandle.low,
          close: mergedCandle.close,
          volume: mergedCandle.volume,
        ));
      }
    }

    return mergedData;
  }

  /// 複数のK線データを1つのK線にマージ
  static PriceData _mergeCandles(List<PriceData> candles) {
    if (candles.isEmpty) throw Exception('空のK線データはマージできません');

    final firstCandle = candles.first;
    final lastCandle = candles.last;

    // マージ後のOHLCVデータを計算
    final double open = firstCandle.open;
    final double close = lastCandle.close;
    final double high = candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final double low = candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final double volume = candles.map((c) => c.volume).reduce((a, b) => a + b);

    return PriceData(
      timestamp: firstCandle.timestamp, // 最初のK線のタイムスタンプを使用
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    );
  }

  /// 生成されたデータをCSVファイルに保存
  static Future<void> _saveGeneratedData(List<PriceData> data, Timeframe timeframe, TradingPair tradingPair) async {
    if (data.isEmpty) return;

    // ディレクトリを作成
    final directoryName = timeframe.getDirectoryName(tradingPair);
    final directory = Directory(directoryName);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // 時間周期に基づいてファイルの構成方法を決定
    if (timeframe == Timeframe.m5) {
      // 5分足：日付ごとにグループ化して複数のデータスライスファイルを生成
      final Map<String, List<PriceData>> dataByDate = {};
      for (final item in data) {
        final date = DateTime.fromMillisecondsSinceEpoch(item.timestamp, isUtc: true);
        final dateKey = _formatDate(date);
        
        if (!dataByDate.containsKey(dateKey)) {
          dataByDate[dateKey] = [];
        }
        dataByDate[dateKey]!.add(item);
      }

      // 各日付に対して個別のCSVファイルを生成
      int totalFiles = 0;
      for (final entry in dataByDate.entries) {
        final dateKey = entry.key;
        final dayData = entry.value;
        
        // ファイル名を生成
        final fileName = '${timeframe.getCsvPrefix(tradingPair)}-$dateKey.csv';
        final filePath = '$directoryName/$fileName';

        // CSVファイルに書き込み
        final file = File(filePath);
        final csvContent = _generateCsvContent(dayData);
        await file.writeAsString(csvContent);

        totalFiles++;
        Log.info('TimeframeDataService', '${timeframe.displayName}データスライスを生成: $fileName (${dayData.length}件)');
      }

      Log.info('TimeframeDataService', '${timeframe.displayName}データ保存完了: $totalFiles個のファイル、合計${data.length}件のデータ');
    } else {
      // 30分钟、4小时：生成单个大文件
      final firstTime = DateTime.fromMillisecondsSinceEpoch(data.first.timestamp, isUtc: true);
      final lastTime = DateTime.fromMillisecondsSinceEpoch(data.last.timestamp, isUtc: true);
      
      final fileName = '${timeframe.getCsvPrefix(tradingPair)}-${_formatDate(firstTime)}-${_formatDate(lastTime)}.csv';
      final filePath = '$directoryName/$fileName';

      // CSVファイルに書き込み
      final file = File(filePath);
      final csvContent = _generateCsvContent(data);
      await file.writeAsString(csvContent);

      Log.info('TimeframeDataService', '${timeframe.displayName}データを保存しました: $filePath (${data.length}件)');
    }
  }

  /// CSVコンテンツを生成
  static String _generateCsvContent(List<PriceData> data) {
    final buffer = StringBuffer();
    
    // CSVヘッダーを書き込み
    buffer.writeln('timestamp,open,high,low,close,volume');
    
    // データ行を書き込み
    for (final candle in data) {
      buffer.writeln('${candle.timestamp},${candle.open},${candle.high},${candle.low},${candle.close},${candle.volume}');
    }
    
    return buffer.toString();
  }

  /// 日付をファイル名形式にフォーマット
  static String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 5分足データを指定した時間周期のデータにマージ
  static Future<List<PriceData>> mergeDataForTimeframe(List<PriceData> m5Data, String timeframe) async {
    try {
      // 時間周期に基づいて分数を決定
      int minutes;
      switch (timeframe) {
        case 'm15':
          minutes = 15;
          break;
        case 'm30':
          minutes = 30;
          break;
        case 'h4':
          minutes = 240; // 4時間 = 240分
          break;
        default:
          throw Exception('サポートされていない時間周期です: $timeframe');
      }

      // Timeframeオブジェクトを作成
      final targetTimeframe = Timeframe.values.firstWhere(
        (tf) => tf.minutes == minutes,
        orElse: () => throw Exception('対応する時間周期が見つかりません: $minutes分'),
      );

      // データをマージ
      final mergedData = _mergeToTimeframe(m5Data, targetTimeframe);
      
      Log.info('TimeframeDataService', '$timeframeデータのマージ完了: ${mergedData.length}件');
      return mergedData;
      
    } catch (e) {
      Log.error('TimeframeDataService', '$timeframeデータのマージ失敗: $e');
      return [];
    }
  }
}
