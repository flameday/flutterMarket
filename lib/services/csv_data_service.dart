import 'dart:io';
import 'dart:convert';
import '../models/price_data.dart';
import '../models/trading_pair.dart';
import '../models/timeframe.dart';
import 'log_service.dart';

class CsvDataService {
  /// 指定された取引ペアと時間周期のCSVファイルパスを取得
  static String getCsvFilePath(TradingPair pair, Timeframe timeframe, DateTime date) {
    final String fileName = timeframe.getCsvFileName(pair, date);
    return '${timeframe.getDirectoryName(pair)}/$fileName';
  }

  /// 指定された取引ペアと時間周期のCSVファイルが存在するかチェック
  static Future<bool> csvFileExists(TradingPair pair, Timeframe timeframe, DateTime date) async {
    final String filePath = getCsvFilePath(pair, timeframe, date);
    return await File(filePath).exists();
  }

  /// CSVファイルから価格データを読み込む
  static Future<List<PriceData>> loadFromCsv(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        Log.warning('CsvDataService', 'CSVファイルが存在しません: $filePath');
        return [];
      }

      final lines = await file.readAsLines(encoding: utf8);
      if (lines.isEmpty) {
        Log.warning('CsvDataService', 'CSVファイルが空です: $filePath');
        return [];
      }

      final List<PriceData> data = [];
      
