import '../models/manual_high_low_point.dart';
import '../models/price_data.dart';

abstract class ManualHighLowControllerHost {
  void notifyUIUpdate();
  List<PriceData> get data;
  int get startIndex;
  int get endIndex;
  int getCandleIndexFromX(double x, double chartWidth);
  String get currentTimeframe;
}

mixin ManualHighLowControllerMixin on ManualHighLowControllerHost {
  final List<ManualHighLowPoint> _manualHighLowPoints = [];

  void initManualHighLowPoints() {
    _manualHighLowPoints.clear();
  }

  Future<void> toggleManualHighLowPointAtPosition(
    double chartX,
    double chartY,
    double chartWidth,
    double chartHeight,
    double minPrice,
    double maxPrice,
  ) async {
    if (data.isEmpty) return;

    final int candleIndex = getCandleIndexFromX(chartX, chartWidth);
    if (candleIndex < 0 || candleIndex >= data.length) return;

    final PriceData candle = data[candleIndex];
    final int timestamp = candle.timestamp;

    final int existingIndex = _manualHighLowPoints.indexWhere((p) => p.timestamp == timestamp);
    if (existingIndex >= 0) {
      _manualHighLowPoints.removeAt(existingIndex);
      notifyUIUpdate();
      return;
    }

    final double clickedPrice = _yToPrice(chartY, chartHeight, minPrice, maxPrice);
    final bool isHigh = _isCloserToHigh(clickedPrice, candle);

    _manualHighLowPoints.add(
      ManualHighLowPoint(
        id: 'manual-$timestamp-${DateTime.now().millisecondsSinceEpoch}',
        timestamp: timestamp,
        price: isHigh ? candle.high : candle.low,
        isHigh: isHigh,
        createdAt: DateTime.now(),
        timeframe: currentTimeframe,
      ),
    );

    notifyUIUpdate();
  }

  List<ManualHighLowPoint> getVisibleManualHighLowPoints() {
    if (_manualHighLowPoints.isEmpty || data.isEmpty) return const [];

    final int safeStart = startIndex.clamp(0, data.length - 1);
    final int safeEndExclusive = endIndex.clamp(0, data.length);
    if (safeEndExclusive <= safeStart) return const [];

    final int minTs = data[safeStart].timestamp;
    final int maxTs = data[safeEndExclusive - 1].timestamp;

    return _manualHighLowPoints
        .where((point) => point.timestamp >= minTs && point.timestamp <= maxTs)
        .toList(growable: false);
  }

  void disposeManualHighLowController() {
    _manualHighLowPoints.clear();
  }

  double _yToPrice(double y, double chartHeight, double minPrice, double maxPrice) {
    if (chartHeight <= 0 || maxPrice == minPrice) {
      return minPrice;
    }
    final double normalized = ((chartHeight - y) / chartHeight).clamp(0.0, 1.0);
    return minPrice + normalized * (maxPrice - minPrice);
  }

  bool _isCloserToHigh(double price, PriceData candle) {
    final double highDistance = (candle.high - price).abs();
    final double lowDistance = (price - candle.low).abs();
    return highDistance <= lowDistance;
  }
}
