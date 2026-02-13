import 'package:flutter/material.dart';
import '../../models/price_data.dart';
import '../../models/manual_high_low_point.dart';
import '../../utils/kline_timestamp_utils.dart';

/// 手動高低点専用の描画クラス
class ManualHighLowPainter {
  static void drawManualHighLowPoints(
    Canvas canvas,
    Size size,
    List<PriceData> data,
    List<ManualHighLowPoint> manualHighLowPoints,
    double candleWidth,
    double spacing,
    int startIndex,
    int endIndex,
    double chartHeight,
    double chartWidth,
    double emptySpaceWidth,
    double minPrice,
    double maxPrice,
  ) {
    if (manualHighLowPoints.isEmpty || data.isEmpty) return;

    final double totalCandleWidth = candleWidth + spacing;
    final double candleDrawingWidth = chartWidth - emptySpaceWidth;
    final int visibleCandles = endIndex - startIndex;
    final double startX = candleDrawingWidth - (visibleCandles * totalCandleWidth);

    for (final point in manualHighLowPoints) {
      final int? candleIndex = KlineTimestampUtils.findKlineIndexByTimestamp(
        data,
        point.timestamp,
      );

      if (candleIndex == null || candleIndex < startIndex || candleIndex >= endIndex) {
        continue;
      }

      final double x = startX + (candleIndex - startIndex) * totalCandleWidth + totalCandleWidth / 2;
      final double y = _priceToY(point.price, minPrice, maxPrice, chartHeight);
      
      _drawSingleManualHighLowPoint(
        canvas,
        point,
        x,
        y,
      );
    }
  }

  static void _drawSingleManualHighLowPoint(
    Canvas canvas,
    ManualHighLowPoint point,
    double x,
    double y,
  ) {
    final Color pointColor = point.isHigh ? Colors.orange : Colors.blue;
    final Paint pointPaint = Paint()
      ..color = pointColor
      ..style = PaintingStyle.fill;

    final Paint strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // 三角形を描画（高値は上向き、安値は下向き）
    final Path trianglePath = _createTrianglePath(x, y, point.isHigh);
    
    canvas.drawPath(trianglePath, pointPaint);
    canvas.drawPath(trianglePath, strokePaint);

    // 価格ラベルを描画
    _drawPriceLabel(canvas, point, x, y);
  }

  static Path _createTrianglePath(double x, double y, bool isHigh) {
    final Path path = Path();
    const double triangleSize = 8.0;

    if (isHigh) {
      // 上向き三角形（高値）
      path.moveTo(x, y - triangleSize);
      path.lineTo(x - triangleSize / 2, y);
      path.lineTo(x + triangleSize / 2, y);
      path.close();
    } else {
      // 下向き三角形（安値）
      path.moveTo(x, y + triangleSize);
      path.lineTo(x - triangleSize / 2, y);
      path.lineTo(x + triangleSize / 2, y);
      path.close();
    }

    return path;
  }

  static void _drawPriceLabel(
    Canvas canvas,
    ManualHighLowPoint point,
    double x,
    double y,
  ) {
    final TextPainter labelPainter = TextPainter(
      text: TextSpan(
        text: point.price.toStringAsFixed(5),
        style: TextStyle(
          color: point.isHigh ? Colors.orange : Colors.blue,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black54,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    labelPainter.layout();

    final double labelX = x - labelPainter.width / 2;
    final double labelY = point.isHigh ? y - 25 : y + 15;

    // 背景を描画
    final Paint backgroundPaint = Paint()
      ..color = Colors.black54;
    
    canvas.drawRect(
      Rect.fromLTWH(labelX - 2, labelY - 2, labelPainter.width + 4, labelPainter.height + 4),
      backgroundPaint,
    );

    labelPainter.paint(canvas, Offset(labelX, labelY));
  }

  static double _priceToY(double price, double minPrice, double maxPrice, double chartHeight) {
    if (maxPrice == minPrice) return chartHeight / 2;
    final double priceRange = maxPrice - minPrice;
    final double normalizedPrice = (price - minPrice) / priceRange;
    return chartHeight - (normalizedPrice * chartHeight);
  }
}