      // ヘッダー行をスキップ（最初の行）
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        try {
          final priceData = _parseCsvLine(line);
          if (priceData != null) {
            data.add(priceData);
          }
        } catch (e) {
          Log.error('CsvDataService', 'CSV行の解析エラー (行 ${i + 1}): $e');
          Log.debug('CsvDataService', '問題のある行: $line');
        }
      }

      Log.info('CsvDataService', 'CSVファイルから読み込み完了: ${data.length}件のデータ');
      if (data.isNotEmpty) {
        final firstTime = DateTime.fromMillisecondsSinceEpoch(data.first.timestamp, isUtc: true);
        final lastTime = DateTime.fromMillisecondsSinceEpoch(data.last.timestamp, isUtc: true);
        Log.info('CsvDataService', 'データ範囲: ${firstTime.toString()} ～ ${lastTime.toString()}');
      }

      return data;
    } catch (e) {
      Log.error('CsvDataService', 'CSVファイル読み込みエラー: $e');
      return [];
    }
  }

  /// CSV行を解析してPriceDataオブジェクトを作成
  static PriceData? _parseCsvLine(String line) {
    final parts = line.split(',');
    if (parts.length < 6) {
      Log.warning('CsvDataService', 'CSV行の列数が不足: ${parts.length}列 (期待値: 6列以上)');
      return null;
    }

    try {
      // dukascopy-nodeのCSV形式: timestamp,open,high,low,close,volume
      final timestamp = int.parse(parts[0]);
      final open = double.parse(parts[1]);
      final high = double.parse(parts[2]);
      final low = double.parse(parts[3]);
      final close = double.parse(parts[4]);
      final volume = double.parse(parts[5]);

      return PriceData(
        timestamp: timestamp,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
      );
    } catch (e) {
      Log.error('CsvDataService', 'CSV行の数値解析エラー: $e');
      Log.debug('CsvDataService', '問題のある行: $line');
      return null;
    }
  }

  /// 指定されたディレクトリ内のCSVファイルを検索
  static Future<List<String>> findCsvFiles(String directoryPath) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        Log.warning('CsvDataService', 'ディレクトリが存在しません: $directoryPath');
        return [];
      }

      final List<String> csvFiles = [];
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.csv')) {
          csvFiles.add(entity.path);
        }
      }

      csvFiles.sort();
      Log.info('CsvDataService', '見つかったCSVファイル: ${csvFiles.length}件');
      for (final file in csvFiles) {
        Log.debug('CsvDataService', '  - $file');
      }

      return csvFiles;
    } catch (e) {
      Log.error('CsvDataService', 'CSVファイル検索エラー: $e');
      return [];
    }
  }

  /// 複数のCSVファイルをマージして読み込む
  static Future<List<PriceData>> loadFromMultipleCsvs(List<String> filePaths, {int? klineDataLimit}) async {
    final List<PriceData> allData = [];

    for (final filePath in filePaths) {
      Log.info('CsvDataService', 'CSVファイルを読み込み中: $filePath');
      final data = await loadFromCsv(filePath);
      allData.addAll(data);
    }

    // 時間順にソート
    allData.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // K線データ制限を適用（最新のデータから指定数だけ取得）
    List<PriceData> finalData = allData;
    Log.info('CsvDataService', '检查数据限制: klineDataLimit=$klineDataLimit, 当前数据量=${allData.length}');
    
    if (klineDataLimit != null && klineDataLimit > 0 && allData.length > klineDataLimit) {
      finalData = allData.sublist(allData.length - klineDataLimit);
      Log.info('CsvDataService', 'K線データ制限適用: ${allData.length}件 → ${finalData.length}件（最新$klineDataLimit件）');
      
      if (finalData.isNotEmpty) {
        final firstTime = DateTime.fromMillisecondsSinceEpoch(finalData.first.timestamp, isUtc: true);
        final lastTime = DateTime.fromMillisecondsSinceEpoch(finalData.last.timestamp, isUtc: true);
        Log.info('CsvDataService', '限制后数据时间范围: $firstTime ～ $lastTime');
      }
    } else {
      Log.info('CsvDataService', '数据限制条件不满足: klineDataLimit=$klineDataLimit, allData.length=${allData.length}');
    }

    Log.info('CsvDataService', '全CSVファイルから読み込み完了: ${finalData.length}件のデータ');
    return finalData;
  }

  /// 最新のK線の時間を取得
  static DateTime? getLatestCandleTime(List<PriceData> data) {
    if (data.isEmpty) return null;
    final latestData = data.last;
    Log.debug('CsvDataService', '最新のK線の時間: ${latestData.timestamp}');
    return DateTime.fromMillisecondsSinceEpoch(latestData.timestamp, isUtc: true);
  }

  /// 次の5分間隔の時間を計算
  static DateTime getNextCandleTime(DateTime lastCandleTime) {
    final nextMinute = ((lastCandleTime.minute ~/ 5) + 1) * 5;
    
    if (nextMinute >= 60) {
      // 次の時間に進む
      return DateTime.utc(
        lastCandleTime.year,
        lastCandleTime.month,
        lastCandleTime.day,
        lastCandleTime.hour + 1,
        0,
      );
    } else {
      // 同じ時間内の次の5分間隔
      return DateTime.utc(
        lastCandleTime.year,
        lastCandleTime.month,
        lastCandleTime.day,
        lastCandleTime.hour,
        nextMinute,
      );
    }
  }

  /// データの重複を除去してマージ
  static List<PriceData> mergeData(List<PriceData> existingData, List<PriceData> newData) {
    final Map<String, PriceData> dataMap = {};
    int duplicateCount = 0;
    
    // 既存データをマップに追加
    for (final data in existingData) {
      final key = data.timestamp.toString();
      dataMap[key] = data;
    }
    
    Log.debug('CsvDataService', '既存データ数: ${existingData.length}件');
    
    if (existingData.isNotEmpty) {
      final firstTime = DateTime.fromMillisecondsSinceEpoch(existingData.first.timestamp, isUtc: true);
      final lastTime = DateTime.fromMillisecondsSinceEpoch(existingData.last.timestamp, isUtc: true);
      Log.debug('CsvDataService', '既存データ时间范围: $firstTime ～ $lastTime');
    }
    
    if (newData.isNotEmpty) {
      final firstTime = DateTime.fromMillisecondsSinceEpoch(newData.first.timestamp, isUtc: true);
      final lastTime = DateTime.fromMillisecondsSinceEpoch(newData.last.timestamp, isUtc: true);
      Log.debug('CsvDataService', '新データ时间范围: $firstTime ～ $lastTime');
    }
    
    // 新しいデータをマップに追加（重複は上書き）
    for (final data in newData) {
      final key = data.timestamp.toString();
      if (dataMap.containsKey(key)) {
        duplicateCount++;
        // 重複データは新しいデータで上書き
        dataMap[key] = data;
      } else {
        dataMap[key] = data;
      }
    }
    
    Log.debug('CsvDataService', '新しいデータ数: ${newData.length}件');
    Log.debug('CsvDataService', '重複データ数: $duplicateCount件');
    
    // マップからリストに変換して時間順にソート
    final mergedData = dataMap.values.toList();
    mergedData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    Log.info('CsvDataService', 'マージ後のデータ数: ${mergedData.length}件');
    
    if (mergedData.isNotEmpty) {
      final firstTime = DateTime.fromMillisecondsSinceEpoch(mergedData.first.timestamp, isUtc: true);
      final lastTime = DateTime.fromMillisecondsSinceEpoch(mergedData.last.timestamp, isUtc: true);
      Log.info('CsvDataService', 'マージ後データ时间范围: $firstTime ～ $lastTime');
    }
    
    return mergedData;
  }
}
