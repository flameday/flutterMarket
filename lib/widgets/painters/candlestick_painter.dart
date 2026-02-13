import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/price_data.dart';

/// K線専用の描画クラス
class CandlestickPainter {
  static void drawCandlesticks(
    Canvas canvas,
    Size size,
    List<PriceData> data,
    double candleWidth,
    double spacing,
    double minPrice,
    double maxPrice,
    int startIndex,
    int endIndex,
    double chartHeight,
    double chartWidth,
    double emptySpaceWidth,
    PriceData? hoveredCandle,
  ) {
    if (data.isEmpty || startIndex >= endIndex) return;

    final double totalCandleWidth = candleWidth + spacing;
    final double candleDrawingWidth = chartWidth - emptySpaceWidth;
    final int visibleCandles = endIndex - startIndex;
    final double startX = candleDrawingWidth - (visibleCandles * totalCandleWidth);

    for (int i = startIndex; i < endIndex && i < data.length; i++) {
      final PriceData candle = data[i];
      final double x = startX + (i - startIndex) * totalCandleWidth;
      final bool isHovered = hoveredCandle == candle;

      _drawSingleCandlestick(
        canvas,
        candle,
        x,
        candleWidth,
        minPrice,
        maxPrice,
        chartHeight,
        isHovered,
      );
    }
  }

  static void _drawSingleCandlestick(
    Canvas canvas,
    PriceData candle,
    double x,
    double candleWidth,
    double minPrice,
    double maxPrice,
    double chartHeight,
    bool isHovered,
  ) {
    final double priceRange = maxPrice - minPrice;
    if (priceRange == 0) return;

    final double openY = _priceToY(candle.open, minPrice, maxPrice, chartHeight);
    final double closeY = _priceToY(candle.close, minPrice, maxPrice, chartHeight);
    final double highY = _priceToY(candle.high, minPrice, maxPrice, chartHeight);
    final double lowY = _priceToY(candle.low, minPrice, maxPrice, chartHeight);

    final bool isBullish = candle.close > candle.open;
    final Color candleColor = isBullish ? Colors.green : Colors.red;
    final Color wickColor = isHovered ? Colors.yellow : Colors.white;

    final Paint wickPaint = Paint()
      ..color = wickColor
      ..strokeWidth = 1.0;

    final Paint bodyPaint = Paint()
      ..color = candleColor
      ..style = PaintingStyle.fill;

    final Paint bodyStrokePaint = Paint()
      ..color = isHovered ? Colors.yellow : candleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHovered ? 2.0 : 1.0;

    // ウィック（上下の線）を描画
    canvas.drawLine(
      Offset(x + candleWidth / 2, highY),
      Offset(x + candleWidth / 2, lowY),
      wickPaint,
    );

    // ボディ（四角形）を描画
    final double bodyTop = math.min(openY, closeY);
    final double bodyBottom = math.max(openY, closeY);
    final double bodyHeight = bodyBottom - bodyTop;

    if (bodyHeight > 0) {
      final Rect bodyRect = Rect.fromLTWH(x, bodyTop, candleWidth, bodyHeight);
      canvas.drawRect(bodyRect, bodyPaint);
      canvas.drawRect(bodyRect, bodyStrokePaint);
    } else {
      // ドージ（同じ価格）の場合は横線を描画
      canvas.drawLine(
        Offset(x, openY),
        Offset(x + candleWidth, openY),
        bodyStrokePaint,
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

