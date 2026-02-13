import 'package:flutter/material.dart';
import '../../models/price_data.dart';

/// トレンド背景専用のCustomPainter
class TrendBackgroundPainter extends CustomPainter {
  final List<PriceData> data;
  final Map<int, List<double>> movingAverages;
  final double candleWidth;
  final double spacing;
  final int startIndex;
  final int endIndex;
  final double chartHeight;
  final double chartWidth;
  final double emptySpaceWidth;
  final bool showRisingBackground;
  final bool showFallingBackground;

  TrendBackgroundPainter({
    required this.data,
    required this.movingAverages,
    required this.candleWidth,
    required this.spacing,
    required this.startIndex,
    required this.endIndex,
    required this.chartHeight,
    required this.chartWidth,
    required this.emptySpaceWidth,
    required this.showRisingBackground,
    required this.showFallingBackground,
  });

  @override
  void paint(Canvas canvas, Size size) {
    TrendBackgroundPainterHelper.drawTrendBackground(
      canvas,
      size,
      data,
      movingAverages,
      candleWidth,
      spacing,
      startIndex,
      endIndex,
      chartHeight,
      chartWidth,
      emptySpaceWidth,
      showRisingBackground,
      showFallingBackground,
    );
  }

  @override
  bool shouldRepaint(TrendBackgroundPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.movingAverages != movingAverages ||
        oldDelegate.candleWidth != candleWidth ||
        oldDelegate.spacing != spacing ||
        oldDelegate.startIndex != startIndex ||
        oldDelegate.endIndex != endIndex ||
        oldDelegate.chartHeight != chartHeight ||
        oldDelegate.chartWidth != chartWidth ||
        oldDelegate.emptySpaceWidth != emptySpaceWidth ||
        oldDelegate.showRisingBackground != showRisingBackground ||
        oldDelegate.showFallingBackground != showFallingBackground;
  }
}

/// トレンド背景専用の描画ヘルパークラス
class TrendBackgroundPainterHelper {
  static void drawTrendBackground(
    Canvas canvas,
    Size size,
    List<PriceData> data,
    Map<int, List<double>> movingAverages,
    double candleWidth,
    double spacing,
    int startIndex,
    int endIndex,
    double chartHeight,
    double chartWidth,
    double emptySpaceWidth,
    bool showRisingBackground,
    bool showFallingBackground,
  ) {
    if (data.isEmpty || movingAverages.isEmpty) return;
    
    // 必要な移動平均線データを取得
    final List<double>? ma13 = movingAverages[13];
    final List<double>? ma60 = movingAverages[60];
    final List<double>? ma300 = movingAverages[300];
    
    if (ma13 == null || ma60 == null || ma300 == null) return;
    
    final double totalCandleWidth = candleWidth + spacing;
    final double candleDrawingWidth = chartWidth - emptySpaceWidth;
    final int visibleCandles = endIndex - startIndex;
    final double startX = candleDrawingWidth - (visibleCandles * totalCandleWidth);
    
    // 上昇背景を描画
    if (showRisingBackground) {
      _drawRisingBackground(
        canvas,
        ma13,
        ma60,
        ma300,
        startX,
        totalCandleWidth,
        startIndex,
        endIndex,
        chartHeight,
      );
    }
    
    // 下降背景を描画
    if (showFallingBackground) {
      _drawFallingBackground(
        canvas,
        ma13,
        ma60,
        ma300,
        startX,
        totalCandleWidth,
        startIndex,
        endIndex,
        chartHeight,
      );
    }
  }
  
  static void _drawRisingBackground(
    Canvas canvas,
    List<double> ma13,
    List<double> ma60,
    List<double> ma300,
    double startX,
    double totalCandleWidth,
    int startIndex,
    int endIndex,
    double chartHeight,
  ) {
    final Paint risingPaint = Paint()
      ..color = Colors.green.withAlpha(26) // 0.1 * 255 = 25.5 -> 26
      ..style = PaintingStyle.fill;
    
    final List<Offset> upperPoints = [];
    final List<Offset> lowerPoints = [];
    
    for (int i = startIndex; i < endIndex && i < ma13.length && i < ma60.length && i < ma300.length; i++) {
      final double ma13Value = ma13[i];
      final double ma60Value = ma60[i];
      final double ma300Value = ma300[i];
      
      // 上昇条件: MA13 > MA60 > MA300
      if (ma13Value > ma60Value && ma60Value > ma300Value) {
        final double x = startX + (i - startIndex) * totalCandleWidth + totalCandleWidth / 2;
        
        // 上昇背景の上限（MA13）
        upperPoints.add(Offset(x, 0));
        
        // 上昇背景の下限（MA300）
        lowerPoints.add(Offset(x, chartHeight));
      }
    }
    
    if (upperPoints.isNotEmpty && lowerPoints.isNotEmpty) {
      _drawBackgroundArea(canvas, upperPoints, lowerPoints, risingPaint);
    }
  }
  
  static void _drawFallingBackground(
    Canvas canvas,
    List<double> ma13,
    List<double> ma60,
    List<double> ma300,
    double startX,
    double totalCandleWidth,
    int startIndex,
    int endIndex,
    double chartHeight,
  ) {
    final Paint fallingPaint = Paint()
      ..color = Colors.red.withAlpha(26) // 0.1 * 255 = 25.5 -> 26
      ..style = PaintingStyle.fill;
    
    final List<Offset> upperPoints = [];
    final List<Offset> lowerPoints = [];
    
    for (int i = startIndex; i < endIndex && i < ma13.length && i < ma60.length && i < ma300.length; i++) {
      final double ma13Value = ma13[i];
      final double ma60Value = ma60[i];
      final double ma300Value = ma300[i];
      
      // 下降条件: MA13 < MA60 < MA300
      if (ma13Value < ma60Value && ma60Value < ma300Value) {
        final double x = startX + (i - startIndex) * totalCandleWidth + totalCandleWidth / 2;
        
        // 下降背景の上限（MA300）
        upperPoints.add(Offset(x, 0));
        
        // 下降背景の下限（MA13）
        lowerPoints.add(Offset(x, chartHeight));
      }
    }
    
    if (upperPoints.isNotEmpty && lowerPoints.isNotEmpty) {
      _drawBackgroundArea(canvas, upperPoints, lowerPoints, fallingPaint);
    }
  }
  
  static void _drawBackgroundArea(
    Canvas canvas,
    List<Offset> upperPoints,
    List<Offset> lowerPoints,
    Paint paint,
  ) {
    if (upperPoints.length != lowerPoints.length) return;
    
    final Path path = Path();
    
    // 上部の点を順番に接続
    for (int i = 0; i < upperPoints.length; i++) {
      if (i == 0) {
        path.moveTo(upperPoints[i].dx, upperPoints[i].dy);
      } else {
        path.lineTo(upperPoints[i].dx, upperPoints[i].dy);
      }
    }
    
    // 下部の点を逆順で接続
    for (int i = lowerPoints.length - 1; i >= 0; i--) {
      path.lineTo(lowerPoints[i].dx, lowerPoints[i].dy);
    }
    
    // パスを閉じる
    path.close();
    
    // 背景を描画
    canvas.drawPath(path, paint);
  }
}
