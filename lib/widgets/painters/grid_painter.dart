import 'package:flutter/material.dart';

/// グリッド専用の描画クラス
class GridPainter {
  static void drawGrid(
    Canvas canvas,
    Size size,
    double minPrice,
    double maxPrice,
    double chartHeight,
    double chartWidth,
    double emptySpaceWidth,
  ) {
    _drawHorizontalGridLines(canvas, minPrice, maxPrice, chartHeight, chartWidth, emptySpaceWidth);
    _drawVerticalGridLines(canvas, chartHeight, chartWidth, emptySpaceWidth);
  }

  static void _drawHorizontalGridLines(
    Canvas canvas,
    double minPrice,
    double maxPrice,
    double chartHeight,
    double chartWidth,
    double emptySpaceWidth,
  ) {
    final Paint gridPaint = Paint()
      ..color = Colors.grey.withAlpha(77)
      ..strokeWidth = 0.5;

    final Paint majorGridPaint = Paint()
      ..color = Colors.grey.withAlpha(128)
      ..strokeWidth = 1.0;

    final double priceRange = maxPrice - minPrice;
    final int numLines = 10;
    final double priceStep = priceRange / numLines;

    for (int i = 0; i <= numLines; i++) {
      final double price = minPrice + (i * priceStep);
      final double y = _priceToY(price, minPrice, maxPrice, chartHeight);
      
      final bool isMajorLine = (i % 2 == 0);
      final Paint paint = isMajorLine ? majorGridPaint : gridPaint;
      
      canvas.drawLine(
        Offset(0, y),
        Offset(chartWidth - emptySpaceWidth, y),
        paint,
      );
    }
  }

  static void _drawVerticalGridLines(
    Canvas canvas,
    double chartHeight,
    double chartWidth,
    double emptySpaceWidth,
  ) {
    final Paint gridPaint = Paint()
      ..color = Colors.grey.withAlpha(51)
      ..strokeWidth = 0.5;

    final double candleDrawingWidth = chartWidth - emptySpaceWidth;
    final int numLines = 20;
    final double xStep = candleDrawingWidth / numLines;

    for (int i = 0; i <= numLines; i++) {
      final double x = i * xStep;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, chartHeight),
        gridPaint,
      );
    }
  }

  static double _priceToY(double price, double minPrice, double maxPrice, double chartHeight) {
    if (maxPrice == minPrice) return chartHeight / 2;
    final double priceRange = maxPrice - minPrice;
    final double normalizedPrice = (price - minPrice) / priceRange;
    return chartHeight - (normalizedPrice * chartHeight);
  }
}
