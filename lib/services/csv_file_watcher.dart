import 'dart:async';
import 'dart:io';

import '../services/log_service.dart';

/// CSVファイル監視サービス
/// 指定時間周期のCSVファイルの変化を監視し、ファイル更新時にUIリフレッシュを通知
class CsvFileWatcher {
  static final Map<String, CsvFileWatcher> _instances = {};
  
  final String timeframe;
  late StreamSubscription<FileSystemEvent> _subscription;
  final StreamController<void> _fileChangedController = StreamController<void>.broadcast();
  bool _isWatching = false;

  CsvFileWatcher._(this.timeframe);

  /// 指定時間周期のファイル監視器インスタンスを取得
  static CsvFileWatcher getInstance(String timeframe) {
    if (!_instances.containsKey(timeframe)) {
      _instances[timeframe] = CsvFileWatcher._(timeframe);
    }
    return _instances[timeframe]!;
  }

  /// ファイル変化イベントストリーム
  Stream<void> get onFileChanged => _fileChangedController.stream;

  /// CSVファイルの監視を開始
  Future<void> startWatching() async {
    if (_isWatching) {
      Log.info('CsvFileWatcher', 'CSVファイル監視器は既に実行中: $timeframe');
      return;
    }

    try {
      // CSVディレクトリパスを取得
      final csvDirPath = await _getCsvDirectoryPath();
      if (csvDirPath == null) {
        Log.warning('CsvFileWatcher', 'CSVディレクトリパスが見つからない: $timeframe');
        return;
      }

      final directory = Directory(csvDirPath);
      
      // ディレクトリが存在するかチェック
      if (!await directory.exists()) {
        Log.warning('CsvFileWatcher', 'CSVディレクトリが存在しない: $csvDirPath');
        return;
      }

      Log.info('CsvFileWatcher', 'CSVディレクトリの監視を開始: $csvDirPath');
      
      // ディレクトリ変化を監視
      _subscription = directory.watch().listen(
        (FileSystemEvent event) {
          _handleFileSystemEvent(event);
        },
        onError: (error) {
          Log.error('CsvFileWatcher', 'CSVファイル監視エラー: $error');
        },
      );

      _isWatching = true;
      Log.info('CsvFileWatcher', 'CSVファイル監視器起動成功: $timeframe');
      
    } catch (e) {
      Log.error('CsvFileWatcher', 'CSVファイル監視器起動失敗: $e');
    }
  }

  /// CSVファイルの監視を停止
  void stopWatching() {
    if (!_isWatching) return;

    _subscription.cancel();
    _isWatching = false;
    Log.info('CsvFileWatcher', 'CSVファイル監視器が停止: $timeframe');
  }

  /// ファイルシステムイベントを処理
  void _handleFileSystemEvent(FileSystemEvent event) {
    if (event is FileSystemModifyEvent || event is FileSystemCreateEvent) {
      final eventPath = event.path;
      
      // CSVファイルかどうかチェック
      if (eventPath.toLowerCase().endsWith('.csv')) {
        Log.debug('CsvFileWatcher', '${timeframe}CSVファイル変化を検出: $eventPath');
        
        // 時間周期に基づいて異なる処理戦略を採用
        if (timeframe == 'm5') {
          // 5分：新ファイルはダウンロードでのみ取得可能、ファイル作成イベントを監視
          if (event is FileSystemCreateEvent) {
            Log.info('CsvFileWatcher', '5分新ファイルを検出: $eventPath');
            _notifyFileChange();
          }
        } else {
          // 30分、4時間：マージ生成により、ファイル修正イベントを監視
          if (event is FileSystemModifyEvent) {
            Log.info('CsvFileWatcher', '$timeframeファイル更新を検出: $eventPath');
            _notifyFileChange();
          }
        }
      }
    }
  }

  /// ファイルの変更を通知
  void _notifyFileChange() {
    // 少し遅延させて、ファイルの書き込みが完了するのを保証する
    Timer(const Duration(milliseconds: 1000), () {
      _fileChangedController.add(null);
    });
  }

  /// CSVディレクトリのパスを取得
  Future<String?> _getCsvDirectoryPath() async {
    try {
      final currentDir = Directory.current.path;
      final csvDirPath = '$currentDir/data/EURUSD/$timeframe';
      return csvDirPath;
      
    } catch (e) {
      Log.error('CsvFileWatcher', 'CSVディレクトリパスの取得に失敗しました: $e');
      return null;
    }
  }


  /// ファイル変更イベントを手動でトリガー（テスト用）
  void triggerFileChange() {
    _fileChangedController.add(null);
  }

  /// リソースを解放
  void dispose() {
    stopWatching();
    _fileChangedController.close();
    _instances.remove(timeframe);
  }

  /// すべてのインスタンスを解放
  static void disposeAll() {
    for (final watcher in _instances.values) {
      watcher.dispose();
    }
    _instances.clear();
  }
}
