import 'dart:math' as math;

import '../models/chart_object.dart';
import 'chart_object_interaction_service.dart';

class UserDrawingLayer3Manager {
  final List<TrendLineObject> trendLines = [];
  final List<CircleObject> circleObjects = [];
  final List<RectangleObject> rectangleObjects = [];
  final List<FibonacciRetracementObject> fibonacciObjects = [];
  final List<FreePolylineObject> polylineObjects = [];

  void addDrawingObject(ChartObject object) {
    if (object is TrendLineObject) {
      trendLines.add(object);
      return;
    }
    if (object is CircleObject) {
      circleObjects.add(object);
      return;
    }
    if (object is RectangleObject) {
      rectangleObjects.add(object);
      return;
    }
    if (object is FibonacciRetracementObject) {
      fibonacciObjects.add(object);
      return;
    }
    if (object is FreePolylineObject) {
      polylineObjects.add(object);
    }
  }

  void appendLayer3UserDrawings(List<ChartObject> objects) {
    objects.addAll(circleObjects);
    objects.addAll(rectangleObjects);
    objects.addAll(fibonacciObjects);
    objects.addAll(polylineObjects);
  }

  int trendLineIndexById(String id) {
    return trendLines.indexWhere((line) => line.id == id);
  }

  bool updateTrendLineById(
    String id,
    TrendLineObject Function(TrendLineObject line) updater,
  ) {
    final int index = trendLineIndexById(id);
    if (index < 0) return false;
    trendLines[index] = updater(trendLines[index]);
    return true;
  }

  bool adjustTrendLineLengthById({
    required String id,
    required double factor,
    required int Function(int index) clampDataIndex,
    required int? Function(int index) indexToTimestamp,
  }) {
    return updateTrendLineById(id, (line) {
      final double dx = (line.endIndex - line.startIndex).toDouble();
      final double dy = line.endPrice - line.startPrice;
      final double newEndIndex = line.startIndex + dx * factor;
      final double newEndPrice = line.startPrice + dy * factor;
      final int nextEndIndex = clampDataIndex(newEndIndex.round());
      return _copyTrendLine(
        line,
        endIndex: nextEndIndex,
        endPrice: newEndPrice,
        endTimestamp: indexToTimestamp(nextEndIndex),
      );
    });
  }

  bool adjustTrendLineAngleById({
    required String id,
    required double deltaDegrees,
    required int Function(int index) clampDataIndex,
    required int? Function(int index) indexToTimestamp,
  }) {
    return updateTrendLineById(id, (line) {
      final double dx = (line.endIndex - line.startIndex).toDouble();
      final double dy = line.endPrice - line.startPrice;
      final double length = math.sqrt(dx * dx + dy * dy);
      if (length < 0.0000001) return line;

      final double angle = math.atan2(dy, dx) + (deltaDegrees * math.pi / 180.0);
      final double newDx = math.cos(angle) * length;
      final double newDy = math.sin(angle) * length;

      final int nextEndIndex = clampDataIndex((line.startIndex + newDx).round());
      return _copyTrendLine(
        line,
        endIndex: nextEndIndex,
        endPrice: line.startPrice + newDy,
        endTimestamp: indexToTimestamp(nextEndIndex),
      );
    });
  }

  bool removeByTypeAndId(Type objectType, String id) {
    if (objectType == TrendLineObject) {
      return _removeById(trendLines, id);
    }
    if (objectType == CircleObject) {
      return _removeById(circleObjects, id);
    }
    if (objectType == RectangleObject) {
      return _removeById(rectangleObjects, id);
    }
    if (objectType == FibonacciRetracementObject) {
      return _removeById(fibonacciObjects, id);
    }
    if (objectType == FreePolylineObject) {
      return _removeById(polylineObjects, id);
    }
    return false;
  }

