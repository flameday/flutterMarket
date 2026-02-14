import 'package:flutter/material.dart';

import '../models/chart_object.dart';

enum ObjectDragTarget {
  start,
  end,
  body,
}

class ObjectHitResult {
  const ObjectHitResult({
    required this.objectId,
    required this.objectType,
    required this.dragTarget,
  });

  final String objectId;
  final Type objectType;
  final ObjectDragTarget dragTarget;
}

class ChartObjectInteractionService {
  const ChartObjectInteractionService._();

  static ObjectHitResult? hitTest({
    required List<ChartObject> objects,
    required double x,
    required double y,
    required int endIndex,
    required double candleWidth,
    required double scale,
    required double spacing,
    required double emptySpaceWidth,
    required double chartWidth,
    required double chartHeight,
    required double minPrice,
    required double maxPrice,
  }) {
    final trendLineHit = _hitTestTrendLine(
      objects: objects,
      x: x,
      y: y,
      endIndex: endIndex,
      candleWidth: candleWidth,
      scale: scale,
      spacing: spacing,
      emptySpaceWidth: emptySpaceWidth,
      chartWidth: chartWidth,
      chartHeight: chartHeight,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );

    if (trendLineHit != null) {
      return trendLineHit;
    }

    final circleHit = _hitTestCircle(
      objects: objects,
      x: x,
      y: y,
      endIndex: endIndex,
      candleWidth: candleWidth,
      scale: scale,
      spacing: spacing,
      emptySpaceWidth: emptySpaceWidth,
      chartWidth: chartWidth,
      chartHeight: chartHeight,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
    if (circleHit != null) return circleHit;

    final rectangleHit = _hitTestRectangle(
      objects: objects,
      x: x,
      y: y,
      endIndex: endIndex,
      candleWidth: candleWidth,
      scale: scale,
      spacing: spacing,
      emptySpaceWidth: emptySpaceWidth,
      chartWidth: chartWidth,
      chartHeight: chartHeight,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
    if (rectangleHit != null) return rectangleHit;

    final fibHit = _hitTestFibonacci(
      objects: objects,
      x: x,
      y: y,
      endIndex: endIndex,
      candleWidth: candleWidth,
      scale: scale,
      spacing: spacing,
      emptySpaceWidth: emptySpaceWidth,
      chartWidth: chartWidth,
      chartHeight: chartHeight,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
    if (fibHit != null) return fibHit;

    final polylineHit = _hitTestPolyline(
      objects: objects,
      x: x,
      y: y,
      endIndex: endIndex,
      candleWidth: candleWidth,
      scale: scale,
      spacing: spacing,
      emptySpaceWidth: emptySpaceWidth,
      chartWidth: chartWidth,
      chartHeight: chartHeight,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
    if (polylineHit != null) return polylineHit;

    return null;
  }

  static Offset _anchorToOffset({
    required int index,
    required double price,
    required int endIndex,
    required double candleWidth,
    required double scale,
    required double spacing,
    required double emptySpaceWidth,
    required double chartWidth,
    required double chartHeight,
    required double minPrice,
    required double maxPrice,
  }) {
    final unit = (candleWidth * scale) + spacing;
    final rightEdge = chartWidth - emptySpaceWidth;
    final priceRange = (maxPrice - minPrice).abs();
    final x = rightEdge - (endIndex - index - 0.5) * unit;
    final y = priceRange < 0.0000001
        ? chartHeight / 2
        : ((maxPrice - price) / priceRange) * chartHeight;
    return Offset(x, y);
  }

  static ObjectHitResult? _hitTestTrendLine({
    required List<ChartObject> objects,
    required double x,
    required double y,
    required int endIndex,
    required double candleWidth,
    required double scale,
    required double spacing,
    required double emptySpaceWidth,
    required double chartWidth,
    required double chartHeight,
    required double minPrice,
    required double maxPrice,
  }) {
    final trendLines = objects.whereType<TrendLineObject>().toList();
    if (trendLines.isEmpty) return null;

    final priceRange = (maxPrice - minPrice).abs();
    if (priceRange < 0.0000001) return null;

    final unit = (candleWidth * scale) + spacing;
    final rightEdge = chartWidth - emptySpaceWidth;

    const handleThreshold = 12.0;
    const bodyThreshold = 12.0;

    ObjectHitResult? nearestHandle;
    double nearestHandleDistance = double.infinity;

    for (final line in trendLines) {
      final start = Offset(
        rightEdge - (endIndex - line.startIndex - 0.5) * unit,
        ((maxPrice - line.startPrice) / priceRange) * chartHeight,
      );
      final end = Offset(
        rightEdge - (endIndex - line.endIndex - 0.5) * unit,
        ((maxPrice - line.endPrice) / priceRange) * chartHeight,
      );

      final startDistance = (Offset(x, y) - start).distance;
      if (startDistance <= handleThreshold && startDistance < nearestHandleDistance) {
        nearestHandleDistance = startDistance;
        nearestHandle = ObjectHitResult(
          objectId: line.id,
          objectType: TrendLineObject,
          dragTarget: ObjectDragTarget.start,
        );
      }

      final endDistance = (Offset(x, y) - end).distance;
      if (endDistance <= handleThreshold && endDistance < nearestHandleDistance) {
        nearestHandleDistance = endDistance;
        nearestHandle = ObjectHitResult(
          objectId: line.id,
          objectType: TrendLineObject,
          dragTarget: ObjectDragTarget.end,
        );
      }
    }

    if (nearestHandle != null) {
      return nearestHandle;
    }

    String? nearestLineId;
    double nearestBodyDistance = bodyThreshold;

    for (final line in trendLines) {
      final p1 = Offset(
        rightEdge - (endIndex - line.startIndex - 0.5) * unit,
        ((maxPrice - line.startPrice) / priceRange) * chartHeight,
      );
      final p2 = Offset(
        rightEdge - (endIndex - line.endIndex - 0.5) * unit,
        ((maxPrice - line.endPrice) / priceRange) * chartHeight,
      );

      final d = _distancePointToSegment(Offset(x, y), p1, p2);
      if (d < nearestBodyDistance) {
        nearestBodyDistance = d;
        nearestLineId = line.id;
      }
    }

    if (nearestLineId == null) return null;

    return ObjectHitResult(
      objectId: nearestLineId,
      objectType: TrendLineObject,
      dragTarget: ObjectDragTarget.body,
    );
  }

  static double _distancePointToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lengthSquared = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lengthSquared < 0.000001) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / lengthSquared).clamp(0.0, 1.0);
    final projection = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - projection).distance;
  }

