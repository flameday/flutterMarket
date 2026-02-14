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

    return null;
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
}
