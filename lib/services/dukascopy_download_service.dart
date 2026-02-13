import 'dart:io';
import '../models/price_data.dart';
import '../models/trading_pair.dart';
import '../models/timeframe.dart';
import 'csv_data_service.dart';
import 'timeframe_data_service.dart';
import 'log_service.dart';

class DukascopyDownloadService {
  static String _resolveNpxCommand() {
    const candidates = [
      r'C:\Program Files\nodejs\npx.cmd',
      r'C:\Program Files (x86)\nodejs\npx.cmd',
    ];

    for (final path in candidates) {
      if (File(path).existsSync()) {
        return path;
      }
    }

    return 'npx';
  }

  static Map<String, String> _buildProcessEnvironment() {
    final env = Map<String, String>.from(Platform.environment);
    final separator = Platform.isWindows ? ';' : ':';
    final currentPath = env['PATH'] ?? '';

    const nodeDirs = [
      r'C:\Program Files\nodejs',
      r'C:\Program Files (x86)\nodejs',
    ];

    for (final dir in nodeDirs) {
      if (Directory(dir).existsSync() && !currentPath.toLowerCase().contains(dir.toLowerCase())) {
        env['PATH'] = '$dir$separator${env['PATH'] ?? ''}';
      }
    }

    return env;
  }

