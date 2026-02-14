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
    required double newPrice,
    required int indexDelta,
    required double priceDelta,
    required int Function(int index) clampDataIndex,
  }) {
    if (objectType == TrendLineObject) {
      _updateTrendLineDuringDrag(
        id: id,
        target: target,
        newIndex: newIndex,
        newPrice: newPrice,
        indexDelta: indexDelta,
        priceDelta: priceDelta,
        clampDataIndex: clampDataIndex,
      );
      return;
    }

    if (objectType == CircleObject) {
      _updateCircleDuringDrag(
        id: id,
        target: target,
        newIndex: newIndex,
        newPrice: newPrice,
        indexDelta: indexDelta,
        priceDelta: priceDelta,
        clampDataIndex: clampDataIndex,
      );
      return;
    }

    if (objectType == RectangleObject) {
      _updateRectangleDuringDrag(
        id: id,
        target: target,
        newIndex: newIndex,
        newPrice: newPrice,
        indexDelta: indexDelta,
        priceDelta: priceDelta,
        clampDataIndex: clampDataIndex,
      );
      return;
    }

    if (objectType == FibonacciRetracementObject) {
      _updateFibonacciDuringDrag(
        id: id,
        target: target,
        newIndex: newIndex,
        newPrice: newPrice,
        indexDelta: indexDelta,
        priceDelta: priceDelta,
        clampDataIndex: clampDataIndex,
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
      );
    }
  }

  void _updateTrendLineDuringDrag({
    required String id,
    required ObjectDragTarget target,
    required int newIndex,
    required double newPrice,
    required int indexDelta,
    required double priceDelta,
    required int Function(int index) clampDataIndex,
  }) {
    final int idx = trendLines.indexWhere((line) => line.id == id);
    if (idx < 0) return;

    final line = trendLines[idx];
    if (target == ObjectDragTarget.start) {
      trendLines[idx] = TrendLineObject(
        id: line.id,
        startIndex: newIndex,
        startPrice: newPrice,
        endIndex: line.endIndex,
        endPrice: line.endPrice,
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
        endIndex: newIndex,
        endPrice: newPrice,
        color: line.color,
        width: line.width,
        selected: line.selected,
        layer: line.layer,
        visible: line.visible,
      );
    } else {
      trendLines[idx] = TrendLineObject(
        id: line.id,
        startIndex: clampDataIndex(line.startIndex + indexDelta),
        startPrice: line.startPrice + priceDelta,
        endIndex: clampDataIndex(line.endIndex + indexDelta),
        endPrice: line.endPrice + priceDelta,
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
    required double newPrice,
    required int indexDelta,
    required double priceDelta,
    required int Function(int index) clampDataIndex,
  }) {
    final int idx = circleObjects.indexWhere((item) => item.id == id);
    if (idx < 0) return;

    final object = circleObjects[idx];
    if (target == ObjectDragTarget.start) {
      circleObjects[idx] = CircleObject(
        id: object.id,
        start: CandleAnchor(index: clampDataIndex(newIndex), price: newPrice),
        end: object.end,
        color: object.color,
        width: object.width,
        layer: object.layer,
        visible: object.visible,
      );
    } else if (target == ObjectDragTarget.end) {
      circleObjects[idx] = CircleObject(
        id: object.id,
        start: object.start,
        end: CandleAnchor(index: clampDataIndex(newIndex), price: newPrice),
        color: object.color,
        width: object.width,
        layer: object.layer,
        visible: object.visible,
      );
    } else {
      circleObjects[idx] = CircleObject(
        id: object.id,
        start: CandleAnchor(
          index: clampDataIndex(object.start.index + indexDelta),
          price: object.start.price + priceDelta,
        ),
        end: CandleAnchor(
          index: clampDataIndex(object.end.index + indexDelta),
          price: object.end.price + priceDelta,
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
    required double newPrice,
    required int indexDelta,
    required double priceDelta,
    required int Function(int index) clampDataIndex,
  }) {
    final int idx = rectangleObjects.indexWhere((item) => item.id == id);
    if (idx < 0) return;

    final object = rectangleObjects[idx];
    if (target == ObjectDragTarget.start) {
      rectangleObjects[idx] = RectangleObject(
        id: object.id,
        start: CandleAnchor(index: clampDataIndex(newIndex), price: newPrice),
        end: object.end,
        color: object.color,
        width: object.width,
        fillAlpha: object.fillAlpha,
        layer: object.layer,
        visible: object.visible,
      );
    } else if (target == ObjectDragTarget.end) {
      rectangleObjects[idx] = RectangleObject(
        id: object.id,
        start: object.start,
        end: CandleAnchor(index: clampDataIndex(newIndex), price: newPrice),
        color: object.color,
        width: object.width,
        fillAlpha: object.fillAlpha,
        layer: object.layer,
        visible: object.visible,
      );
    } else {
      rectangleObjects[idx] = RectangleObject(
        id: object.id,
        start: CandleAnchor(
          index: clampDataIndex(object.start.index + indexDelta),
          price: object.start.price + priceDelta,
        ),
        end: CandleAnchor(
          index: clampDataIndex(object.end.index + indexDelta),
          price: object.end.price + priceDelta,
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
    required double newPrice,
    required int indexDelta,
    required double priceDelta,
    required int Function(int index) clampDataIndex,
  }) {
    final int idx = fibonacciObjects.indexWhere((item) => item.id == id);
    if (idx < 0) return;

    final object = fibonacciObjects[idx];
    if (target == ObjectDragTarget.start) {
      fibonacciObjects[idx] = FibonacciRetracementObject(
        id: object.id,
        start: CandleAnchor(index: clampDataIndex(newIndex), price: newPrice),
        end: object.end,
        levels: object.levels,
        color: object.color,
        width: object.width,
        layer: object.layer,
        visible: object.visible,
      );
    } else if (target == ObjectDragTarget.end) {
      fibonacciObjects[idx] = FibonacciRetracementObject(
        id: object.id,
        start: object.start,
        end: CandleAnchor(index: clampDataIndex(newIndex), price: newPrice),
        levels: object.levels,
        color: object.color,
        width: object.width,
        layer: object.layer,
        visible: object.visible,
      );
    } else {
      fibonacciObjects[idx] = FibonacciRetracementObject(
        id: object.id,
        start: CandleAnchor(
          index: clampDataIndex(object.start.index + indexDelta),
          price: object.start.price + priceDelta,
        ),
        end: CandleAnchor(
          index: clampDataIndex(object.end.index + indexDelta),
          price: object.end.price + priceDelta,
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
  }) {
    if (target != ObjectDragTarget.body) return;

    final int idx = polylineObjects.indexWhere((item) => item.id == id);
    if (idx < 0) return;

    final object = polylineObjects[idx];
    polylineObjects[idx] = FreePolylineObject(
      id: object.id,
      points: object.points
          .map(
            (p) => CandleAnchor(
              index: clampDataIndex(p.index + indexDelta),
              price: p.price + priceDelta,
            ),
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
}
