import 'dart:async';
import '../models/price_data.dart';
import '../models/manual_high_low_point.dart';
import '../services/manual_high_low_service.dart';
import '../utils/kline_timestamp_utils.dart';
import '../services/log_service.dart';

/// Mixinが依存するホストクラスのインターフェースを定義
abstract class ManualHighLowControllerHost {
  List<PriceData> get data;
  int get startIndex;
  int get endIndex;
  double get candleWidth;
  double get scale;
  String get currentTimeframe; // 現在の時間周期
  void notifyUIUpdate();
}

/// 手動高低点コントローラーミックスイン
mixin ManualHighLowControllerMixin on ManualHighLowControllerHost {
  List<ManualHighLowPoint> _manualHighLowPoints = [];
  bool _isManualHighLowMode = false;

  /// 手動高低点モードの状態
  bool get isManualHighLowMode => _isManualHighLowMode;

  /// 手動高低点のリスト（読み取り専用）
  List<ManualHighLowPoint> get manualHighLowPoints => List.unmodifiable(_manualHighLowPoints);

  /// 手動高低点モードを切り替え
  void toggleManualHighLowMode() {
    _isManualHighLowMode = !_isManualHighLowMode;
    Log.info('ManualHighLowController', '手動高低点モード: ${_isManualHighLowMode ? "ON" : "OFF"}');
  }

  /// 手動高低点データを初期化
  Future<void> initManualHighLowPoints() async {
    try {
      _manualHighLowPoints = await ManualHighLowService.loadHighLowPoints();
      Log.info('ManualHighLowController', '手動高低点データを初期化しました: ${_manualHighLowPoints.length}個');
    } catch (e) {
      Log.error('ManualHighLowController', '手動高低点データの初期化に失敗しました: $e');
      _manualHighLowPoints = [];
    }
  }

  /// 指定位置で手動高低点を追加または削除
  Future<void> toggleManualHighLowPointAtPosition(double x, double y, double chartWidth, double chartHeight, double minPrice, double maxPrice) async {
    if (data.isEmpty) return;

    // X座標からK線インデックスを取得
    final int candleIndex = getCandleIndexFromX(x, chartWidth);
    if (candleIndex < 0 || candleIndex >= data.length) {
      Log.warning('ManualHighLow', 'K線インデックスが無効です: $candleIndex');
      return;
    }

    final PriceData candle = data[candleIndex];
    final int timestamp = candle.timestamp;

    // Y座標から価格を計算
    final double price = minPrice + (maxPrice - minPrice) * (1.0 - y / chartHeight);

    // 高値と安値のどちらに近いかを判定
    final double highDistance = (price - candle.high).abs();
    final double lowDistance = (price - candle.low).abs();
    final bool isHigh = highDistance < lowDistance;

    Log.info('ManualHighLow', '高低点操作 - 位置: ($x, $y), K線: $candleIndex, 価格: $price, タイプ: ${isHigh ? "高値" : "安値"}');

    // 既存の手動高低点があるかチェック（時間周期も考慮）
    final existingPoint = _manualHighLowPoints.where((point) => 
      point.timestamp == timestamp && 
      point.isHigh == isHigh &&
      point.timeframe == currentTimeframe
    ).firstOrNull;

    if (existingPoint != null) {
      // 既存の点を削除
      await removeManualHighLowPoint(existingPoint.id);
      Log.info('ManualHighLow', '既存の手動高低点を削除しました: ${existingPoint.id}');
    } else {
      // 新しい点を追加
      await addManualHighLowPoint(timestamp, price, isHigh, timeframe: currentTimeframe);
      Log.info('ManualHighLow', '新しい手動高低点を追加しました: ${isHigh ? "高値" : "安値"} - $price (周期: $currentTimeframe)');
    }
  }

  /// 手動高低点を追加
  Future<void> addManualHighLowPoint(int timestamp, double price, bool isHigh, {String? note, String? timeframe}) async {
    final String id = DateTime.now().millisecondsSinceEpoch.toString();
    final ManualHighLowPoint point = ManualHighLowPoint(
      id: id,
      timestamp: timestamp,
      price: price,
      isHigh: isHigh,
      createdAt: DateTime.now(),
      note: note,
      timeframe: timeframe ?? currentTimeframe,
    );

    _manualHighLowPoints.add(point);
    await ManualHighLowService.addHighLowPoint(point);
    notifyUIUpdate();
  }

  /// 手動高低点を削除
  Future<void> removeManualHighLowPoint(String id) async {
    _manualHighLowPoints.removeWhere((point) => point.id == id);
    await ManualHighLowService.removeHighLowPoint(id);
    notifyUIUpdate();
  }

  /// すべての手動高低点を削除
  Future<void> clearAllManualHighLowPoints() async {
    _manualHighLowPoints.clear();
    await ManualHighLowService.clearAllHighLowPoints();
    notifyUIUpdate();
  }

  /// 表示範囲内の手動高低点を取得
  List<ManualHighLowPoint> getVisibleManualHighLowPoints() {
    if (data.isEmpty) return [];

    // インデックスの境界チェック
    final int safeStartIndex = startIndex.clamp(0, data.length - 1);
    final int safeEndIndex = endIndex.clamp(0, data.length);
    
    if (safeStartIndex >= safeEndIndex) return [];

    final int startTimestamp = data[safeStartIndex].timestamp;
    final int endTimestamp = data[safeEndIndex - 1].timestamp;

    return _manualHighLowPoints.where((point) => 
      KlineTimestampUtils.isTimestampInRange(point.timestamp, startTimestamp, endTimestamp) &&
      (point.timeframe == null || point.timeframe == currentTimeframe)
    ).toList();
  }

  /// 指定位置付近の手動高低点を検索
  ManualHighLowPoint? findManualHighLowPointNearPosition(double x, double y, double chartWidth, double chartHeight, double minPrice, double maxPrice) {
    if (data.isEmpty) return null;

    // クリック位置からK線インデックスと価格を計算
    final int candleIndex = getCandleIndexFromX(x, chartWidth);
    if (candleIndex < 0 || candleIndex >= data.length) return null;

    final PriceData candle = data[candleIndex];
    final int timestamp = candle.timestamp;
    final double price = minPrice + (maxPrice - minPrice) * (1.0 - y / chartHeight);

    // 表示範囲内の手動高低点を取得
    final visiblePoints = getVisibleManualHighLowPoints();

    if (visiblePoints.isEmpty) return null;

    // 最も近い点を検索
    ManualHighLowPoint? nearestPoint;
    double minDistance = double.infinity;
    const double maxSearchDistance = 50.0; // 50ピクセル以内

    for (final point in visiblePoints) {
      // 時間距離と価格距離を組み合わせた距離を計算
      final timeDistance = (point.timestamp - timestamp).abs() / 1000.0; // 秒単位
      final priceDistance = (point.price - price).abs();
      
      // 正規化された距離を計算
      final distance = (timeDistance / 3600.0) + (priceDistance / 100.0);
      
      if (distance < minDistance && distance <= maxSearchDistance) {
        minDistance = distance;
        nearestPoint = point;
      }
    }

    return nearestPoint;
  }

  /// 手動高低点と自動高低点を統合して返す
  /// 手動高低点が優先され、自動高低点は手動高低点がない場合のみ使用される
  List<ManualHighLowPoint> getCombinedHighLowPoints(List<ManualHighLowPoint> autoHighLowPoints) {
    final List<ManualHighLowPoint> combinedPoints = [];
    
    // 現在の時間周期の手動高低点を追加
    final currentTimeframeManualPoints = _manualHighLowPoints.where((point) => 
      point.timeframe == null || point.timeframe == currentTimeframe
    ).toList();
    combinedPoints.addAll(currentTimeframeManualPoints);
    
    // 自動高低点を追加（手動高低点と重複しないもののみ）
    for (final autoPoint in autoHighLowPoints) {
      final hasManualPoint = currentTimeframeManualPoints.any((manualPoint) => 
        manualPoint.timestamp == autoPoint.timestamp && 
        manualPoint.isHigh == autoPoint.isHigh &&
        (manualPoint.timeframe == null || manualPoint.timeframe == currentTimeframe)
      );
      
      if (!hasManualPoint) {
        combinedPoints.add(autoPoint);
      }
    }
    
    // タイムスタンプでソート
    combinedPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    return combinedPoints;
  }

  /// 手動高低点の統計情報を取得
  Map<String, dynamic> getManualHighLowStats() {
    final highPoints = _manualHighLowPoints.where((point) => point.isHigh).toList();
    final lowPoints = _manualHighLowPoints.where((point) => !point.isHigh).toList();
    
    return {
      'total': _manualHighLowPoints.length,
      'highPoints': highPoints.length,
      'lowPoints': lowPoints.length,
      'oldestPoint': _manualHighLowPoints.isNotEmpty ? _manualHighLowPoints.map((p) => p.timestamp).reduce((a, b) => a < b ? a : b) : null,
      'newestPoint': _manualHighLowPoints.isNotEmpty ? _manualHighLowPoints.map((p) => p.timestamp).reduce((a, b) => a > b ? a : b) : null,
    };
  }

  /// 手動高低点コントローラーを破棄
  void disposeManualHighLowController() {
    _manualHighLowPoints.clear();
    _isManualHighLowMode = false;
    Log.info('ManualHighLowController', '手動高低点コントローラーを破棄しました');
  }

  /// X座標からK線インデックスを取得（ホストクラスから実装を借用）
  int getCandleIndexFromX(double x, double chartWidth) {
    // このメソッドはホストクラスで実装される必要があります
    // ここでは基本的な実装を提供します
    if (data.isEmpty) return -1;
    
    final double candleWidth = this.candleWidth * scale;
    final double startX = (chartWidth - data.length * candleWidth) / 2;
    final int index = ((x - startX) / candleWidth).floor();
    
    return index.clamp(0, data.length - 1);
  }
}
