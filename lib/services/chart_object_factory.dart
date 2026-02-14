import '../models/chart_object.dart';
import '../widgets/chart_view_controller.dart';

class ChartObjectFactory {
  const ChartObjectFactory._();

  static List<ChartObject> build({
    required ChartViewController controller,
    List<TrendLineObject> trendLines = const [],
    String? selectedTrendLineId,
    bool includeTrendFiltering = false,
    bool includeFibonacciForSelectedTrendLine = false,
  }) {
    final objects = <ChartObject>[];

    _appendLayer2IndicatorObjects(
      objects,
      controller: controller,
      includeTrendFiltering: includeTrendFiltering,
    );

    _appendLayer3UserInteractionObjects(
      objects,
      controller: controller,
      trendLines: trendLines,
      selectedTrendLineId: selectedTrendLineId,
      includeFibonacciForSelectedTrendLine: includeFibonacciForSelectedTrendLine,
    );

    return objects;
  }

  static void _appendLayer2IndicatorObjects(
    List<ChartObject> objects, {
    required ChartViewController controller,
    required bool includeTrendFiltering,
  }) {
    final mergedWavePoints = controller.getMergedWavePoints();
    if (controller.isWavePointsVisible && mergedWavePoints.isNotEmpty) {
      for (int i = 0; i < mergedWavePoints.length; i++) {
        final point = mergedWavePoints[i];
        final type = point['type'] as String;
        objects.add(
          WavePointObject(
            id: 'wave-point-$i-${point['index']}',
            index: point['index'] as int,
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
                (point) => CandleAnchor(
                  index: point['index'] as int,
                  price: (point['value'] as num).toDouble(),
                ),
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

    if (includeTrendFiltering) {
      final filtered = controller.filteredWavePoints;
      if (filtered != null) {
        for (int i = 0; i < filtered.originalPoints.length; i++) {
          final point = filtered.originalPoints[i];
          final type = point['type'] as String;
          objects.add(
            FilteredWavePointObject(
              id: 'filtered-original-$i-${point['index']}',
              index: point['index'] as int,
              price: (point['value'] as num).toDouble(),
              pointKind: type == 'high' ? 'original_high' : 'original_low',
              layer: ChartObjectLayer.aboveIndicators,
            ),
          );
        }

        for (int i = 0; i < filtered.filteredHighPoints.length; i++) {
          final point = filtered.filteredHighPoints[i];
          objects.add(
            FilteredWavePointObject(
              id: 'filtered-high-$i-${point['index']}',
              index: point['index'] as int,
              price: (point['value'] as num).toDouble(),
              pointKind: 'filtered_high',
              layer: ChartObjectLayer.aboveIndicators,
            ),
          );
        }

        for (int i = 0; i < filtered.filteredLowPoints.length; i++) {
          final point = filtered.filteredLowPoints[i];
          objects.add(
            FilteredWavePointObject(
              id: 'filtered-low-$i-${point['index']}',
              index: point['index'] as int,
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
              start: CandleAnchor(index: line.startIndex, price: line.startValue),
              end: CandleAnchor(index: line.endIndex, price: line.endValue),
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
                    (point) => CandleAnchor(
                      index: point['index'] as int,
                      price: (point['value'] as num).toDouble(),
                    ),
                  )
                  .toList(),
              color: '#FF9800',
              width: 4.0,
              layer: ChartObjectLayer.aboveIndicators,
            ),
          );
        }

        if (filtered.fittedCurve.length > 1) {
          objects.add(
            FittedCurveObject(
              id: 'analysis-fitted-curve',
              points: filtered.fittedCurve
                  .map(
                    (point) => CandleAnchor(
                      index: point['index'] as int,
                      price: (point['value'] as num).toDouble(),
                    ),
                  )
                  .toList(),
              color: '#2196F3',
              width: 2.0,
              layer: ChartObjectLayer.aboveIndicators,
            ),
          );
        }
      }
    }
  }

  static void _appendLayer3UserInteractionObjects(
    List<ChartObject> objects, {
    required ChartViewController controller,
    required List<TrendLineObject> trendLines,
    required String? selectedTrendLineId,
    required bool includeFibonacciForSelectedTrendLine,
  }) {
    for (final line in controller.getVisibleVerticalLines()) {
      objects.add(
        VerticalLineObject(
          id: line.id,
          timestamp: line.timestamp,
          color: line.color,
          width: line.width,
          layer: ChartObjectLayer.interaction,
        ),
      );
    }

    for (final line in trendLines) {
      objects.add(
        TrendLineObject(
          id: line.id,
          startIndex: line.startIndex,
          startPrice: line.startPrice,
          endIndex: line.endIndex,
          endPrice: line.endPrice,
          color: line.color,
          width: line.width,
          selected: selectedTrendLineId == line.id,
          layer: line.layer,
        ),
      );
    }

    if (includeFibonacciForSelectedTrendLine && selectedTrendLineId != null) {
      TrendLineObject? selected;
      for (final line in trendLines) {
        if (line.id == selectedTrendLineId) {
          selected = line;
          break;
        }
      }
      if (selected != null) {
        objects.add(
          FibonacciRetracementObject(
            id: 'fib-${selected.id}',
            start: CandleAnchor(index: selected.startIndex, price: selected.startPrice),
            end: CandleAnchor(index: selected.endIndex, price: selected.endPrice),
            layer: ChartObjectLayer.interaction,
          ),
        );
      }
    }

    for (final selection in controller.getVisibleKlineSelections()) {
      objects.add(
        KlineSelectionObject(
          id: selection.id,
          startTimestamp: selection.startTimestamp,
          endTimestamp: selection.endTimestamp,
          klineCount: selection.klineCount,
          color: selection.color,
          opacity: selection.opacity,
          layer: ChartObjectLayer.interaction,
        ),
      );
    }

    if (controller.selectionStartX != null && controller.selectionEndX != null) {
      objects.add(
        ActiveKlineSelectionObject(
          id: 'active-selection',
          startX: controller.selectionStartX!,
          endX: controller.selectionEndX!,
          selectedKlineCount: controller.selectedKlineCount,
          layer: ChartObjectLayer.interaction,
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
