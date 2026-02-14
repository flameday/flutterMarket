import '../models/chart_object.dart';
import '../widgets/chart_view_controller.dart';

class ChartObjectLayer3InteractionBuilder {
  const ChartObjectLayer3InteractionBuilder._();

  static void append(
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
}