  static ObjectHitResult? _hitTestCircle({
    required List<ChartObject> objects,
    required double x,
    required double y,
    required int endIndex,
    required double candleWidth,
    required double scale,
    required double spacing,
    required double emptySpaceWidth,
    required double chartWidth,
    required double chartHeight,
    required double minPrice,
    required double maxPrice,
  }) {
    final circles = objects.whereType<CircleObject>();
    const handleThreshold = 12.0;
    const bodyThreshold = 10.0;
    final point = Offset(x, y);

    for (final circle in circles) {
      final start = _anchorToOffset(
        index: circle.start.index,
        price: circle.start.price,
        endIndex: endIndex,
        candleWidth: candleWidth,
        scale: scale,
        spacing: spacing,
        emptySpaceWidth: emptySpaceWidth,
        chartWidth: chartWidth,
        chartHeight: chartHeight,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );
      final end = _anchorToOffset(
        index: circle.end.index,
        price: circle.end.price,
        endIndex: endIndex,
        candleWidth: candleWidth,
        scale: scale,
        spacing: spacing,
        emptySpaceWidth: emptySpaceWidth,
        chartWidth: chartWidth,
        chartHeight: chartHeight,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );

      if ((point - start).distance <= handleThreshold) {
        return ObjectHitResult(objectId: circle.id, objectType: CircleObject, dragTarget: ObjectDragTarget.start);
      }
      if ((point - end).distance <= handleThreshold) {
        return ObjectHitResult(objectId: circle.id, objectType: CircleObject, dragTarget: ObjectDragTarget.end);
      }

      final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      final radius = ((end.dx - start.dx).abs() + (end.dy - start.dy).abs()) / 4;
      if (radius > 0.5 && ((point - center).distance - radius).abs() <= bodyThreshold) {
        return ObjectHitResult(objectId: circle.id, objectType: CircleObject, dragTarget: ObjectDragTarget.body);
      }
    }

    return null;
  }

  static ObjectHitResult? _hitTestRectangle({
    required List<ChartObject> objects,
    required double x,
    required double y,
    required int endIndex,
    required double candleWidth,
    required double scale,
    required double spacing,
    required double emptySpaceWidth,
    required double chartWidth,
    required double chartHeight,
    required double minPrice,
    required double maxPrice,
  }) {
    final rectangles = objects.whereType<RectangleObject>();
    const handleThreshold = 12.0;
    final point = Offset(x, y);

    for (final rectObj in rectangles) {
      final start = _anchorToOffset(
        index: rectObj.start.index,
        price: rectObj.start.price,
        endIndex: endIndex,
        candleWidth: candleWidth,
        scale: scale,
        spacing: spacing,
        emptySpaceWidth: emptySpaceWidth,
        chartWidth: chartWidth,
        chartHeight: chartHeight,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );
      final end = _anchorToOffset(
        index: rectObj.end.index,
        price: rectObj.end.price,
        endIndex: endIndex,
        candleWidth: candleWidth,
        scale: scale,
        spacing: spacing,
        emptySpaceWidth: emptySpaceWidth,
        chartWidth: chartWidth,
        chartHeight: chartHeight,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );

      if ((point - start).distance <= handleThreshold) {
        return ObjectHitResult(objectId: rectObj.id, objectType: RectangleObject, dragTarget: ObjectDragTarget.start);
      }
      if ((point - end).distance <= handleThreshold) {
        return ObjectHitResult(objectId: rectObj.id, objectType: RectangleObject, dragTarget: ObjectDragTarget.end);
      }

      final rect = Rect.fromPoints(start, end).inflate(6.0);
      if (rect.contains(point)) {
        return ObjectHitResult(objectId: rectObj.id, objectType: RectangleObject, dragTarget: ObjectDragTarget.body);
      }
    }

    return null;
  }

