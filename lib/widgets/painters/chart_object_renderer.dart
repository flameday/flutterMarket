import 'package:flutter/material.dart';

import '../../models/chart_object.dart';
import '../../models/price_data.dart';
import '../../utils/kline_timestamp_utils.dart';

class ChartObjectRenderContext {
  const ChartObjectRenderContext({
    required this.canvas,
    required this.size,
    required this.data,
    required this.startIndex,
    required this.endIndex,
    required this.candleWidth,
    required this.spacing,
    required this.minPrice,
    required this.maxPrice,
    required this.emptySpaceWidth,
  });

  final Canvas canvas;
  final Size size;
  final List<PriceData> data;
  final int startIndex;
  final int endIndex;
  final double candleWidth;
  final double spacing;
  final double minPrice;
  final double maxPrice;
  final double emptySpaceWidth;

  double priceToY(double price) {
    final range = maxPrice - minPrice;
    if (range == 0) return size.height / 2;
    final normalized = (price - minPrice) / range;
    return size.height - (normalized * size.height);
  }

  double candleXByIndex(int candleIndex) {
    final visibleCandles = endIndex - startIndex;
    if (visibleCandles <= 0) return -1;

    final totalWidth = candleWidth + spacing;
    final candleDrawingWidth = size.width - emptySpaceWidth;
    final rightEdgeX = candleDrawingWidth;
    final startDrawX = rightEdgeX - (visibleCandles * totalWidth);
    final relativeIndex = candleIndex - startIndex;
    return startDrawX + (relativeIndex * totalWidth) + (candleWidth / 2);
  }

  int? findKlineIndexByTimestamp(int timestamp) {
    if (data.isEmpty) return null;

    int low = 0;
    int high = data.length - 1;
    int? result;

    while (low <= high) {
      final mid = low + ((high - low) >> 1);
      final midTimestamp = data[mid].timestamp;

      if (midTimestamp == timestamp) {
        return mid;
      }
      if (midTimestamp < timestamp) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return result;
  }

  Color parseHexColor(String colorString, Color fallback) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (_) {
      return fallback;
    }
  }

  void logTimestampNotFound(String scope, int timestamp) {
    // ignore: avoid_print
    debugPrint('$scope timestamp not found: ${KlineTimestampUtils.formatTimestamp(timestamp)}');
  }
}

abstract class ChartObjectRenderer<T extends ChartObject> {
  const ChartObjectRenderer();

  bool canRender(ChartObject object) => object is T;

  void render(ChartObjectRenderContext context, T object);
}

class VerticalLineObjectRenderer extends ChartObjectRenderer<VerticalLineObject> {
  const VerticalLineObjectRenderer();

  @override
  void render(ChartObjectRenderContext context, VerticalLineObject object) {
    final candleIndex = context.findKlineIndexByTimestamp(object.timestamp);
    if (candleIndex == null) {
      return;
    }
    if (candleIndex < context.startIndex || candleIndex >= context.endIndex) {
      return;
    }

    final x = context.candleXByIndex(candleIndex);
    if (x < 0) return;

    final paint = Paint()
      ..color = context.parseHexColor(object.color, Colors.red)
      ..strokeWidth = object.width
      ..style = PaintingStyle.stroke;

    context.canvas.drawLine(
      Offset(x, 0),
      Offset(x, context.size.height),
      paint,
    );
  }
}

class TrendLineObjectRenderer extends ChartObjectRenderer<TrendLineObject> {
  const TrendLineObjectRenderer();

  @override
  void render(ChartObjectRenderContext context, TrendLineObject object) {
    final startX = context.candleXByIndex(object.startIndex);
    final endX = context.candleXByIndex(object.endIndex);
    final startY = context.priceToY(object.startPrice);
    final endY = context.priceToY(object.endPrice);

    if ((startX < -100 && endX < -100) ||
        (startX > context.size.width + 100 && endX > context.size.width + 100)) {
      return;
    }

    final linePaint = Paint()
      ..color = object.selected
          ? Colors.lightBlueAccent
          : context.parseHexColor(object.color, Colors.amber)
      ..strokeWidth = object.selected ? (object.width + 1.2) : object.width
      ..style = PaintingStyle.stroke;

    context.canvas.drawLine(Offset(startX, startY), Offset(endX, endY), linePaint);

    if (object.selected) {
      final handlePaint = Paint()
        ..color = Colors.lightBlueAccent
        ..style = PaintingStyle.fill;
      context.canvas.drawCircle(Offset(startX, startY), 4.0, handlePaint);
      context.canvas.drawCircle(Offset(endX, endY), 4.0, handlePaint);
    }
  }
}

