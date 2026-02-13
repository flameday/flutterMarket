import 'dart:async';
import '../models/trading_pair.dart';
import '../models/timeframe.dart';
import 'dukascopy_download_service.dart';
import 'log_service.dart';

/// 複数取引ペアのデータダウンロードサービス
class MultiPairDownloadService {
  static final Map<String, StreamController<double>> _progressControllers = {};
  static final Map<String, bool> _isDownloading = {};

  /// 指定された取引ペアと時間周期のデータをダウンロード
  static Future<List<Map<String, dynamic>>> downloadMultiplePairs({
    required List<TradingPair> pairs,
    required List<Timeframe> timeframes,
    required DateTime startDate,
    required DateTime endDate,
    String? progressKey,
  }) async {
    final String key = progressKey ?? 'default';
    _isDownloading[key] = true;
    
    try {
      Log.info('MultiPairDownloadService', '複数ペアダウンロード開始: ${pairs.length}ペア x ${timeframes.length}時間周期');
      
      final List<Map<String, dynamic>> results = [];
      final int totalTasks = pairs.length * timeframes.length;
      int completedTasks = 0;

      for (final pair in pairs) {
        for (final timeframe in timeframes) {
          if (!_isDownloading[key]!) break; // キャンセルチェック
          
          try {
            Log.info('MultiPairDownloadService', 'ダウンロード中: ${pair.displayName} ${timeframe.displayName}');
            
            // 各日付のデータをダウンロード
            DateTime currentDate = startDate;
            while (currentDate.isBefore(endDate) && _isDownloading[key]!) {
              try {
                await DukascopyDownloadService.downloadDataForDate(
                  currentDate, 
                  pair, 
                  timeframe
                );
                
                Log.info('MultiPairDownloadService', '完了: ${pair.displayName} ${timeframe.displayName} ${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')}');
              } catch (e) {
                Log.error('MultiPairDownloadService', 'エラー: ${pair.displayName} ${timeframe.displayName} ${currentDate.year}-${currentDate.month.toString().padLeft(2, '0')}-${currentDate.day.toString().padLeft(2, '0')} - $e');
              }
              
              currentDate = currentDate.add(const Duration(days: 1));
            }
            
            completedTasks++;
            final double progress = completedTasks / totalTasks;
            _notifyProgress(key, progress);
            
            results.add({
              'pair': pair,
              'timeframe': timeframe,
              'status': 'success',
              'message': 'ダウンロード完了',
            });
            
          } catch (e) {
            Log.error('MultiPairDownloadService', 'ダウンロードエラー: ${pair.displayName} ${timeframe.displayName} - $e');
            
            results.add({
              'pair': pair,
              'timeframe': timeframe,
              'status': 'error',
              'message': e.toString(),
            });
            
            completedTasks++;
            final double progress = completedTasks / totalTasks;
            _notifyProgress(key, progress);
          }
        }
      }
      
      Log.info('MultiPairDownloadService', '複数ペアダウンロード完了: ${results.length}タスク');
      return results;
      
    } finally {
      _isDownloading[key] = false;
    }
  }

  /// 主要通貨ペアのデータをダウンロード
  static Future<List<Map<String, dynamic>>> downloadMajorPairs({
    required List<Timeframe> timeframes,
    required DateTime startDate,
    required DateTime endDate,
    String? progressKey,
  }) async {
    final List<TradingPair> majorPairs = [
      TradingPair.eurusd,
      TradingPair.usdjpy,
      TradingPair.gbpjpy,
      TradingPair.xauusd,
      TradingPair.gbpusd,
      TradingPair.audusd,
    ];
    
    return downloadMultiplePairs(
      pairs: majorPairs,
      timeframes: timeframes,
      startDate: startDate,
      endDate: endDate,
      progressKey: progressKey,
    );
  }

  /// 指定された取引ペアのデータをダウンロード
  static Future<List<Map<String, dynamic>>> downloadSpecificPairs({
    required List<TradingPair> pairs,
    required List<Timeframe> timeframes,
    required DateTime startDate,
    required DateTime endDate,
    String? progressKey,
  }) async {
    return downloadMultiplePairs(
      pairs: pairs,
      timeframes: timeframes,
      startDate: startDate,
      endDate: endDate,
      progressKey: progressKey,
    );
  }

  /// ダウンロードをキャンセル
  static void cancelDownload(String? progressKey) {
    final String key = progressKey ?? 'default';
    _isDownloading[key] = false;
    Log.info('MultiPairDownloadService', 'ダウンロードキャンセル: $key');
  }

  /// ダウンロード中かチェック
  static bool isDownloading(String? progressKey) {
    final String key = progressKey ?? 'default';
    return _isDownloading[key] ?? false;
  }

  /// 進捗ストリームを取得
  static Stream<double> getProgressStream(String? progressKey) {
    final String key = progressKey ?? 'default';
    if (!_progressControllers.containsKey(key)) {
      _progressControllers[key] = StreamController<double>.broadcast();
    }
    return _progressControllers[key]!.stream;
  }

  /// 進捗を通知
  static void _notifyProgress(String key, double progress) {
    if (_progressControllers.containsKey(key)) {
      _progressControllers[key]!.add(progress);
    }
  }

  /// リソースをクリーンアップ
  static void dispose() {
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _progressControllers.clear();
    _isDownloading.clear();
  }
}
