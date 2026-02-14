import '../models/chart_object.dart';
import '../models/drawing_tool.dart';

class Layer3DrawingObjectBuilder {
  const Layer3DrawingObjectBuilder._();

  static ChartObject? createDrawingObject({
    required DrawingTool tool,
    required CandleAnchor start,
    required CandleAnchor end,
    required int uniqueId,
  }) {
    switch (tool) {
      case DrawingTool.trendLine:
        return TrendLineObject(
          id: uniqueId.toString(),
          startIndex: start.index,
          startPrice: start.price,
          endIndex: end.index,
          endPrice: end.price,
          layer: ChartObjectLayer.interaction,
        );
      case DrawingTool.circle:
        return CircleObject(
          id: 'circle-$uniqueId',
          start: start,
          end: end,
          layer: ChartObjectLayer.interaction,
        );
      case DrawingTool.rectangle:
        return RectangleObject(
          id: 'rect-$uniqueId',
          start: start,
          end: end,
          layer: ChartObjectLayer.interaction,
        );
      case DrawingTool.fibonacci:
        return FibonacciRetracementObject(
          id: 'fib-user-$uniqueId',
          start: start,
          end: end,
          layer: ChartObjectLayer.interaction,
        );
      case DrawingTool.none:
      case DrawingTool.polyline:
        return null;
    }
  }

  static ChartObject? createToolPreviewObject({
    required DrawingTool tool,
    required CandleAnchor start,
    required CandleAnchor preview,
  }) {
    switch (tool) {
      case DrawingTool.trendLine:
        return TrendLineObject(
          id: 'trend-preview',
          startIndex: start.index,
          startPrice: start.price,
          endIndex: preview.index,
          endPrice: preview.price,
          color: '#66FFD700',
          layer: ChartObjectLayer.interaction,
        );
      case DrawingTool.circle:
        return CircleObject(
          id: 'circle-preview',
          start: start,
          end: preview,
          color: '#6600BCD4',
          layer: ChartObjectLayer.interaction,
        );
      case DrawingTool.rectangle:
        return RectangleObject(
          id: 'rect-preview',
          start: start,
          end: preview,
          color: '#6603A9F4',
          fillAlpha: 0.08,
          layer: ChartObjectLayer.interaction,
        );
      case DrawingTool.fibonacci:
        return FibonacciRetracementObject(
          id: 'fib-preview',
          start: start,
          end: preview,
          color: '#669C27B0',
          layer: ChartObjectLayer.interaction,
        );
      case DrawingTool.none:
      case DrawingTool.polyline:
        return null;
    }
  }

  static FreePolylineObject createPolylineObject({
    required List<CandleAnchor> points,
    required int uniqueId,
  }) {
    return FreePolylineObject(
      id: 'polyline-$uniqueId',
      points: points,
      layer: ChartObjectLayer.interaction,
    );
  }

  static ChartObject? createPolylinePreviewObject({
    required DrawingTool tool,
    required List<CandleAnchor> pendingPoints,
    required CandleAnchor? preview,
  }) {
    if (tool != DrawingTool.polyline || pendingPoints.isEmpty) {
      return null;
    }

    final previewPoints = List<CandleAnchor>.from(pendingPoints);
    if (preview != null) {
      final last = previewPoints.last;
      if (last.index != preview.index || (last.price - preview.price).abs() > 0.0000001) {
        previewPoints.add(preview);
      }
    }

    if (previewPoints.length < 2) return null;

    return FreePolylineObject(
      id: 'polyline-preview',
      points: previewPoints,
      color: '#66FFC107',
      layer: ChartObjectLayer.interaction,
    );
  }
}
