import 'package:flutter/material.dart';
import '../../models/price_data.dart';
import '../../constants/chart_constants.dart';

/// 移動平均線専用の描画クラス
class MovingAveragePainter {
  static void drawMovingAverages(
    Canvas canvas,
    Size size,
    List<PriceData> data,
    Map<int, List<double>> movingAverages,
    Map<int, bool> maVisibility,
    double candleWidth,
    double spacing,
    double minPrice,
    double maxPrice,
    int startIndex,
    int endIndex,
    double chartHeight,
    double chartWidth,
    double emptySpaceWidth,
  ) {
    if (data.isEmpty || movingAverages.isEmpty) return;

    final double totalCandleWidth = candleWidth + spacing;
    final double candleDrawingWidth = chartWidth - emptySpaceWidth;
    final int visibleCandles = endIndex - startIndex;
    final double startX = candleDrawingWidth - (visibleCandles * totalCandleWidth);

    for (int period in movingAverages.keys) {
      if (!(maVisibility[period] ?? false)) continue;

      final List<double> maData = movingAverages[period]!;
      final Color maColor = ChartConstants.maColors[period] ?? Colors.grey;
      
      _drawMovingAverageLine(
        canvas,
        maData,
        startX,
        totalCandleWidth,
        startIndex,
        endIndex,
        minPrice,
        maxPrice,
        chartHeight,
        maColor,
      );
    }
  }

  static void _drawMovingAverageLine(
    Canvas canvas,
    List<double> maData,
    double startX,
    double totalCandleWidth,
    int startIndex,
    int endIndex,
    double minPrice,
    double maxPrice,
    double chartHeight,
    Color color,
  ) {
    if (maData.isEmpty) return;

    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final List<Offset> points = [];

    for (int i = startIndex; i < endIndex && i < maData.length; i++) {
      final double maValue = maData[i];
      if (maValue.isNaN || maValue.isInfinite) continue;

      final double x = startX + (i - startIndex) * totalCandleWidth + totalCandleWidth / 2;
      final double y = _priceToY(maValue, minPrice, maxPrice, chartHeight);
      
      points.add(Offset(x, y));
    }

    if (points.length > 1) {
      for (int i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  static double _priceToY(double price, double minPrice, double maxPrice, double chartHeight) {
    if (maxPrice == minPrice) return chartHeight / 2;
    final double priceRange = maxPrice - minPrice;
    final double normalizedPrice = (price - minPrice) / priceRange;
    return chartHeight - (normalizedPrice * chartHeight);
  }
}