  static ObjectHitResult? _hitTestFibonacci({
    required List<ChartObject> objects,
    required double x,
    required double y,
    required int endIndex,
    required double candleWidth,
    required double scale,
    required double spacing,
    required double emptySpaceWidth,
    required double chartWidth,
    required double chartHeight,
    required double minPrice,
    required double maxPrice,
  }) {
    final fibs = objects.whereType<FibonacciRetracementObject>();
    const handleThreshold = 12.0;
    const bodyThreshold = 8.0;
    final point = Offset(x, y);

    for (final fib in fibs) {
      final start = _anchorToOffset(
        index: fib.start.index,
        price: fib.start.price,
        endIndex: endIndex,
        candleWidth: candleWidth,
        scale: scale,
        spacing: spacing,
        emptySpaceWidth: emptySpaceWidth,
        chartWidth: chartWidth,
        chartHeight: chartHeight,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );
      final end = _anchorToOffset(
        index: fib.end.index,
        price: fib.end.price,
        endIndex: endIndex,
        candleWidth: candleWidth,
        scale: scale,
        spacing: spacing,
        emptySpaceWidth: emptySpaceWidth,
        chartWidth: chartWidth,
        chartHeight: chartHeight,
        minPrice: minPrice,
        maxPrice: maxPrice,
      );

      if ((point - start).distance <= handleThreshold) {
        return ObjectHitResult(objectId: fib.id, objectType: FibonacciRetracementObject, dragTarget: ObjectDragTarget.start);
      }
      if ((point - end).distance <= handleThreshold) {
        return ObjectHitResult(objectId: fib.id, objectType: FibonacciRetracementObject, dragTarget: ObjectDragTarget.end);
      }

      final minX = start.dx < end.dx ? start.dx : end.dx;
      final maxX = start.dx < end.dx ? end.dx : start.dx;
      final priceDelta = fib.end.price - fib.start.price;
      for (final level in fib.levels) {
        final levelPrice = fib.start.price + priceDelta * level;
        final levelPoint = _anchorToOffset(
          index: fib.start.index,
          price: levelPrice,
          endIndex: endIndex,
          candleWidth: candleWidth,
          scale: scale,
          spacing: spacing,
          emptySpaceWidth: emptySpaceWidth,
          chartWidth: chartWidth,
          chartHeight: chartHeight,
          minPrice: minPrice,
          maxPrice: maxPrice,
        );
        if (x >= minX - bodyThreshold && x <= maxX + bodyThreshold && (y - levelPoint.dy).abs() <= bodyThreshold) {
          return ObjectHitResult(objectId: fib.id, objectType: FibonacciRetracementObject, dragTarget: ObjectDragTarget.body);
        }
      }
    }

    return null;
  }

  static ObjectHitResult? _hitTestPolyline({
    required List<ChartObject> objects,
    required double x,
    required double y,
    required int endIndex,
    required double candleWidth,
    required double scale,
    required double spacing,
    required double emptySpaceWidth,
    required double chartWidth,
    required double chartHeight,
    required double minPrice,
    required double maxPrice,
  }) {
    final polylines = objects.whereType<FreePolylineObject>();
    const bodyThreshold = 12.0;
    final point = Offset(x, y);

    for (final polyline in polylines) {
      if (polyline.points.length < 2) continue;
      for (int i = 0; i < polyline.points.length - 1; i++) {
        final p1 = _anchorToOffset(
          index: polyline.points[i].index,
          price: polyline.points[i].price,
          endIndex: endIndex,
          candleWidth: candleWidth,
          scale: scale,
          spacing: spacing,
          emptySpaceWidth: emptySpaceWidth,
          chartWidth: chartWidth,
          chartHeight: chartHeight,
          minPrice: minPrice,
          maxPrice: maxPrice,
        );
        final p2 = _anchorToOffset(
          index: polyline.points[i + 1].index,
          price: polyline.points[i + 1].price,
          endIndex: endIndex,
          candleWidth: candleWidth,
          scale: scale,
          spacing: spacing,
          emptySpaceWidth: emptySpaceWidth,
          chartWidth: chartWidth,
          chartHeight: chartHeight,
          minPrice: minPrice,
          maxPrice: maxPrice,
        );
        final d = _distancePointToSegment(point, p1, p2);
        if (d <= bodyThreshold) {
          return ObjectHitResult(objectId: polyline.id, objectType: FreePolylineObject, dragTarget: ObjectDragTarget.body);
        }
      }
    }

    return null;
  }
}
