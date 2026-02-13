import 'package:flutter/material.dart';
import '../../models/price_data.dart';

/// 十字線専用の描画クラス
class CrosshairPainter {
  static void drawCrosshair(
    Canvas canvas,
    Size size,
    Offset? crosshairPosition,
    PriceData? hoveredCandle,
    double? hoveredPrice,
    double minPrice,
    double maxPrice,
    double chartHeight,
    double chartWidth,
    double emptySpaceWidth,
  ) {
    if (crosshairPosition == null || hoveredCandle == null || hoveredPrice == null) return;

    final double x = crosshairPosition.dx;
    final double y = crosshairPosition.dy;

    // 十字線の描画範囲を制限
    final double candleDrawingWidth = chartWidth - emptySpaceWidth;
    if (x < 0 || x > candleDrawingWidth || y < 0 || y > chartHeight) return;

    _drawCrosshairLines(canvas, x, y, chartHeight, candleDrawingWidth);
    _drawCrosshairLabels(
      canvas,
      hoveredCandle,
      hoveredPrice,
      x,
      y,
      minPrice,
      maxPrice,
      chartHeight,
      candleDrawingWidth,
    );
  }

  static void _drawCrosshairLines(
    Canvas canvas,
    double x,
    double y,
    double chartHeight,
    double chartWidth,
  ) {
    final Paint crosshairPaint = Paint()
      ..color = Colors.white.withAlpha(204)
      ..strokeWidth = 1.0;

    // 縦線
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, chartHeight),
      crosshairPaint,
    );

    // 横線
    canvas.drawLine(
      Offset(0, y),
      Offset(chartWidth, y),
      crosshairPaint,
    );
  }

  static void _drawCrosshairLabels(
    Canvas canvas,
    PriceData hoveredCandle,
    double hoveredPrice,
    double x,
    double y,
    double minPrice,
    double maxPrice,
    double chartHeight,
    double chartWidth,
  ) {
    // 価格ラベル（右側）
    _drawPriceLabel(canvas, hoveredPrice, x, y, chartWidth);

    // 時間ラベル（下部）
    _drawTimeLabel(canvas, hoveredCandle, x, y, chartHeight);
  }

  static void _drawPriceLabel(
    Canvas canvas,
    double price,
    double x,
    double y,
    double chartWidth,
  ) {
    final TextPainter pricePainter = TextPainter(
      text: TextSpan(
        text: price.toStringAsFixed(5),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          backgroundColor: Colors.black54,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    pricePainter.layout();

    final double labelX = chartWidth - pricePainter.width - 5;
    final double labelY = y - pricePainter.height / 2;

    // 背景を描画
    final Paint backgroundPaint = Paint()
      ..color = Colors.black54;
    
    canvas.drawRect(
      Rect.fromLTWH(labelX - 2, labelY - 2, pricePainter.width + 4, pricePainter.height + 4),
      backgroundPaint,
    );

    pricePainter.paint(canvas, Offset(labelX, labelY));
  }

  static void _drawTimeLabel(
    Canvas canvas,
    PriceData hoveredCandle,
    double x,
    double y,
    double chartHeight,
  ) {
    final TextPainter timePainter = TextPainter(
      text: TextSpan(
        text: hoveredCandle.formattedDateTime,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          backgroundColor: Colors.black54,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    timePainter.layout();

    final double labelX = x - timePainter.width / 2;
    final double labelY = chartHeight - timePainter.height - 5;

    // 背景を描画
    final Paint backgroundPaint = Paint()
      ..color = Colors.black54;
    
    canvas.drawRect(
      Rect.fromLTWH(labelX - 2, labelY - 2, timePainter.width + 4, timePainter.height + 4),
      backgroundPaint,
    );

    timePainter.paint(canvas, Offset(labelX, labelY));
  }
}
