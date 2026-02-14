enum ChartObjectLayer {
  belowIndicators,
  aboveIndicators,
  interaction,
}

abstract class ChartObject {
  const ChartObject({
    required this.id,
    this.layer = ChartObjectLayer.aboveIndicators,
    this.visible = true,
  });

  final String id;
  final ChartObjectLayer layer;
  final bool visible;
}

class VerticalLineObject extends ChartObject {
  const VerticalLineObject({
    required super.id,
    required this.timestamp,
    this.color = '#FF0000',
    this.width = 2.0,
    super.layer = ChartObjectLayer.aboveIndicators,
    super.visible = true,
  });

  final int timestamp;
  final String color;
  final double width;
}

class TrendLineObject extends ChartObject {
  const TrendLineObject({
    required super.id,
    required this.startIndex,
    required this.startPrice,
    required this.endIndex,
    required this.endPrice,
    this.color = '#FFD700',
    this.width = 2.0,
    this.selected = false,
    super.layer = ChartObjectLayer.aboveIndicators,
    super.visible = true,
  });

  final int startIndex;
  final double startPrice;
  final int endIndex;
  final double endPrice;
  final String color;
  final double width;
  final bool selected;
}

class KlineSelectionObject extends ChartObject {
  const KlineSelectionObject({
    required super.id,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.klineCount,
    this.color = '#2196F3',
    this.opacity = 0.2,
    super.layer = ChartObjectLayer.interaction,
    super.visible = true,
  });

  final int startTimestamp;
  final int endTimestamp;
  final int klineCount;
  final String color;
  final double opacity;
}

class ActiveKlineSelectionObject extends ChartObject {
  const ActiveKlineSelectionObject({
    required super.id,
    required this.startX,
    required this.endX,
    required this.selectedKlineCount,
    super.layer = ChartObjectLayer.interaction,
    super.visible = true,
  });

  final double startX;
  final double endX;
  final int selectedKlineCount;
}

class CandleAnchor {
  const CandleAnchor({
    required this.index,
    required this.price,
  });

  final int index;
  final double price;
}

class WavePointObject extends ChartObject {
  const WavePointObject({
    required super.id,
    required this.index,
    required this.price,
    required this.isHigh,
    super.layer = ChartObjectLayer.aboveIndicators,
    super.visible = true,
  });

  final int index;
  final double price;
  final bool isHigh;
}

class WavePolylineObject extends ChartObject {
  const WavePolylineObject({
    required super.id,
    required this.points,
    this.color = '#FFA500',
    this.width = 2.0,
    super.layer = ChartObjectLayer.aboveIndicators,
    super.visible = true,
  });

  final List<CandleAnchor> points;
  final String color;
  final double width;
}

class ManualHighLowObject extends ChartObject {
  const ManualHighLowObject({
    required super.id,
    required this.timestamp,
    required this.price,
    required this.isHigh,
    super.layer = ChartObjectLayer.aboveIndicators,
    super.visible = true,
  });

  final int timestamp;
  final double price;
  final bool isHigh;
}

class FibonacciRetracementObject extends ChartObject {
  const FibonacciRetracementObject({
    required super.id,
    required this.start,
    required this.end,
    this.levels = const [0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0],
    this.color = '#9C27B0',
    this.width = 1.0,
    super.layer = ChartObjectLayer.aboveIndicators,
    super.visible = true,
  });

  final CandleAnchor start;
  final CandleAnchor end;
  final List<double> levels;
  final String color;
  final double width;
}

class FilteredWavePointObject extends ChartObject {
  const FilteredWavePointObject({
    required super.id,
    required this.index,
    required this.price,
    required this.pointKind,
    super.layer = ChartObjectLayer.aboveIndicators,
    super.visible = true,
  });

  final int index;
  final double price;
  final String pointKind; // original_high/original_low/filtered_high/filtered_low
}

class TrendAnalysisLineObject extends ChartObject {
  const TrendAnalysisLineObject({
    required super.id,
    required this.start,
    required this.end,
    required this.color,
    required this.width,
    this.direction = 'horizontal',
    super.layer = ChartObjectLayer.aboveIndicators,
    super.visible = true,
  });

  final CandleAnchor start;
  final CandleAnchor end;
  final String color;
  final double width;
  final String direction; // upward/downward/horizontal
}

class SmoothTrendPolylineObject extends ChartObject {
  const SmoothTrendPolylineObject({
    required super.id,
    required this.points,
    this.color = '#FFA500',
    this.width = 4.0,
    super.layer = ChartObjectLayer.aboveIndicators,
    super.visible = true,
  });

  final List<CandleAnchor> points;
  final String color;
  final double width;
}

class FittedCurveObject extends ChartObject {
  const FittedCurveObject({
    required super.id,
    required this.points,
    this.color = '#2196F3',
    this.width = 2.0,
    super.layer = ChartObjectLayer.aboveIndicators,
    super.visible = true,
  });

  final List<CandleAnchor> points;
  final String color;
  final double width;
}

class CircleObject extends ChartObject {
  const CircleObject({
    required super.id,
    required this.start,
    required this.end,
    this.color = '#00BCD4',
    this.width = 2.0,
    super.layer = ChartObjectLayer.aboveIndicators,
    super.visible = true,
  });

  final CandleAnchor start;
  final CandleAnchor end;
  final String color;
  final double width;
}

class RectangleObject extends ChartObject {
  const RectangleObject({
    required super.id,
    required this.start,
    required this.end,
    this.color = '#03A9F4',
    this.width = 2.0,
    this.fillAlpha = 0.12,
    super.layer = ChartObjectLayer.aboveIndicators,
    super.visible = true,
  });

  final CandleAnchor start;
  final CandleAnchor end;
  final String color;
  final double width;
  final double fillAlpha;
}

class FreePolylineObject extends ChartObject {
  const FreePolylineObject({
    required super.id,
    required this.points,
    this.color = '#FFC107',
    this.width = 2.0,
    super.layer = ChartObjectLayer.aboveIndicators,
    super.visible = true,
  });

  final List<CandleAnchor> points;
  final String color;
  final double width;
}