  void updateObjectDuringDrag({
    required String id,
    required Type objectType,
    required ObjectDragTarget target,
    required int newIndex,
    required int? newTimestamp,
    required double newPrice,
    required int indexDelta,
    required double priceDelta,
    required int Function(int index) clampDataIndex,
    required int? Function(int index) indexToTimestamp,
  }) {
    if (objectType == TrendLineObject) {
      _updateTrendLineDuringDrag(
        id: id,
        target: target,
        newIndex: newIndex,
        newTimestamp: newTimestamp,
        newPrice: newPrice,
        indexDelta: indexDelta,
        priceDelta: priceDelta,
        clampDataIndex: clampDataIndex,
        indexToTimestamp: indexToTimestamp,
      );
      return;
    }

    if (objectType == CircleObject) {
      _updateCircleDuringDrag(
        id: id,
        target: target,
        newIndex: newIndex,
        newTimestamp: newTimestamp,
        newPrice: newPrice,
        indexDelta: indexDelta,
        priceDelta: priceDelta,
        clampDataIndex: clampDataIndex,
        indexToTimestamp: indexToTimestamp,
      );
      return;
    }

    if (objectType == RectangleObject) {
      _updateRectangleDuringDrag(
        id: id,
        target: target,
        newIndex: newIndex,
        newTimestamp: newTimestamp,
        newPrice: newPrice,
        indexDelta: indexDelta,
        priceDelta: priceDelta,
        clampDataIndex: clampDataIndex,
        indexToTimestamp: indexToTimestamp,
      );
      return;
    }

    if (objectType == FibonacciRetracementObject) {
      _updateFibonacciDuringDrag(
        id: id,
        target: target,
        newIndex: newIndex,
        newTimestamp: newTimestamp,
        newPrice: newPrice,
        indexDelta: indexDelta,
        priceDelta: priceDelta,
        clampDataIndex: clampDataIndex,
        indexToTimestamp: indexToTimestamp,
      );
      return;
    }

    if (objectType == FreePolylineObject) {
      _updatePolylineDuringDrag(
        id: id,
        target: target,
        indexDelta: indexDelta,
        priceDelta: priceDelta,
        clampDataIndex: clampDataIndex,
        indexToTimestamp: indexToTimestamp,
      );
    }
  }

  void _updateTrendLineDuringDrag({
    required String id,
    required ObjectDragTarget target,
    required int newIndex,
    required int? newTimestamp,
    required double newPrice,
    required int indexDelta,
    required double priceDelta,
    required int Function(int index) clampDataIndex,
    required int? Function(int index) indexToTimestamp,
  }) {
    final int idx = trendLines.indexWhere((line) => line.id == id);
    if (idx < 0) return;

    final line = trendLines[idx];
    if (target == ObjectDragTarget.start) {
      trendLines[idx] = TrendLineObject(
        id: line.id,
        startIndex: newIndex,
        startPrice: newPrice,
        startTimestamp: newTimestamp ?? indexToTimestamp(newIndex),
        endIndex: line.endIndex,
        endPrice: line.endPrice,
        endTimestamp: line.endTimestamp,
        color: line.color,
        width: line.width,
        selected: line.selected,
        layer: line.layer,
        visible: line.visible,
      );
    } else if (target == ObjectDragTarget.end) {
      trendLines[idx] = TrendLineObject(
        id: line.id,
        startIndex: line.startIndex,
        startPrice: line.startPrice,
        startTimestamp: line.startTimestamp,
        endIndex: newIndex,
        endPrice: newPrice,
        endTimestamp: newTimestamp ?? indexToTimestamp(newIndex),
        color: line.color,
        width: line.width,
        selected: line.selected,
        layer: line.layer,
        visible: line.visible,
      );
    } else {
      final int nextStartIndex = clampDataIndex(line.startIndex + indexDelta);
      final int nextEndIndex = clampDataIndex(line.endIndex + indexDelta);
      trendLines[idx] = TrendLineObject(
        id: line.id,
        startIndex: nextStartIndex,
        startPrice: line.startPrice + priceDelta,
        startTimestamp: indexToTimestamp(nextStartIndex),
        endIndex: nextEndIndex,
        endPrice: line.endPrice + priceDelta,
        endTimestamp: indexToTimestamp(nextEndIndex),
        color: line.color,
        width: line.width,
        selected: line.selected,
        layer: line.layer,
        visible: line.visible,
      );
    }
  }

