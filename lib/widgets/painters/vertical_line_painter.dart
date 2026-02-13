import 'package:flutter/material.dart';
import '../../models/price_data.dart';
import '../../models/vertical_line.dart';
import '../../utils/kline_timestamp_utils.dart';

/// 縦線専用の描画クラス
class VerticalLinePainter {
  static void drawVerticalLines(
    Canvas canvas,
    Size size,
    List<PriceData> data,
    List<VerticalLine> verticalLines,
    double candleWidth,
    double spacing,
    int startIndex,
    int endIndex,
    double chartHeight,
    double chartWidth,
    double emptySpaceWidth,
  ) {
    if (verticalLines.isEmpty || data.isEmpty) return;

    final double totalCandleWidth = candleWidth + spacing;
    final double candleDrawingWidth = chartWidth - emptySpaceWidth;
    final int visibleCandles = endIndex - startIndex;
    final double startX = candleDrawingWidth - (visibleCandles * totalCandleWidth);

    for (final verticalLine in verticalLines) {
      final int? candleIndex = KlineTimestampUtils.findKlineIndexByTimestamp(
        data,
        verticalLine.timestamp,
      );

      if (candleIndex == null || candleIndex < startIndex || candleIndex >= endIndex) {
        continue;
      }

      final double x = startX + (candleIndex - startIndex) * totalCandleWidth + totalCandleWidth / 2;
      
      _drawSingleVerticalLine(
        canvas,
        verticalLine,
        x,
        chartHeight,
      );
    }
  }

  static void _drawSingleVerticalLine(
    Canvas canvas,
    VerticalLine verticalLine,
    double x,
    double chartHeight,
  ) {
    final Paint linePaint = Paint()
      ..color = Color(int.parse(verticalLine.color.replaceFirst('#', '0xFF')))
      ..strokeWidth = verticalLine.width
      ..style = PaintingStyle.stroke;

    // 縦線を描画
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, chartHeight),
      linePaint,
    );

    // ラベルを描画（IDを表示）
    _drawVerticalLineLabel(
      canvas,
      verticalLine,
      x,
      chartHeight,
    );
  }

  static void _drawVerticalLineLabel(
    Canvas canvas,
    VerticalLine verticalLine,
    double x,
    double chartHeight,
  ) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: verticalLine.id.substring(0, 8), // IDの最初の8文字を表示
        style: TextStyle(
          color: Color(int.parse(verticalLine.color.replaceFirst('#', '0xFF'))),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final double labelX = x - textPainter.width / 2;
    final double labelY = 10; // 上部に配置

    textPainter.paint(canvas, Offset(labelX, labelY));
  }
}
