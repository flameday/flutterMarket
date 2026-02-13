import 'dart:async';
import '../models/price_data.dart';
import '../models/vertical_line.dart';
import '../services/vertical_line_service.dart';
import '../services/vertical_line_file_watcher.dart';
import '../utils/kline_timestamp_utils.dart';
import '../services/log_service.dart';

/// Mixinが依存するホストクラスのインターフェースを定義
abstract class VerticalLineControllerHost {
  List<PriceData> get data;
  int get startIndex;
  int get endIndex;
  double get candleWidth;
  double get scale;
  int getCandleIndexFromX(double x, double chartWidth);
  void notifyUIUpdate();
}

/// 垂直線に関するロジックを管理するMixin
mixin VerticalLineControllerMixin on VerticalLineControllerHost {
  List<VerticalLine> _verticalLines = [];
  bool isVerticalLineMode = false;
  StreamSubscription<void>? _fileWatcherSubscription;

  /// Mixinを初期化
  Future<void> initVerticalLines() async {
    _verticalLines = await VerticalLineService.loadVerticalLines();
    
    // 縦線設定ファイルの変更監視を開始
    await _startFileWatcher();
  }

  /// 縦線設定ファイルの変更監視を開始
  Future<void> _startFileWatcher() async {
    try {
      // ファイル監視器を起動
      await VerticalLineFileWatcher.instance.startWatching();
      
      // ファイル変更イベントを監視
      _fileWatcherSubscription = VerticalLineFileWatcher.instance.onFileChanged.listen(
        (_) async {
          await _onVerticalLineFileChanged();
        },
        onError: (error) {
          Log.error('VerticalLineController', '縦線ファイル監視エラー: $error');
        },
      );
      
      Log.info('VerticalLineController', '縦線設定ファイル監視器が起動しました');
    } catch (e) {
      Log.error('VerticalLineController', '縦線ファイル監視器の起動に失敗しました: $e');
    }
  }

  /// 縦線設定ファイルの変更を処理
  Future<void> _onVerticalLineFileChanged() async {
    try {
      Log.info('VerticalLineController', '縦線設定ファイルの変更を検出、データを再読み込み中...');
      
      // 縦線データを再読み込み
      final newVerticalLines = await VerticalLineService.loadVerticalLines();
      
      // データが実際に変更されたかチェック
      if (_hasVerticalLinesChanged(newVerticalLines)) {
        _verticalLines = newVerticalLines;
        Log.info('VerticalLineController', '縦線データが更新されました: ${_verticalLines.length}本');
        
        // UI更新を通知（ここでホストクラスの更新メソッドを呼び出す必要があります）
        _notifyVerticalLinesChanged();
      } else {
        Log.debug('VerticalLineController', '縦線データに変更はありません');
      }
    } catch (e) {
      Log.error('VerticalLineController', '縦線ファイル変更の処理に失敗しました: $e');
    }
  }

  /// 縦線データが変更されたかチェック
  bool _hasVerticalLinesChanged(List<VerticalLine> newLines) {
    if (_verticalLines.length != newLines.length) {
      return true;
    }
    
    // 各縦線のIDを比較
    final currentIds = _verticalLines.map((line) => line.id).toSet();
    final newIds = newLines.map((line) => line.id).toSet();
    
    return !currentIds.containsAll(newIds) || !newIds.containsAll(currentIds);
  }

  /// 通知竖线数据已变化
  void _notifyVerticalLinesChanged() {
    // 调用宿主类的UI更新方法
    notifyUIUpdate();
    Log.info('VerticalLineController', '竖线数据已变化，UI更新已触发');
  }

  List<VerticalLine> get verticalLines => List.unmodifiable(_verticalLines);

  /// 指定位置に垂直線を追加または削除
  Future<void> addVerticalLineAtPosition(double x, double chartWidth) async {
    if (data.isEmpty) return;

    final int candleIndex = getCandleIndexFromX(x, chartWidth);
    
    if (candleIndex < 0 || candleIndex >= data.length) {
      Log.warning('VerticalLine', 'K線インデックスが無効、縦線を追加できません');
      return;
    }

    final PriceData candle = data[candleIndex];
    final int timestamp = candle.timestamp;
    
    Log.info('VerticalLine', '添加竖线 - 时间戳: ${KlineTimestampUtils.formatTimestamp(timestamp)}, 位置: $candleIndex');
    
    // 基于时间戳查找现有竖线
    final existingLine = _verticalLines.where((line) => line.timestamp == timestamp).firstOrNull;
    if (existingLine != null) {
      Log.info('VerticalLine', '发现现有竖线，删除 - ID: ${existingLine.id}');
      await removeVerticalLine(existingLine.id);
      isVerticalLineMode = false;
      return;
    }

    final String id = DateTime.now().millisecondsSinceEpoch.toString();
    final VerticalLine verticalLine = VerticalLine(
      id: id,
      timestamp: timestamp,
      createdAt: DateTime.now(),
    );

    _verticalLines.add(verticalLine);
    await VerticalLineService.addVerticalLine(verticalLine);
    
    Log.info('VerticalLine', '竖线添加成功 - ID: $id, 时间戳: ${KlineTimestampUtils.formatTimestamp(timestamp)}');
    isVerticalLineMode = false;
  }

  /// 指定位置付近で縦線を削除（右クリックで削除）
  Future<bool> removeVerticalLineNearPosition(double x, double chartWidth) async {
    if (data.isEmpty) return false;

    // 20ピクセルに対応するK線インデックス範囲を計算
    const double deleteRangePixels = 20.0;
    
    // 実際のK線幅を取得（スケールを考慮）
    final double actualCandleWidth = candleWidth * scale;
    final double deleteRangeCandles = deleteRangePixels / actualCandleWidth;
    
    final int centerCandleIndex = getCandleIndexFromX(x, chartWidth);
    if (centerCandleIndex < 0 || centerCandleIndex >= data.length) {
      Log.warning('VerticalLine', '删除竖线 - 中心K线索引无效: $centerCandleIndex');
      return false;
    }

    // 範囲内のK線の时间戳
    final int startRange = (centerCandleIndex - deleteRangeCandles).round().clamp(0, data.length - 1);
    final int endRange = (centerCandleIndex + deleteRangeCandles).round().clamp(0, data.length - 1);
    
    final int startTimestamp = data[startRange].timestamp;
    final int endTimestamp = data[endRange].timestamp;
    
    Log.info('VerticalLine', '删除竖线 - 搜索范围: ${KlineTimestampUtils.formatTimestamp(startTimestamp)} 到 ${KlineTimestampUtils.formatTimestamp(endTimestamp)}, 中心索引: $centerCandleIndex');
    
    // 基于时间戳范围查找竖线
    final List<VerticalLine> linesInRange = _verticalLines.where((line) => 
      KlineTimestampUtils.isTimestampInRange(line.timestamp, startTimestamp, endTimestamp)
    ).toList();

    if (linesInRange.isEmpty) {
      Log.info('VerticalLine', '删除竖线 - 在指定范围内未找到竖线');
      return false;
    }

    // 見つかった縦線を削除
    for (final line in linesInRange) {
      Log.info('VerticalLine', '删除竖线 - ID: ${line.id}, 时间戳: ${KlineTimestampUtils.formatTimestamp(line.timestamp)}');
      await removeVerticalLine(line.id);
    }

    Log.info('VerticalLine', '成功删除 ${linesInRange.length} 条竖线 (时间戳范围: ${KlineTimestampUtils.formatTimestamp(startTimestamp)} - ${KlineTimestampUtils.formatTimestamp(endTimestamp)})');
    return true;
  }

  /// 垂直線を削除
  Future<void> removeVerticalLine(String id) async {
    _verticalLines.removeWhere((line) => line.id == id);
    await VerticalLineService.removeVerticalLine(id);
  }

  /// 根据时间戳删除竖线（跨窗口删除支持）
  Future<bool> removeVerticalLineByTimestamp(int timestamp) async {
    // 查找匹配时间戳的竖线
    final List<VerticalLine> linesToRemove = _verticalLines.where((line) => 
      line.timestamp == timestamp
    ).toList();

    if (linesToRemove.isEmpty) {
      Log.info('VerticalLine', '根据时间戳删除竖线 - 未找到时间戳为 ${KlineTimestampUtils.formatTimestamp(timestamp)} 的竖线');
      return false;
    }

    // 删除找到的竖线
    for (final line in linesToRemove) {
      Log.info('VerticalLine', '根据时间戳删除竖线 - ID: ${line.id}, 时间戳: ${KlineTimestampUtils.formatTimestamp(timestamp)}');
      await removeVerticalLine(line.id);
    }

    Log.info('VerticalLine', '成功根据时间戳删除 ${linesToRemove.length} 条竖线');
    return true;
  }

  /// 根据时间戳范围删除竖线（跨窗口删除支持）
  Future<int> removeVerticalLinesByTimestampRange(int startTimestamp, int endTimestamp) async {
    // 查找时间戳范围内的竖线
    final List<VerticalLine> linesToRemove = _verticalLines.where((line) => 
      KlineTimestampUtils.isTimestampInRange(line.timestamp, startTimestamp, endTimestamp)
    ).toList();

    if (linesToRemove.isEmpty) {
      Log.info('VerticalLine', '根据时间戳范围删除竖线 - 在范围 ${KlineTimestampUtils.formatTimestamp(startTimestamp)} 到 ${KlineTimestampUtils.formatTimestamp(endTimestamp)} 内未找到竖线');
      return 0;
    }

    // 删除找到的竖线
    for (final line in linesToRemove) {
      Log.info('VerticalLine', '根据时间戳范围删除竖线 - ID: ${line.id}, 时间戳: ${KlineTimestampUtils.formatTimestamp(line.timestamp)}');
      await removeVerticalLine(line.id);
    }

    Log.info('VerticalLine', '成功根据时间戳范围删除 ${linesToRemove.length} 条竖线');
    return linesToRemove.length;
  }

  /// すべての垂直線を削除
  Future<void> clearAllVerticalLines() async {
    _verticalLines.clear();
    await VerticalLineService.clearAllVerticalLines();
  }

  /// 縦線描画モードを切り替え
  void toggleVerticalLineMode() {
    isVerticalLineMode = !isVerticalLineMode;
    Log.info('VerticalLine', '縦線モード: ${isVerticalLineMode ? "オン" : "オフ"}');
  }

  /// 表示範囲内の垂直線を取得
  List<VerticalLine> getVisibleVerticalLines() {
    if (data.isEmpty) return [];
    
    // インデックスの境界チェック
    final int safeStartIndex = startIndex.clamp(0, data.length - 1);
    final int safeEndIndex = endIndex.clamp(0, data.length);
    
    if (safeStartIndex >= safeEndIndex) return [];
    
    // 表示範囲内のタイムスタンプ範囲を取得
    final int startTimestamp = data[safeStartIndex].timestamp;
    final int endTimestamp = data[safeEndIndex - 1].timestamp;
    
    return _verticalLines.where((line) => 
      line.timestamp >= startTimestamp && line.timestamp <= endTimestamp
    ).toList();
  }

  /// 清理资源，停止文件监控
  void disposeVerticalLineController() {
    _fileWatcherSubscription?.cancel();
    Log.info('VerticalLineController', '竖线控制器资源已清理');
  }
}