  void _updateCircleDuringDrag({
    required String id,
    required ObjectDragTarget target,
    required int newIndex,
    required int? newTimestamp,
    required double newPrice,
    required int indexDelta,
    required double priceDelta,
    required int Function(int index) clampDataIndex,
    required int? Function(int index) indexToTimestamp,
  }) {
    final int idx = circleObjects.indexWhere((item) => item.id == id);
    if (idx < 0) return;

    final object = circleObjects[idx];
    if (target == ObjectDragTarget.start) {
      final int nextIndex = clampDataIndex(newIndex);
      circleObjects[idx] = CircleObject(
        id: object.id,
        start: CandleAnchor(
          index: nextIndex,
          price: newPrice,
          timestamp: newTimestamp ?? indexToTimestamp(nextIndex),
        ),
        end: object.end,
        color: object.color,
        width: object.width,
        layer: object.layer,
        visible: object.visible,
      );
    } else if (target == ObjectDragTarget.end) {
      final int nextIndex = clampDataIndex(newIndex);
      circleObjects[idx] = CircleObject(
        id: object.id,
        start: object.start,
        end: CandleAnchor(
          index: nextIndex,
          price: newPrice,
          timestamp: newTimestamp ?? indexToTimestamp(nextIndex),
        ),
        color: object.color,
        width: object.width,
        layer: object.layer,
        visible: object.visible,
      );
    } else {
      final int nextStartIndex = clampDataIndex(object.start.index + indexDelta);
      final int nextEndIndex = clampDataIndex(object.end.index + indexDelta);
      circleObjects[idx] = CircleObject(
        id: object.id,
        start: CandleAnchor(
          index: nextStartIndex,
          price: object.start.price + priceDelta,
          timestamp: indexToTimestamp(nextStartIndex),
        ),
        end: CandleAnchor(
          index: nextEndIndex,
          price: object.end.price + priceDelta,
          timestamp: indexToTimestamp(nextEndIndex),
        ),
        color: object.color,
        width: object.width,
        layer: object.layer,
        visible: object.visible,
      );
    }
  }

  void _updateRectangleDuringDrag({
    required String id,
    required ObjectDragTarget target,
    required int newIndex,
    required int? newTimestamp,
    required double newPrice,
    required int indexDelta,
    required double priceDelta,
    required int Function(int index) clampDataIndex,
    required int? Function(int index) indexToTimestamp,
  }) {
    final int idx = rectangleObjects.indexWhere((item) => item.id == id);
    if (idx < 0) return;

    final object = rectangleObjects[idx];
    if (target == ObjectDragTarget.start) {
      final int nextIndex = clampDataIndex(newIndex);
      rectangleObjects[idx] = RectangleObject(
        id: object.id,
        start: CandleAnchor(
          index: nextIndex,
          price: newPrice,
          timestamp: newTimestamp ?? indexToTimestamp(nextIndex),
        ),
        end: object.end,
        color: object.color,
        width: object.width,
        fillAlpha: object.fillAlpha,
        layer: object.layer,
        visible: object.visible,
      );
    } else if (target == ObjectDragTarget.end) {
      final int nextIndex = clampDataIndex(newIndex);
      rectangleObjects[idx] = RectangleObject(
        id: object.id,
        start: object.start,
        end: CandleAnchor(
          index: nextIndex,
          price: newPrice,
          timestamp: newTimestamp ?? indexToTimestamp(nextIndex),
        ),
        color: object.color,
        width: object.width,
        fillAlpha: object.fillAlpha,
        layer: object.layer,
        visible: object.visible,
      );
    } else {
      final int nextStartIndex = clampDataIndex(object.start.index + indexDelta);
      final int nextEndIndex = clampDataIndex(object.end.index + indexDelta);
      rectangleObjects[idx] = RectangleObject(
        id: object.id,
        start: CandleAnchor(
          index: nextStartIndex,
          price: object.start.price + priceDelta,
          timestamp: indexToTimestamp(nextStartIndex),
        ),
        end: CandleAnchor(
          index: nextEndIndex,
          price: object.end.price + priceDelta,
          timestamp: indexToTimestamp(nextEndIndex),
        ),
        color: object.color,
        width: object.width,
        fillAlpha: object.fillAlpha,
        layer: object.layer,
        visible: object.visible,
      );
    }
  }

