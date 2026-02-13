import 'package:flutter/material.dart';
import '../../models/price_data.dart';

/// 布林通道専用の描画クラス
class BollingerBandsPainter {
  static void drawBollingerBands(
    Canvas canvas,
    Size size,
    List<PriceData> data,
    Map<String, List<double>> bollingerBands,
    Map<String, Color> bbColors,
    Map<String, double> bbAlphas,
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
    if (data.isEmpty || bollingerBands.isEmpty) return;

    final double totalCandleWidth = candleWidth + spacing;
    final double candleDrawingWidth = chartWidth - emptySpaceWidth;
    final int visibleCandles = endIndex - startIndex;
    final double startX = candleDrawingWidth - (visibleCandles * totalCandleWidth);

    // 上軌と下軌の間の領域を塗りつぶし
    _drawBollingerBandsArea(
      canvas,
      bollingerBands,
      bbColors,
      bbAlphas,
      startX,
      totalCandleWidth,
      startIndex,
      endIndex,
      minPrice,
      maxPrice,
      chartHeight,
    );

    // 上軌線を描画
    if (bollingerBands.containsKey('upper')) {
      _drawBollingerBandLine(
        canvas,
        bollingerBands['upper']!,
        bbColors['upper'] ?? Colors.blue,
        bbAlphas['upper'] ?? 0.3,
        startX,
        totalCandleWidth,
        startIndex,
        endIndex,
        minPrice,
        maxPrice,
        chartHeight,
      );
    }

    // 中軌線を描画
    if (bollingerBands.containsKey('middle')) {
      _drawBollingerBandLine(
        canvas,
        bollingerBands['middle']!,
        bbColors['middle'] ?? Colors.orange,
        bbAlphas['middle'] ?? 0.3,
        startX,
        totalCandleWidth,
        startIndex,
        endIndex,
        minPrice,
        maxPrice,
        chartHeight,
      );
    }

    // 下軌線を描画
    if (bollingerBands.containsKey('lower')) {
      _drawBollingerBandLine(
        canvas,
        bollingerBands['lower']!,
        bbColors['lower'] ?? Colors.blue,
        bbAlphas['lower'] ?? 0.3,
        startX,
        totalCandleWidth,
        startIndex,
        endIndex,
        minPrice,
        maxPrice,
        chartHeight,
      );
    }
  }

  /// 布林通道の領域を塗りつぶし
  static void _drawBollingerBandsArea(
    Canvas canvas,
    Map<String, List<double>> bollingerBands,
    Map<String, Color> bbColors,
    Map<String, double> bbAlphas,
    double startX,
    double totalCandleWidth,
    int startIndex,
    int endIndex,
    double minPrice,
    double maxPrice,
    double chartHeight,
  ) {
    final upperBand = bollingerBands['upper'];
    final lowerBand = bollingerBands['lower'];
    
    if (upperBand == null || lowerBand == null) return;

    final double priceRange = maxPrice - minPrice;
    if (priceRange <= 0) return;

    // 領域の色を設定（上軌の色を使用、透明度を下げる）
    final areaColor = (bbColors['upper'] ?? Colors.blue)
        .withValues(alpha: (bbAlphas['upper'] ?? 0.7) * 0.3);

    final Paint areaPaint = Paint()
      ..color = areaColor
      ..style = PaintingStyle.fill;

    // 上軌と下軌の間の領域を描画
    final Path areaPath = Path();
    bool isFirstPoint = true;

    for (int i = 0; i < endIndex - startIndex; i++) {
      final int dataIndex = startIndex + i;
      if (dataIndex >= upperBand.length || dataIndex >= lowerBand.length) continue;
      
      final double upperValue = upperBand[dataIndex];
      final double lowerValue = lowerBand[dataIndex];
      
      if (upperValue.isNaN || lowerValue.isNaN) continue;

      final double x = startX + i * totalCandleWidth;
      final double upperY = chartHeight - ((upperValue - minPrice) / priceRange) * chartHeight;

      if (isFirstPoint) {
        areaPath.moveTo(x, upperY);
        isFirstPoint = false;
      } else {
        areaPath.lineTo(x, upperY);
      }
    }

    // 下軌を逆順で追加して閉じたパスを作成
    for (int i = (endIndex - startIndex) - 1; i >= 0; i--) {
      final int dataIndex = startIndex + i;
      if (dataIndex >= upperBand.length || dataIndex >= lowerBand.length) continue;
      
      final double lowerValue = lowerBand[dataIndex];
      if (lowerValue.isNaN) continue;

      final double x = startX + i * totalCandleWidth;
      final double lowerY = chartHeight - ((lowerValue - minPrice) / priceRange) * chartHeight;
      
      areaPath.lineTo(x, lowerY);
    }

    areaPath.close();
    canvas.drawPath(areaPath, areaPaint);
  }

  /// 布林通道の線を描画
  static void _drawBollingerBandLine(
    Canvas canvas,
    List<double> bandData,
    Color color,
    double alpha,
    double startX,
    double totalCandleWidth,
    int startIndex,
    int endIndex,
    double minPrice,
    double maxPrice,
    double chartHeight,
  ) {
    if (bandData.isEmpty) return;

    final double priceRange = maxPrice - minPrice;
    if (priceRange <= 0) return;

    final Paint linePaint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final Path linePath = Path();
    bool isFirstPoint = true;

    for (int i = 0; i < endIndex - startIndex; i++) {
      final int dataIndex = startIndex + i;
      if (dataIndex >= bandData.length) continue;
      
      final double value = bandData[dataIndex];
      if (value.isNaN) continue;

      final double x = startX + i * totalCandleWidth;
      final double y = chartHeight - ((value - minPrice) / priceRange) * chartHeight;

      if (isFirstPoint) {
        linePath.moveTo(x, y);
        isFirstPoint = false;
      } else {
        linePath.lineTo(x, y);
      }
    }

    canvas.drawPath(linePath, linePaint);
  }
}