class KlineSelectionObjectRenderer extends ChartObjectRenderer<KlineSelectionObject> {
  const KlineSelectionObjectRenderer();

  @override
  void render(ChartObjectRenderContext context, KlineSelectionObject object) {
    final startIndex = context.findKlineIndexByTimestamp(object.startTimestamp);
    final endIndex = context.findKlineIndexByTimestamp(object.endTimestamp);
    if (startIndex == null || endIndex == null) {
      return;
    }
    if (startIndex < context.startIndex || endIndex >= context.endIndex) {
      return;
    }

    final startX = context.candleXByIndex(startIndex);
    final endX = context.candleXByIndex(endIndex);
    final minX = startX < endX ? startX : endX;
    final maxX = startX < endX ? endX : startX;
    final adjustedMinX = minX - (context.candleWidth / 2);
    final adjustedMaxX = maxX + (context.candleWidth / 2);

    final baseColor = context.parseHexColor(object.color, Colors.blue);

    final fillPaint = Paint()
      ..color = baseColor.withValues(alpha: object.opacity)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = baseColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    context.canvas.drawRect(
      Rect.fromLTRB(adjustedMinX, 0, adjustedMaxX, context.size.height),
      fillPaint,
    );
    context.canvas.drawRect(
      Rect.fromLTRB(adjustedMinX, 0, adjustedMaxX, context.size.height),
      borderPaint,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'K線: ${object.klineCount} 本',
        style: TextStyle(
          color: baseColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white.withValues(alpha: 0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textX = (adjustedMinX + adjustedMaxX) / 2 - textPainter.width / 2;
    const textY = 10.0;

    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    context.canvas.drawRect(
      Rect.fromLTWH(textX - 4, textY - 2, textPainter.width + 8, textPainter.height + 4),
      backgroundPaint,
    );

    textPainter.paint(context.canvas, Offset(textX, textY));
  }
}

class ActiveKlineSelectionObjectRenderer extends ChartObjectRenderer<ActiveKlineSelectionObject> {
  const ActiveKlineSelectionObjectRenderer();

  @override
  void render(ChartObjectRenderContext context, ActiveKlineSelectionObject object) {
    final minX = object.startX < object.endX ? object.startX : object.endX;
    final maxX = object.startX < object.endX ? object.endX : object.startX;
    final adjustedMinX = minX - (context.candleWidth / 2);
    final adjustedMaxX = maxX + (context.candleWidth / 2);

    final fillPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    context.canvas.drawRect(
      Rect.fromLTRB(adjustedMinX, 0, adjustedMaxX, context.size.height),
      fillPaint,
    );
    context.canvas.drawRect(
      Rect.fromLTRB(adjustedMinX, 0, adjustedMaxX, context.size.height),
      borderPaint,
    );

    if (object.selectedKlineCount <= 0) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: '選択されたK線: ${object.selectedKlineCount} 本',
        style: TextStyle(
          color: Colors.blue,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white.withValues(alpha: 0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textX = (adjustedMinX + adjustedMaxX) / 2 - textPainter.width / 2;
    const textY = 20.0;

    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    context.canvas.drawRect(
      Rect.fromLTWH(textX - 4, textY - 2, textPainter.width + 8, textPainter.height + 4),
      backgroundPaint,
    );

    textPainter.paint(context.canvas, Offset(textX, textY));
  }
}

class WavePointObjectRenderer extends ChartObjectRenderer<WavePointObject> {
  const WavePointObjectRenderer();

  @override
  void render(ChartObjectRenderContext context, WavePointObject object) {
    if (object.index < context.startIndex || object.index >= context.endIndex) {
      return;
    }

    final x = context.candleXByIndex(object.index);
    if (x < 0) return;
    final y = context.priceToY(object.price);

    final borderPaint = Paint()
      ..color = object.isHigh
          ? Colors.red.withValues(alpha: 0.7)
          : Colors.blue.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final squareRect = Rect.fromCenter(
      center: Offset(x, y),
      width: 16,
      height: 16,
    );

    context.canvas.drawRect(squareRect, borderPaint);
  }
}

class WavePolylineObjectRenderer extends ChartObjectRenderer<WavePolylineObject> {
  const WavePolylineObjectRenderer();

  @override
  void render(ChartObjectRenderContext context, WavePolylineObject object) {
    if (object.points.length < 2) return;

    final paint = Paint()
      ..color = context.parseHexColor(object.color, Colors.orange)
      ..strokeWidth = object.width
      ..style = PaintingStyle.stroke;

    CandleAnchor? previous;
    for (final point in object.points) {
      if (previous != null) {
        final x1 = context.candleXByIndex(previous.index);
        final y1 = context.priceToY(previous.price);
        final x2 = context.candleXByIndex(point.index);
        final y2 = context.priceToY(point.price);
        context.canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      }
      previous = point;
    }
  }
}

class ManualHighLowObjectRenderer extends ChartObjectRenderer<ManualHighLowObject> {
  const ManualHighLowObjectRenderer();

  @override
  void render(ChartObjectRenderContext context, ManualHighLowObject object) {
    final candleIndex = context.findKlineIndexByTimestamp(object.timestamp);
    if (candleIndex == null) {
      return;
    }
    if (candleIndex < context.startIndex || candleIndex >= context.endIndex) {
      return;
    }

    final x = context.candleXByIndex(candleIndex);
    if (x < 0 || x > context.size.width) {
      return;
    }
    final y = context.priceToY(object.price);
    if (y < 0 || y > context.size.height) {
      return;
    }

    final pointPaint = Paint()
      ..color = object.isHigh ? Colors.orange : Colors.blue
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = object.isHigh ? Colors.red : Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    const size = 8.0;
    if (object.isHigh) {
      path.moveTo(x, y - size);
      path.lineTo(x - size, y + size);
      path.lineTo(x + size, y + size);
    } else {
      path.moveTo(x, y + size);
      path.lineTo(x - size, y - size);
      path.lineTo(x + size, y - size);
    }
    path.close();

    context.canvas.drawPath(path, pointPaint);
    context.canvas.drawPath(path, borderPaint);
  }
}

class FibonacciRetracementObjectRenderer extends ChartObjectRenderer<FibonacciRetracementObject> {
  const FibonacciRetracementObjectRenderer();

  @override
  void render(ChartObjectRenderContext context, FibonacciRetracementObject object) {
    final startX = context.candleXByIndex(object.start.index);
    final endX = context.candleXByIndex(object.end.index);
    final minX = startX < endX ? startX : endX;
    final maxX = startX < endX ? endX : startX;

    final baseColor = context.parseHexColor(object.color, Colors.purple);
    final priceDelta = object.end.price - object.start.price;

    final linePaint = Paint()
      ..color = baseColor
      ..strokeWidth = object.width
      ..style = PaintingStyle.stroke;

    for (final level in object.levels) {
      final levelPrice = object.start.price + priceDelta * level;
      final y = context.priceToY(levelPrice);
      context.canvas.drawLine(Offset(minX, y), Offset(maxX, y), linePaint);

      final labelPainter = TextPainter(
        text: TextSpan(
          text: '${(level * 100).toStringAsFixed(1)}%',
          style: TextStyle(
            color: baseColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(context.canvas, Offset(maxX + 4, y - 6));
    }
  }
}

class FilteredWavePointObjectRenderer
    extends ChartObjectRenderer<FilteredWavePointObject> {
  const FilteredWavePointObjectRenderer();

  @override
  void render(ChartObjectRenderContext context, FilteredWavePointObject object) {
    if (object.index < context.startIndex || object.index > context.endIndex) {
      return;
    }

    final x = context.candleXByIndex(object.index);
    if (x < 0) return;
    final y = context.priceToY(object.price);

    if (object.pointKind == 'original_high' || object.pointKind == 'original_low') {
      final paint = Paint()
        ..color = object.pointKind == 'original_high'
            ? Colors.green.withValues(alpha: 0.3)
            : Colors.red.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      context.canvas.drawCircle(Offset(x, y), 3, paint);
      return;
    }

    final fill = Paint()
      ..color = object.pointKind == 'filtered_high' ? Colors.green : Colors.red
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    context.canvas.drawCircle(Offset(x, y), 6, fill);
    context.canvas.drawCircle(Offset(x, y), 6, border);
  }
}

class TrendAnalysisLineObjectRenderer
    extends ChartObjectRenderer<TrendAnalysisLineObject> {
  const TrendAnalysisLineObjectRenderer();

  @override
  void render(ChartObjectRenderContext context, TrendAnalysisLineObject object) {
    final startX = context.candleXByIndex(object.start.index);
    final endX = context.candleXByIndex(object.end.index);
    final startY = context.priceToY(object.start.price);
    final endY = context.priceToY(object.end.price);

    final lineColor = context.parseHexColor(object.color, Colors.blue);
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = object.width
      ..style = PaintingStyle.stroke;

    context.canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);

    if (object.direction == 'horizontal') return;

    const arrowSize = 8.0;
    final arrowPath = Path();
    if (object.direction == 'upward') {
      arrowPath.moveTo(endX, endY - arrowSize);
      arrowPath.lineTo(endX - arrowSize / 2, endY);
      arrowPath.lineTo(endX + arrowSize / 2, endY);
    } else if (object.direction == 'downward') {
      arrowPath.moveTo(endX, endY + arrowSize);
      arrowPath.lineTo(endX - arrowSize / 2, endY);
      arrowPath.lineTo(endX + arrowSize / 2, endY);
    }
    arrowPath.close();

    final arrowPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    context.canvas.drawPath(arrowPath, arrowPaint);
  }
}

class SmoothTrendPolylineObjectRenderer
    extends ChartObjectRenderer<SmoothTrendPolylineObject> {
  const SmoothTrendPolylineObjectRenderer();

  @override
  void render(ChartObjectRenderContext context, SmoothTrendPolylineObject object) {
    if (object.points.length < 2) return;

    final paint = Paint()
      ..color = context.parseHexColor(object.color, Colors.orange)
      ..strokeWidth = object.width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    var first = true;
    for (final point in object.points) {
      final x = context.candleXByIndex(point.index);
      if (x < 0) continue;
      final y = context.priceToY(point.price);
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    if (!first) {
      context.canvas.drawPath(path, paint);
    }
  }
}

class FittedCurveObjectRenderer extends ChartObjectRenderer<FittedCurveObject> {
  const FittedCurveObjectRenderer();

  @override
  void render(ChartObjectRenderContext context, FittedCurveObject object) {
    if (object.points.length < 2) return;

    final paint = Paint()
      ..color = context.parseHexColor(object.color, Colors.blue)
      ..strokeWidth = object.width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    var first = true;
    for (final point in object.points) {
      final x = context.candleXByIndex(point.index);
      if (x < 0) continue;
      final y = context.priceToY(point.price);
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    if (!first) {
      context.canvas.drawPath(path, paint);
    }
  }
}

class ChartObjectRendererRegistry {
  ChartObjectRendererRegistry({
    List<ChartObjectRenderer<dynamic>>? renderers,
  }) : _renderers =
            renderers ??
            const [
              VerticalLineObjectRenderer(),
              TrendLineObjectRenderer(),
              KlineSelectionObjectRenderer(),
              ActiveKlineSelectionObjectRenderer(),
              WavePointObjectRenderer(),
              WavePolylineObjectRenderer(),
              ManualHighLowObjectRenderer(),
              FibonacciRetracementObjectRenderer(),
              FilteredWavePointObjectRenderer(),
              TrendAnalysisLineObjectRenderer(),
              SmoothTrendPolylineObjectRenderer(),
              FittedCurveObjectRenderer(),
            ];

  final List<ChartObjectRenderer<dynamic>> _renderers;

  void renderObjects({
    required Canvas canvas,
    required Size size,
    required List<PriceData> data,
    required int startIndex,
    required int endIndex,
    required double candleWidth,
    required double spacing,
    required double minPrice,
    required double maxPrice,
    required double emptySpaceWidth,
    required List<ChartObject> objects,
    required ChartObjectLayer layer,
  }) {
    final context = ChartObjectRenderContext(
      canvas: canvas,
      size: size,
      data: data,
      startIndex: startIndex,
      endIndex: endIndex,
      candleWidth: candleWidth,
      spacing: spacing,
      minPrice: minPrice,
      maxPrice: maxPrice,
      emptySpaceWidth: emptySpaceWidth,
    );

    for (final object in objects) {
      if (!object.visible || object.layer != layer) {
        continue;
      }

      for (final renderer in _renderers) {
        if (renderer.canRender(object)) {
          (renderer as ChartObjectRenderer<ChartObject>).render(context, object);
          break;
        }
      }
    }
  }
}