  void _updateFibonacciDuringDrag({
    required String id,
    required ObjectDragTarget target,
    required int newIndex,
    required int? newTimestamp,
    required double newPrice,
    required int indexDelta,
    required double priceDelta,
    required int Function(int index) clampDataIndex,
    required int? Function(int index) indexToTimestamp,
  }) {
    final int idx = fibonacciObjects.indexWhere((item) => item.id == id);
    if (idx < 0) return;

    final object = fibonacciObjects[idx];
    if (target == ObjectDragTarget.start) {
      final int nextIndex = clampDataIndex(newIndex);
      fibonacciObjects[idx] = FibonacciRetracementObject(
        id: object.id,
        start: CandleAnchor(
          index: nextIndex,
          price: newPrice,
          timestamp: newTimestamp ?? indexToTimestamp(nextIndex),
        ),
        end: object.end,
        levels: object.levels,
        color: object.color,
        width: object.width,
        layer: object.layer,
        visible: object.visible,
      );
    } else if (target == ObjectDragTarget.end) {
      final int nextIndex = clampDataIndex(newIndex);
      fibonacciObjects[idx] = FibonacciRetracementObject(
        id: object.id,
        start: object.start,
        end: CandleAnchor(
          index: nextIndex,
          price: newPrice,
          timestamp: newTimestamp ?? indexToTimestamp(nextIndex),
        ),
        levels: object.levels,
        color: object.color,
        width: object.width,
        layer: object.layer,
        visible: object.visible,
      );
    } else {
      final int nextStartIndex = clampDataIndex(object.start.index + indexDelta);
      final int nextEndIndex = clampDataIndex(object.end.index + indexDelta);
      fibonacciObjects[idx] = FibonacciRetracementObject(
        id: object.id,
        start: CandleAnchor(
          index: nextStartIndex,
          price: object.start.price + priceDelta,
          timestamp: indexToTimestamp(nextStartIndex),
        ),
        end: CandleAnchor(
          index: nextEndIndex,
          price: object.end.price + priceDelta,
          timestamp: indexToTimestamp(nextEndIndex),
        ),
        levels: object.levels,
        color: object.color,
        width: object.width,
        layer: object.layer,
        visible: object.visible,
      );
    }
  }

  void _updatePolylineDuringDrag({
    required String id,
    required ObjectDragTarget target,
    required int indexDelta,
    required double priceDelta,
    required int Function(int index) clampDataIndex,
    required int? Function(int index) indexToTimestamp,
  }) {
    if (target != ObjectDragTarget.body) return;

    final int idx = polylineObjects.indexWhere((item) => item.id == id);
    if (idx < 0) return;

    final object = polylineObjects[idx];
    polylineObjects[idx] = FreePolylineObject(
      id: object.id,
      points: object.points
          .map(
            (p) {
              final int nextIndex = clampDataIndex(p.index + indexDelta);
              return CandleAnchor(
                index: nextIndex,
                price: p.price + priceDelta,
                timestamp: indexToTimestamp(nextIndex),
              );
            },
          )
          .toList(),
      color: object.color,
      width: object.width,
      layer: object.layer,
      visible: object.visible,
    );
  }

  bool _removeById<T extends ChartObject>(List<T> objects, String id) {
    final int before = objects.length;
    objects.removeWhere((object) => object.id == id);
    return objects.length != before;
  }

  TrendLineObject _copyTrendLine(
    TrendLineObject line, {
    int? startIndex,
    double? startPrice,
    int? startTimestamp,
    int? endIndex,
    double? endPrice,
    int? endTimestamp,
  }) {
    return TrendLineObject(
      id: line.id,
      startIndex: startIndex ?? line.startIndex,
      startPrice: startPrice ?? line.startPrice,
      startTimestamp: startTimestamp ?? line.startTimestamp,
      endIndex: endIndex ?? line.endIndex,
      endPrice: endPrice ?? line.endPrice,
      endTimestamp: endTimestamp ?? line.endTimestamp,
      color: line.color,
      width: line.width,
      selected: line.selected,
      layer: line.layer,
      visible: line.visible,
    );
  }
}
