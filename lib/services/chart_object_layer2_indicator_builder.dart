import '../models/chart_object.dart';
import '../widgets/chart_view_controller.dart';

class ChartObjectLayer2IndicatorBuilder {
  const ChartObjectLayer2IndicatorBuilder._();

  static void append(
    List<ChartObject> objects, {
    required ChartViewController controller,
    required bool includeTrendFiltering,
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
          layer: ChartObjectLayer.aboveIndicators,
        ),
      );
    }

    if (!includeTrendFiltering) return;

    final filtered = controller.filteredWavePoints;
    if (filtered == null) return;

    for (int i = 0; i < filtered.originalPoints.length; i++) {
      final point = filtered.originalPoints[i];
      final type = point['type'] as String;
      final int pointIndex = point['index'] as int;
      objects.add(
        FilteredWavePointObject(
          id: 'filtered-original-$i-${point['index']}',
          index: pointIndex,
          timestamp: timestampFromIndex(pointIndex),
          price: (point['value'] as num).toDouble(),
          pointKind: type == 'high' ? 'original_high' : 'original_low',
          layer: ChartObjectLayer.aboveIndicators,
        ),
      );
    }

    for (int i = 0; i < filtered.filteredHighPoints.length; i++) {
      final point = filtered.filteredHighPoints[i];
      final int pointIndex = point['index'] as int;
      objects.add(
        FilteredWavePointObject(
          id: 'filtered-high-$i-${point['index']}',
          index: pointIndex,
          timestamp: timestampFromIndex(pointIndex),
          price: (point['value'] as num).toDouble(),
          pointKind: 'filtered_high',
          layer: ChartObjectLayer.aboveIndicators,
        ),
      );
    }

    for (int i = 0; i < filtered.filteredLowPoints.length; i++) {
      final point = filtered.filteredLowPoints[i];
      final int pointIndex = point['index'] as int;
      objects.add(
        FilteredWavePointObject(
          id: 'filtered-low-$i-${point['index']}',
          index: pointIndex,
          timestamp: timestampFromIndex(pointIndex),
          price: (point['value'] as num).toDouble(),
          pointKind: 'filtered_low',
          layer: ChartObjectLayer.aboveIndicators,
        ),
      );
    }

    for (int i = 0; i < filtered.trendLines.length; i++) {
      final line = filtered.trendLines[i];
      final style = _trendLineStyle(line.strengthLevel, line.type);

      objects.add(
        TrendAnalysisLineObject(
          id: 'analysis-trend-$i-${line.startIndex}-${line.endIndex}',
          start: CandleAnchor(
            index: line.startIndex,
            price: line.startValue,
            timestamp: timestampFromIndex(line.startIndex),
          ),
          end: CandleAnchor(
            index: line.endIndex,
            price: line.endValue,
            timestamp: timestampFromIndex(line.endIndex),
          ),
          color: style.$1,
          width: style.$2,
          direction: line.direction,
          layer: ChartObjectLayer.aboveIndicators,
        ),
      );
    }

    final smoothPoints = filtered.smoothTrendLine?.points;
    if (smoothPoints != null && smoothPoints.length > 1) {
      objects.add(
        SmoothTrendPolylineObject(
          id: 'analysis-smooth-trend',
          points: smoothPoints
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
          color: '#FF9800',
          width: 4.0,
          layer: ChartObjectLayer.aboveIndicators,
        ),
      );
    }
  }

  static (String, double) _trendLineStyle(String strengthLevel, String type) {
    switch (strengthLevel) {
      case 'strong':
        return (type == 'high' ? '#4CAF50' : '#F44336', 3.0);
      case 'moderate':
        return (type == 'high' ? '#81C784' : '#E57373', 2.5);
      case 'weak':
        return (type == 'high' ? '#A5D6A7' : '#EF9A9A', 2.0);
      default:
        return (type == 'high' ? '#C8E6C9' : '#FFCDD2', 1.5);
    }
  }
}