  /// 指定された日付と取引ペアのデータをダウンロード
  static Future<List<PriceData>> downloadDataForDate(DateTime date, TradingPair pair, Timeframe timeframe) async {
    try {
      Log.info('DukascopyDownloadService', 'データダウンロード開始: ${pair.displayName} ${timeframe.displayName} ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
      
      // 日付を文字列に変換
      final String dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final String nextDateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${(date.day + 1).toString().padLeft(2, '0')}';
      
      // dukascopy-nodeコマンドを実行
      final result = await Process.run(
        _resolveNpxCommand(),
        [
          'dukascopy-node',
          '-i', pair.dukascopyCode,
          '-from', dateStr,
          '-to', nextDateStr,
          '-t', timeframe.dukascopyCode,
          '-f', 'csv',
          '--volumes', 'true',
          '--directory', timeframe.getDirectoryName(pair),
          '--cache', 'true',
          '--cache-path', '.dukascopy-cache',
          '--batch-size', '12',
          '--batch-pause', '1000',
          '--retries', '3',
          '--retry-on-empty', 'true'
        ],
        workingDirectory: Directory.current.path,
        environment: _buildProcessEnvironment(),
        runInShell: true, // Use shell to execute npx.cmd on Windows
      );
      
      Log.info('DukascopyDownloadService', 'dukascopy-nodeコマンド実行結果:');
      Log.info('DukascopyDownloadService', '終了コード: ${result.exitCode}');
      Log.info('DukascopyDownloadService', '標準出力: ${result.stdout}');
      if (result.stderr.isNotEmpty) {
        Log.error('DukascopyDownloadService', 'エラー出力: ${result.stderr}');
      }
      
      if (result.exitCode != 0) {
        throw Exception('dukascopy-nodeコマンドの実行に失敗しました: ${result.stderr}');
      }
      
      // ダウンロードされたCSVファイルを読み込み
      final directoryPath = timeframe.getDirectoryName(pair);
      final csvFiles = await CsvDataService.findCsvFiles(directoryPath);
      if (csvFiles.isEmpty) {
        Log.warning('DukascopyDownloadService', '警告: CSVファイルが見つかりません');
        return [];
      }
      
      Log.info('DukascopyDownloadService', '見つかったCSVファイル数: ${csvFiles.length}件');
      for (final file in csvFiles) {
        Log.debug('DukascopyDownloadService', '  - $file');
      }
      
      // 指定された日付のCSVファイルを探す
      final String targetDateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      String? targetFile;
      
      for (final file in csvFiles) {
        if (file.contains(targetDateStr)) {
          targetFile = file;
          break;
        }
      }
      
      // 指定日付のファイルが見つからない場合は最新ファイルを使用
      if (targetFile == null) {
        targetFile = csvFiles.last;
        Log.warning('DukascopyDownloadService', '指定日付のファイルが見つからないため、最新ファイルを使用: $targetFile');
      } else {
        Log.info('DukascopyDownloadService', '指定日付のファイルを使用: $targetFile');
      }
      
      final data = await CsvDataService.loadFromCsv(targetFile);
      
      Log.info('DukascopyDownloadService', 'ダウンロード完了: ${data.length}件のデータを取得');
      if (data.isNotEmpty) {
        final firstTime = DateTime.fromMillisecondsSinceEpoch(data.first.timestamp, isUtc: true);
        final lastTime = DateTime.fromMillisecondsSinceEpoch(data.last.timestamp, isUtc: true);
        Log.info('DukascopyDownloadService', 'データ範囲: ${firstTime.toString()} ～ ${lastTime.toString()}');
        
        // 指定された日付のデータのみをフィルタリング
        final filteredData = data.where((item) {
          final itemDate = DateTime.fromMillisecondsSinceEpoch(item.timestamp, isUtc: true);
          return itemDate.year == date.year && 
                 itemDate.month == date.month && 
                 itemDate.day == date.day;
        }).toList();
        
        Log.info('DukascopyDownloadService', '指定日付(${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')})のデータ: ${filteredData.length}件');
        
        if (filteredData.isNotEmpty) {
          final firstTime = DateTime.fromMillisecondsSinceEpoch(filteredData.first.timestamp, isUtc: true);
          final lastTime = DateTime.fromMillisecondsSinceEpoch(filteredData.last.timestamp, isUtc: true);
          Log.info('DukascopyDownloadService', 'フィルタリング後のデータ範囲: ${firstTime.toString()} ～ ${lastTime.toString()}');
        }
        
        return filteredData;
      }
      
      return data;
    } catch (e) {
      Log.error('DukascopyDownloadService', 'データダウンロードエラー: $e');
      return [];
    }
  }
  
  /// 最新の日付のデータをダウンロード
  static Future<List<PriceData>> downloadLatestData() async {
    // 今日の日付を取得
    final DateTime today = DateTime.now().toUtc();
    Log.info('DukascopyDownloadService', '今日の日付でダウンロード: ${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}');
    return await downloadDataForDate(today, TradingPair.eurusd, Timeframe.m5);
  }
  
  /// 前日のデータをダウンロード
  static Future<List<PriceData>> downloadPreviousDayData() async {
    // 前日の日付を取得
    final DateTime yesterday = DateTime.now().toUtc().subtract(const Duration(days: 1));
    Log.info('DukascopyDownloadService', '前日の日付でダウンロード: ${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}');
    return await downloadDataForDate(yesterday, TradingPair.eurusd, Timeframe.m5);
  }
  
  /// 指定された日付の前日のデータをダウンロード
  static Future<List<PriceData>> downloadPreviousDayDataForDate(DateTime date) async {
    final DateTime previousDay = date.subtract(const Duration(days: 1));
    return await downloadDataForDate(previousDay, TradingPair.eurusd, Timeframe.m5);
  }
  
  /// 指定された日付の翌日のデータをダウンロード
  static Future<List<PriceData>> downloadNextDayData(DateTime date) async {
    final DateTime nextDay = date.add(const Duration(days: 1));
    return await downloadDataForDate(nextDay, TradingPair.eurusd, Timeframe.m5);
  }
  
  /// 指定された日付から指定日数分のデータをダウンロード
  static Future<List<PriceData>> downloadDataForDays(DateTime startDate, int days, {TradingPair tradingPair = TradingPair.eurusd}) async {
    try {
      // 終了日を計算
      final DateTime endDate = startDate.add(Duration(days: days - 1));
      
      Log.info('DukascopyDownloadService', '$days日分のデータをダウンロード開始: ${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')} ～ ${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}');
      Log.debug('DukascopyDownloadService', '開始日: $startDate');
      Log.debug('DukascopyDownloadService', '終了日: $endDate');
      Log.debug('DukascopyDownloadService', '現在の作業ディレクトリ: ${Directory.current.path}');
      Log.debug('DukascopyDownloadService', 'コマンド実行ディレクトリ: flutter_drawer_app');
      
      // 開始日と終了日を文字列に変換
      final String startDateStr = '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
      final String endDateStr = '${endDate.year}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
      
      // 使用正常目录，下载后重命名文件以避免冲突
      final normalDirectory = Timeframe.m5.getDirectoryName(tradingPair);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // dukascopy-nodeコマンドを実行（指定期間のデータを一度にダウンロード）
      final result = await Process.run(
        _resolveNpxCommand(),
        [
          'dukascopy-node',
          '-i', tradingPair.dukascopyCode,
          '-from', startDateStr,
          '-to', endDateStr,
          '-t', 'm5',
          '-f', 'csv',
          '--volumes', 'true',
          '--directory', normalDirectory,
          '--cache', 'true',
          '--cache-path', '.dukascopy-cache',
          '--batch-size', '12',
          '--batch-pause', '1000',
          '--retries', '3',
          '--retry-on-empty', 'true'
        ],
        workingDirectory: Directory.current.path,
        environment: _buildProcessEnvironment(),
        runInShell: true, // Use shell to execute npx.cmd on Windows
      );
      
      Log.info('DukascopyDownloadService', 'dukascopy-nodeコマンド実行結果:');
      Log.info('DukascopyDownloadService', '終了コード: ${result.exitCode}');
      Log.info('DukascopyDownloadService', '標準出力: ${result.stdout}');
      if (result.stderr.isNotEmpty) {
        Log.error('DukascopyDownloadService', 'エラー出力: ${result.stderr}');
      }
      
      // 详细的失败诊断
      if (result.exitCode != 0) {
        Log.error('DukascopyDownloadService', '=== 下载失败诊断 ===');
        Log.error('DukascopyDownloadService', '退出代码: ${result.exitCode}');
        Log.error('DukascopyDownloadService', '标准输出: ${result.stdout}');
        Log.error('DukascopyDownloadService', '错误输出: ${result.stderr}');
        Log.error('DukascopyDownloadService', '交易对: ${tradingPair.dukascopyCode}');
        Log.error('DukascopyDownloadService', '开始日期: $startDateStr');
        Log.error('DukascopyDownloadService', '结束日期: $endDateStr');
        Log.error('DukascopyDownloadService', '输出目录: $normalDirectory');
        Log.error('DukascopyDownloadService', '工作目录: ${Directory.current.path}');
        Log.error('DukascopyDownloadService', '文件名模式: ${tradingPair.dukascopyCode}-m5-bid-{startDate}-{endDate}-$timestamp.csv');
        
        // 检查常见问题
        if (result.stderr.contains('ENOENT') || result.stderr.contains('not found')) {
          Log.error('DukascopyDownloadService', '可能原因: npx或dukascopy-node未安装或不在PATH中');
        } else if (result.stderr.contains('network') || result.stderr.contains('timeout')) {
          Log.error('DukascopyDownloadService', '可能原因: 网络连接问题或超时');
        } else if (result.stderr.contains('permission') || result.stderr.contains('access')) {
          Log.error('DukascopyDownloadService', '可能原因: 文件权限问题');
        } else if (result.stderr.contains('invalid') || result.stderr.contains('format')) {
          Log.error('DukascopyDownloadService', '可能原因: 日期格式或参数错误');
        }
        
        throw Exception('dukascopy-nodeコマンドの実行に失敗しました: ${result.stderr}');
      }
      
      // 下载成功后，重命名文件以避免冲突
      Log.info('DukascopyDownloadService', '下载成功，开始重命名文件以避免冲突...');
      await _renameDownloadedFiles(normalDirectory, tradingPair, startDateStr, endDateStr, timestamp);
      
      // ダウンロードされたCSVファイルを読み込み
      final directoryPath = Timeframe.m5.getDirectoryName(tradingPair);
      Log.info('DukascopyDownloadService', '查找CSV文件目录: $directoryPath');
      
      // 检查目录是否存在
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        Log.error('DukascopyDownloadService', '目录不存在: $directoryPath');
        return [];
      }
      
      final csvFiles = await CsvDataService.findCsvFiles(directoryPath);
      Log.info('DukascopyDownloadService', '找到CSV文件数量: ${csvFiles.length}');
      
      if (csvFiles.isEmpty) {
        Log.error('DukascopyDownloadService', '=== CSV文件未找到诊断 ===');
        Log.error('DukascopyDownloadService', '查找目录: $directoryPath');
        Log.error('DukascopyDownloadService', '目录存在: ${await directory.exists()}');
        
        // 列出目录中的所有文件
        try {
          final files = await directory.list().toList();
          Log.error('DukascopyDownloadService', '目录中的文件:');
          for (final file in files) {
            Log.error('DukascopyDownloadService', '  - ${file.path}');
          }
        } catch (e) {
          Log.error('DukascopyDownloadService', '无法列出目录内容: $e');
        }
        
        Log.warning('DukascopyDownloadService', '警告: CSVファイルが見つかりません');
        return [];
      }
      
      Log.info('DukascopyDownloadService', '見つかったCSVファイル数: ${csvFiles.length}件');
      for (final file in csvFiles) {
        Log.debug('DukascopyDownloadService', '  - $file');
      }
      
      // 指定期間のデータを読み込み
      final List<PriceData> allData = [];
      for (final file in csvFiles) {
        try {
          Log.info('DukascopyDownloadService', '正在读取CSV文件: $file');
          final data = await CsvDataService.loadFromCsv(file);
          Log.info('DukascopyDownloadService', 'ファイル $file から読み込んだデータ数: ${data.length}件');
          
          if (data.isNotEmpty) {
            final firstTime = DateTime.fromMillisecondsSinceEpoch(data.first.timestamp, isUtc: true);
            final lastTime = DateTime.fromMillisecondsSinceEpoch(data.last.timestamp, isUtc: true);
            Log.info('DukascopyDownloadService', 'ファイル $file のデータ範囲: $firstTime ～ $lastTime');
          } else {
            Log.warning('DukascopyDownloadService', '文件 $file 没有数据');
          }
          
          // 指定期間内のデータのみをフィルタリング
          final filteredData = data.where((item) {
            final itemDate = DateTime.fromMillisecondsSinceEpoch(item.timestamp, isUtc: true);
            final itemDateOnly = DateTime.utc(itemDate.year, itemDate.month, itemDate.day);
            return !itemDateOnly.isBefore(startDate) && !itemDateOnly.isAfter(endDate);
          }).toList();
          
          Log.info('DukascopyDownloadService', 'フィルタリング後のデータ数: ${filteredData.length}件');
          allData.addAll(filteredData);
        } catch (e) {
          Log.error('DukascopyDownloadService', '读取CSV文件失败: $file, 错误: $e');
          // 继续处理其他文件
        }
      }
      
      // 時間順にソート
      allData.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      
      Log.info('DukascopyDownloadService', '$days日分のダウンロード完了: ${allData.length}件のデータ');
      if (allData.isNotEmpty) {
        final firstTime = DateTime.fromMillisecondsSinceEpoch(allData.first.timestamp, isUtc: true);
        final lastTime = DateTime.fromMillisecondsSinceEpoch(allData.last.timestamp, isUtc: true);
        Log.info('DukascopyDownloadService', 'データ範囲: ${firstTime.toString()} ～ ${lastTime.toString()}');
      }
      
      return allData;
    } catch (e) {
      Log.error('DukascopyDownloadService', '$days日分データダウンロードエラー: $e');
      return [];
    }
  }
  
  /// 指定された日付から3日分のデータをダウンロード
  static Future<List<PriceData>> downloadDataFor3Days(DateTime startDate) async {
    return await downloadDataForDays(startDate, 7);
  }

  /// 5分足データをダウンロードし、30分足と4時間足のCSVを自動的にマージ生成する
  static Future<List<PriceData>> downloadAndMergeData(DateTime startDate, int days, {TradingPair tradingPair = TradingPair.eurusd}) async {
    try {
      Log.info('DukascopyDownloadService', '=== 开始下载和合并数据 ===');
      Log.info('DukascopyDownloadService', '开始日期: $startDate, 天数: $days');
      Log.info('DukascopyDownloadService', '5分足データのダウンロードと他の時間足のマージ生成を開始します...');
      
      // 1. 5分足データをダウンロード（使用时间戳避免文件名冲突）
      Log.info('DukascopyDownloadService', '开始下载5分钟数据...');
      final m5Data = await downloadDataForDays(startDate, days, tradingPair: tradingPair);
      if (m5Data.isEmpty) {
        Log.error('DukascopyDownloadService', '5分足データのダウンロードに失敗しました');
        return [];
      }
      
      Log.info('DukascopyDownloadService', '5分足データのダウンロード完了: ${m5Data.length}件');
      if (m5Data.isNotEmpty) {
        final firstTime = DateTime.fromMillisecondsSinceEpoch(m5Data.first.timestamp, isUtc: true);
        final lastTime = DateTime.fromMillisecondsSinceEpoch(m5Data.last.timestamp, isUtc: true);
        Log.info('DukascopyDownloadService', '5分钟数据范围: $firstTime ～ $lastTime');
      }
      
      // 2. 30分足CSVをマージ生成
      Log.info('DukascopyDownloadService', '15分足CSVのマージ生成を開始します...');
      await _mergeAndGenerateCsv('m15', tradingPair);

      // 2. 30分足CSVをマージ生成
      Log.info('DukascopyDownloadService', '30分足CSVのマージ生成を開始します...');
      await _mergeAndGenerateCsv('m30', tradingPair);
      
      // 3. 1時間足CSVをマージ生成
      Log.info('DukascopyDownloadService', '1時間足CSVのマージ生成を開始します...');
      await _mergeAndGenerateCsv('h1', tradingPair);
      
      // 4. 2時間足CSVをマージ生成
      Log.info('DukascopyDownloadService', '2時間足CSVのマージ生成を開始します...');
      await _mergeAndGenerateCsv('h2', tradingPair);
      
      // 5. 4時間足CSVをマージ生成
      Log.info('DukascopyDownloadService', '4時間足CSVのマージ生成を開始します...');
      await _mergeAndGenerateCsv('h4', tradingPair);
      
      Log.info('DukascopyDownloadService', 'すべての時間足CSVの生成が完了しました');
      Log.info('DukascopyDownloadService', '=== 下载和合并数据完成 ===');
      return m5Data;
      
    } catch (e) {
      Log.error('DukascopyDownloadService', 'データのダウンロードとマージに失敗しました: $e');
      Log.error('DukascopyDownloadService', '错误堆栈: ${StackTrace.current}');
      return [];
    }
  }

  /// データをマージして指定した時間足のCSVファイルを生成する
  static Future<void> _mergeAndGenerateCsv(String timeframe, TradingPair tradingPair) async {
    try {
      // 1. すべての5分足周期のCSVファイルを読み込む
      Log.info('DukascopyDownloadService', 'マージのためにすべての5分足CSVファイルを読み込みます...');
      final allM5CsvFiles = await CsvDataService.findCsvFiles('data/${tradingPair.dukascopyCode}/m5');
      if (allM5CsvFiles.isEmpty) {
        Log.warning('DukascopyDownloadService', '5分足CSVファイルが見つからないため、$timeframeファイルをマージ生成できません');
        return;
      }
      // 合并操作不应用数据限制，读取所有5分钟数据
      final allM5Data = await CsvDataService.loadFromMultipleCsvs(allM5CsvFiles, klineDataLimit: null);
      if (allM5Data.isEmpty) {
        Log.warning('DukascopyDownloadService', '5分足CSVファイルにデータがないため、マージできません');
        return;
      }
      Log.info('DukascopyDownloadService', 'すべての5分足データの読み込み完了: ${allM5Data.length}件');

      // 2. TimeframeDataServiceを使用してデータをマージ
      final mergedData = await TimeframeDataService.mergeDataForTimeframe(allM5Data, timeframe);
      
      if (mergedData.isEmpty) {
        Log.warning('DukascopyDownloadService', '$timeframeデータのマージに失敗しました、結果は空です');
        return;
      }
      
      // 3. ファイルの断片化を避けるため、まず古いCSVファイルを削除し、その後、完全に新しい統合ファイルを生成します
      final directory = await _getCsvDirectory(timeframe, tradingPair);
      if (await directory.exists()) {
        final oldFiles = await CsvDataService.findCsvFiles(directory.path);
        for (final file in oldFiles) {
          Log.debug('DukascopyDownloadService', '古い $timeframe CSV ファイルを削除: $file');
          await File(file).delete();
        }
      } else {
        await directory.create(recursive: true);
      }
      
      // 4. 新しいファイル名を生成
      final firstTime = DateTime.fromMillisecondsSinceEpoch(mergedData.first.timestamp, isUtc: true);
      final lastTime = DateTime.fromMillisecondsSinceEpoch(mergedData.last.timestamp, isUtc: true);
      final dateKey = '${firstTime.year.toString().padLeft(4, '0')}-${firstTime.month.toString().padLeft(2, '0')}-${firstTime.day.toString().padLeft(2, '0')}-${lastTime.year.toString().padLeft(4, '0')}-${lastTime.month.toString().padLeft(2, '0')}-${lastTime.day.toString().padLeft(2, '0')}';
      
      final fileName = '${tradingPair.dukascopyCode}-$timeframe-bid-$dateKey.csv';
      final filePath = '${directory.path}/$fileName';
      
      // 5. CSVコンテンツを生成してファイルに書き込む
      final csvContent = _generateCsvContent(mergedData);
      
      final file = File(filePath);
      await file.writeAsString(csvContent);
      
      Log.info('DukascopyDownloadService', '${timeframe}CSVファイルの生成完了: $fileName (${mergedData.length}件のデータ)');
      
    } catch (e) {
      Log.error('DukascopyDownloadService', '${timeframe}CSVの生成に失敗しました: $e');
    }
  }

  /// CSVコンテンツを生成
  static String _generateCsvContent(List<PriceData> data) {
    final buffer = StringBuffer();
    
    // ヘッダー行を書き込み
    buffer.writeln('timestamp,open,high,low,close,volume');
    
    // データ行を書き込み
    for (final item in data) {
      buffer.writeln('${item.timestamp},${item.open},${item.high},${item.low},${item.close},${item.volume}');
    }
    
    return buffer.toString();
  }


  /// CSVディレクトリを取得
  static Future<Directory> _getCsvDirectory(String timeframe, TradingPair tradingPair) async {
    final currentDir = Directory.current.path;
    return Directory('$currentDir/data/${tradingPair.dukascopyCode}/$timeframe');
  }
  
  /// 重命名下载的文件以避免冲突
  static Future<void> _renameDownloadedFiles(String directoryPath, TradingPair tradingPair, String startDateStr, String endDateStr, int timestamp) async {
    try {
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        Log.warning('DukascopyDownloadService', '目录不存在，无法重命名文件: $directoryPath');
        return;
      }
      
      // 查找最近下载的CSV文件
      final files = await directory.list().toList();
      final csvFiles = files.where((file) => 
        file is File && 
        file.path.endsWith('.csv') &&
        file.path.contains(tradingPair.dukascopyCode.toLowerCase())
      ).cast<File>().toList();
      
      if (csvFiles.isEmpty) {
        Log.warning('DukascopyDownloadService', '没有找到需要重命名的CSV文件');
        return;
      }
      
      // 按修改时间排序，获取最新的文件
      csvFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      final latestFile = csvFiles.first;
      
      // 生成新的文件名
      final newFileName = '${tradingPair.dukascopyCode}-m5-bid-$startDateStr-$endDateStr-$timestamp.csv';
      final newFilePath = '${directory.path}/$newFileName';
      
      Log.info('DukascopyDownloadService', '重命名文件: ${latestFile.path} -> $newFilePath');
      
      // 重命名文件
      await latestFile.rename(newFilePath);
      Log.info('DukascopyDownloadService', '文件重命名成功: $newFileName');
      
    } catch (e) {
      Log.error('DukascopyDownloadService', '重命名文件时发生错误: $e');
    }
  }
}
