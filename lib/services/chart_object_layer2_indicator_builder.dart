import '../models/chart_object.dart';
import '../widgets/chart_view_controller.dart';

class ChartObjectLayer2IndicatorBuilder {
  const ChartObjectLayer2IndicatorBuilder._();

  static void append(
    List<ChartObject> objects, {
    required ChartViewController controller,
  }) {
    int? timestampFromIndex(dynamic rawIndex) {
      if (rawIndex is! int) return null;
      return controller.timestampAtIndex(rawIndex);
    }

    final mergedWavePoints = controller.getMergedWavePoints();
    if (controller.isWavePointsVisible && mergedWavePoints.isNotEmpty) {
      for (int i = 0; i < mergedWavePoints.length; i++) {
        final point = mergedWavePoints[i];
        final type = point['type'] as String;
        final int pointIndex = point['index'] as int;
        objects.add(
          WavePointObject(
            id: 'wave-point-$i-${point['index']}',
            index: pointIndex,
            timestamp: timestampFromIndex(pointIndex),
            price: (point['value'] as num).toDouble(),
            isHigh: type == 'high',
            layer: ChartObjectLayer.aboveIndicators,
          ),
        );
      }
    }

    if (controller.isWavePointsVisible &&
        controller.isWavePointsLineVisible &&
        mergedWavePoints.length > 1) {
      objects.add(
        WavePolylineObject(
          id: 'wave-polyline-main',
          points: mergedWavePoints
              .map(
                (point) {
                  final int pointIndex = point['index'] as int;
                  return CandleAnchor(
                    index: pointIndex,
                    price: (point['value'] as num).toDouble(),
                    timestamp: timestampFromIndex(pointIndex),
                  );
                },
              )
              .toList(),
          color: '#FFA500',
          width: 2.0,
          layer: ChartObjectLayer.aboveIndicators,
        ),
      );
    }

    for (final point in controller.getVisibleManualHighLowPoints()) {
      objects.add(
        ManualHighLowObject(
          id: point.id,
          timestamp: point.timestamp,
          price: point.price,
          isHigh: point.isHigh,
          markerColor: point.isHigh
              ? controller.highMarkerColor
              : controller.lowMarkerColor,
          markerShape: controller.highLowMarkerShape,
          markerSize: controller.highLowMarkerSize,
          markerOffset: controller.highLowMarkerOffset,
          layer: ChartObjectLayer.aboveIndicators,
        ),
      );
    }

    final strategyPoints = controller.getStrategyHighLowPoints();
    for (final point in strategyPoints) {
      objects.add(
        ManualHighLowObject(
          id: point.id,
          timestamp: point.timestamp,
          price: point.price,
          isHigh: point.isHigh,
          markerColor: point.isHigh
              ? controller.highMarkerColor
              : controller.lowMarkerColor,
          markerShape: controller.highLowMarkerShape,
          markerSize: controller.highLowMarkerSize,
          markerOffset: controller.highLowMarkerOffset,
          layer: ChartObjectLayer.aboveIndicators,
        ),
      );
    }

    if (controller.isStrategyPolylineVisible && strategyPoints.length > 1) {
      objects.add(
        WavePolylineObject(
          id: 'strategy-high-low-polyline',
          points: strategyPoints
              .map(
                (point) => CandleAnchor(
                  index: -1,
                  price: point.price,
                  timestamp: point.timestamp,
                ),
              )
              .toList(),
          color: controller.strategyPolylineColor,
          width: controller.strategyPolylineWidth,
          layer: ChartObjectLayer.aboveIndicators,
        ),
      );
    }

  }
}
