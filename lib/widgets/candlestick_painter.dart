import 'package:flutter/material.dart';
import '../models/chart_object.dart';
import '../models/price_data.dart';
import '../constants/chart_constants.dart';
import '../services/log_service.dart';
import '../models/trading_pair.dart';
import 'painters/chart_object_renderer.dart';

/// キャンドルスティックチャートを描画するカスタムPainter
///
/// 渲染业务分三层：
/// 1) K线层（坐标系、网格、K线本体）
/// 2) 指标层（均线、波浪高低点、布林及其关联对象）
/// 3) 用户手绘层（斜线/图形/选区等交互对象）
class CandlestickPainter extends CustomPainter {
  final List<PriceData> data;
  final double candleWidth;
  final double spacing;
  final double minPrice;
  final double maxPrice;
  final int startIndex;
  final int endIndex;
  final double chartHeight;
  final double chartWidth;
  final double emptySpaceWidth; // 空白区域幅
  final Offset? crosshairPosition;
  final PriceData? hoveredCandle;
  final double? hoveredPrice;
  final Map<int, List<double>>? movingAverages; // 移動平均線データ
  final Map<int, bool>? maVisibility; // 移動平均線の表示状態
  final Map<int, String>? maColorSettings; // MA色設定
  final Map<int, double>? maAlphas; // MA透明度設定
  final Color? backgroundColor; // 背景色
  final bool isKlineVisible; // K線表示/非表示
  final bool isMaTrendBackgroundEnabled; // 移动平均线趋势背景是否启用
  final List<Color?>? maTrendBackgroundColors; // 移动平均线趋势背景颜色
  final TradingPair? selectedTradingPair;
  // Object贴层数据（所有斜线/形状/选区等都应进入此集合）
  final List<ChartObject> chartObjects;
  final ChartObjectRendererRegistry _objectRendererRegistry =
      ChartObjectRendererRegistry();

  CandlestickPainter({
    required this.data,
    required this.candleWidth,
    required this.spacing,
    required this.minPrice,
    required this.maxPrice,
    required this.startIndex,
    required this.endIndex,
    required this.chartHeight,
    required this.chartWidth,
    this.emptySpaceWidth = 0.0, // デフォルト値
    this.crosshairPosition,
    this.hoveredCandle,
    this.hoveredPrice,
    this.movingAverages,
    this.maVisibility,
    this.maColorSettings,
    this.maAlphas,
    this.backgroundColor,
    this.isKlineVisible = true,
    this.isMaTrendBackgroundEnabled = false,
    this.maTrendBackgroundColors,
    this.selectedTradingPair,
    this.chartObjects = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // 最底層の背景色を描画
    if (backgroundColor != null) {
      // // LogService.instance.debug('CandlestickPainter', '背景色を描画: $backgroundColor, サイズ: ${size.width}x${size.height}');
      final backgroundPaint = Paint()..color = backgroundColor!;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);
    } else {
      // LogService.instance.debug('CandlestickPainter', '背景色がnull、透明背景を使用');
      // デフォルトは透明背景（何も描画しない）
      // これにより上位のContainerの背景色が表示される
    }

    // 移动平均线趋势背景绘制
    if (isMaTrendBackgroundEnabled && maTrendBackgroundColors != null && maTrendBackgroundColors!.isNotEmpty) {
      _drawMaTrendBackground(canvas, size);
    }

    // 性能監視：描画開始時間
    final stopwatch = Stopwatch()..start();

    final Paint bullishPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    final Paint bearishPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;

    final Paint wickPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final Paint gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // ==========================
    // 1) K线层（Board）
    // ==========================

    // グリッド線を描画
    _drawGrid(canvas, size, gridPaint);

    _drawChartObjectsByLayer(canvas, size, ChartObjectLayer.belowIndicators);

    // キャンドルスティックを描画（K線表示が有効な場合のみ）
    if (isKlineVisible) {
    _drawCandlesticks(canvas, size, bullishPaint, bearishPaint, wickPaint);
    }

    // 移動平均線を描画
    _drawMovingAverages(canvas, size);

    // ==========================
    // 2) 指标层（Indicators）
    // ==========================
    _drawChartObjectsByLayer(canvas, size, ChartObjectLayer.aboveIndicators);

    // 価格ラベルを描画
    _drawPriceLabels(canvas, size);

    // 時間ラベルを描画
    _drawTimeLabels(canvas, size);

    // 十字カーソルとラベルを描画
    _drawCrosshairAndLabels(canvas, size);

    // 线/形类覆盖物统一走 Object 管线，不再使用旧直绘回退路径。

    // ==========================
    // 3) 用户手绘层（User Drawings）
    // ==========================
    _drawChartObjectsByLayer(canvas, size, ChartObjectLayer.interaction);

    // 性能監視：描画完了時間
    stopwatch.stop();
    // 性能監視：描画時間が長すぎる場合に警告
    if (stopwatch.elapsedMilliseconds > 16) {
      Log.warning('CandlestickPainter', '描画性能警告: ${stopwatch.elapsedMilliseconds}ms (データ量: ${data.length}, 表示K線: ${endIndex - startIndex})');
    }
  }

  void _drawChartObjectsByLayer(
    Canvas canvas,
    Size size,
    ChartObjectLayer layer,
  ) {
    if (chartObjects.isEmpty) return;
    _objectRendererRegistry.renderObjects(
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
      objects: chartObjects,
      layer: layer,
    );
  }

  void _drawGrid(Canvas canvas, Size size, Paint gridPaint) {
    // 性能最適化：グリッド線数を削減
    // 水平グリッド線（価格レベル）
    final int gridLines = ChartConstants.maxGridLines;
    for (int i = 0; i <= gridLines; i++) {
      final double y = (size.height / gridLines) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 垂直グリッド線（時間レベル）
    final int timeGridLines = ChartConstants.maxTimeGridLines;
    for (int i = 0; i <= timeGridLines; i++) {
      final double x = (size.width / timeGridLines) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  void _drawCandlesticks(
    Canvas canvas,
    Size size,
    Paint bullishPaint,
    Paint bearishPaint,
    Paint wickPaint,
  ) {
    // デバッグログ：インデックス範囲を確認
    if (startIndex < 0 || endIndex <= 0 || startIndex >= data.length) {
      // LogService.instance.warning('CandlestickPainter', 'K線描画: 無効なインデックス範囲 startIndex=$startIndex, endIndex=$endIndex, data.length=${data.length}');
      return;
    }

    final int visibleCandles = endIndex - startIndex;
    if (visibleCandles <= 0) return;

    // 大量データの場合の描画制限（通常キャンドル描画時のみ適用）
    const int maxDrawCandles = 200000;

    final double totalWidth = candleWidth + spacing;
    
    // 新しいスケーリングロジック：K線の右端を原点とした配置
    // K線描画幅 = 画面幅 - 空白区域幅
    final double candleDrawingWidth = size.width - emptySpaceWidth;

    // 右端から左に向かってK線を配置（右端が原点）
    // 最後のK線が右端に表示されるように配置
    final double rightEdgeX = candleDrawingWidth;
    // 座標系の基準点を計算。すべての描画要素で一貫性を保つため、
    // 実際に描画するK線数(effectiveVisibleCandles)ではなく、
    // 表示範囲内の全K線数(visibleCandles)を使用する。
    final double startX = rightEdgeX - (visibleCandles * totalWidth);

    // 缩小时采用类似 TradingView 的简化绘制：按像素列聚合OHLC，减少糊感并提升可读性
    if (candleWidth <= 2.2) {
      _drawCompressedCandlesticks(
        canvas,
        size,
        startX,
        candleDrawingWidth,
        visibleCandles,
        0,
      );
      return;
    }

    final int effectiveVisibleCandles = visibleCandles > maxDrawCandles
      ? maxDrawCandles
      : visibleCandles;
    final int startOffset = visibleCandles > maxDrawCandles
      ? (visibleCandles - maxDrawCandles)
      : 0;
    
    // 性能最適化：早期終了条件を追加
    final double minVisibleX = -candleWidth; // 左側の描画境界
    final double maxVisibleX = candleDrawingWidth + candleWidth; // 右側の描画境界

    for (int i = startOffset; i < startOffset + effectiveVisibleCandles; i++) {
      final int dataIndex = startIndex + i;
      if (dataIndex >= data.length) break;
      if (dataIndex < 0) continue;
      
      final double x = startX + i * totalWidth;

      // 早期終了：画面外のK線は描画しない
      if (x > maxVisibleX) break;
      if (x + candleWidth < minVisibleX) continue;

      final PriceData candle = data[dataIndex];

      // 価格をY座標に変換
      final double openY = _priceToY(candle.open, size.height);
      final double highY = _priceToY(candle.high, size.height);
      final double lowY = _priceToY(candle.low, size.height);
      final double closeY = _priceToY(candle.close, size.height);

      // 上昇/下降を判定
      final bool isBullish = candle.close >= candle.open;
      final Paint candlePaint = isBullish ? bullishPaint : bearishPaint;

      // ヒゲ（ウィック）を描画
      canvas.drawLine(
        Offset(x + candleWidth / 2, highY),
        Offset(x + candleWidth / 2, lowY),
        wickPaint,
      );

      // 実体（ボディ）を描画
      final double bodyTop = isBullish ? closeY : openY;
      final double bodyBottom = isBullish ? openY : closeY;
      final double bodyHeight = (bodyBottom - bodyTop).abs();

      if (bodyHeight > 0) {
        canvas.drawRect(
          Rect.fromLTWH(x, bodyTop, candleWidth, bodyHeight),
          candlePaint,
        );
      } else {
        // ドジ（同じ価格）の場合は線で描画
        canvas.drawLine(
          Offset(x, openY),
          Offset(x + candleWidth, openY),
          wickPaint..strokeWidth = 2.0,
        );
      }
    }
  }

  void _drawCompressedCandlesticks(
    Canvas canvas,
    Size size,
    double startX,
    double candleDrawingWidth,
    int visibleCandles,
    int startOffset,
  ) {
    final double totalWidth = candleWidth + spacing;
    final double minVisibleX = -1.0;
    final double maxVisibleX = candleDrawingWidth + 1.0;

    final Map<int, _PixelOhlcBucket> buckets = {};

    for (int i = startOffset; i < visibleCandles; i++) {
      final int dataIndex = startIndex + i;
      if (dataIndex < 0 || dataIndex >= data.length) continue;

      final double xCenter = startX + i * totalWidth + (candleWidth / 2);
      if (xCenter < minVisibleX) continue;
      if (xCenter > maxVisibleX) break;

      final int pixelX = xCenter.floor();
      final PriceData candle = data[dataIndex];

      final existing = buckets[pixelX];
      if (existing == null) {
        buckets[pixelX] = _PixelOhlcBucket(
          open: candle.open,
          close: candle.close,
          high: candle.high,
          low: candle.low,
        );
      } else {
        existing.close = candle.close;
        if (candle.high > existing.high) existing.high = candle.high;
        if (candle.low < existing.low) existing.low = candle.low;
      }
    }

    final List<int> sortedPixels = buckets.keys.toList()..sort();
    for (final pixelX in sortedPixels) {
      final bucket = buckets[pixelX]!;
      final bool isBullish = bucket.close >= bucket.open;
      final Color color = isBullish ? Colors.green : Colors.red;

      final Paint hlPaint = Paint()
        ..color = color
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
        ..isAntiAlias = false;

      final Paint tickPaint = Paint()
        ..color = color
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
        ..isAntiAlias = false;

      final double x = pixelX.toDouble() + 0.5;
      final double highY = _priceToY(bucket.high, size.height);
      final double lowY = _priceToY(bucket.low, size.height);
      final double openY = _priceToY(bucket.open, size.height);
      final double closeY = _priceToY(bucket.close, size.height);

      // 类TradingView缩小时的OHLC柱线：高低竖线 + 开收盘短横
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), hlPaint);
      canvas.drawLine(Offset(x - 1.0, openY), Offset(x, openY), tickPaint);
      canvas.drawLine(Offset(x, closeY), Offset(x + 1.0, closeY), tickPaint);
    }
  }

  void _drawMovingAverages(Canvas canvas, Size size) {
    if (movingAverages == null || movingAverages!.isEmpty) return;

    // デバッグログ：インデックス範囲を確認
    if (startIndex < 0 || endIndex <= 0 || startIndex >= data.length) {
      // LogService.instance.warning('CandlestickPainter', '移動平均線描画: 無効なインデックス範囲 startIndex=$startIndex, endIndex=$endIndex, data.length=${data.length}');
      return;
    }

    final double totalWidth = candleWidth + spacing;
    final double candleDrawingWidth = size.width - emptySpaceWidth;
    final double rightEdgeX = candleDrawingWidth;
    final int visibleCandles = endIndex - startIndex;
    final double startX = rightEdgeX - (visibleCandles * totalWidth);

    for (int period in movingAverages!.keys) {
      final List<double>? maData = movingAverages![period];
      if (maData == null || maData.isEmpty) continue;

      Color maColor;
      if (maColorSettings != null && maColorSettings!.containsKey(period)) {
        try {
          maColor = Color(int.parse(maColorSettings![period]!));
        } catch (e) {
          // LogService.instance.error('MA色解析', 'MA色解析エラー: $e');
          maColor = ChartConstants.maColors[period] ?? Colors.grey;
        }
      } else {
        maColor = ChartConstants.maColors[period] ?? Colors.grey;
      }
      
      // 透明度を適用
      if (maAlphas != null && maAlphas!.containsKey(period)) {
        final alpha = maAlphas![period]!;
        maColor = maColor.withValues(alpha: alpha);
      }
      
      final Paint maPaint = Paint()
        ..color = maColor
        ..strokeWidth = ChartConstants.maLineWidth
        ..style = PaintingStyle.stroke;

      // 移動平均線の点を計算
      List<Offset> maPoints = [];

      for (int i = 0; i < visibleCandles; i++) {
        final int dataIndex = startIndex + i;
        if (dataIndex < 0 || dataIndex >= data.length || dataIndex >= maData.length) break;

        final double maValue = maData[dataIndex];
        if (maValue.isNaN) continue; // NaNの場合はスキップ

        final double x = startX + i * totalWidth + candleWidth / 2;
        final double y = _priceToY(maValue, size.height);

        maPoints.add(Offset(x, y));
      }

      // 移動平均線を描画
      if (maPoints.length > 1) {
        for (int i = 0; i < maPoints.length - 1; i++) {
          canvas.drawLine(maPoints[i], maPoints[i + 1], maPaint);
        }
      }
    }
  }

  void _drawPriceLabels(Canvas canvas, Size size) {
    final pair = selectedTradingPair ?? TradingPair.eurusd;
    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final TextStyle labelStyle = TextStyle(
      color: Colors.grey[400],
      fontSize: ChartConstants.labelFontSize,
    );

    // 価格ラベルを描画（性能最適化：ラベル数を削減）
    final int labelCount = 4; // 5から4に削減
    for (int i = 0; i <= labelCount; i++) {
      final double price = minPrice + (maxPrice - minPrice) * (i / labelCount);
      final double y = _priceToY(price, size.height);

      textPainter.text = TextSpan(
        text: pair.formatPrice(price),
        style: labelStyle,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(size.width - textPainter.width - 5, y - textPainter.height / 2),
      );
    }
  }

  void _drawCrosshairAndLabels(Canvas canvas, Size size) {
    if (crosshairPosition == null) return;
    final pair = selectedTradingPair ?? TradingPair.eurusd;

    final crosshairPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 垂直線（破線）
    _drawDashedLine(
      canvas,
      Offset(crosshairPosition!.dx, 0),
      Offset(crosshairPosition!.dx, size.height),
      crosshairPaint,
    );

    // 水平線（破線）
    _drawDashedLine(
      canvas,
      Offset(0, crosshairPosition!.dy),
      Offset(size.width, crosshairPosition!.dy),
      crosshairPaint,
    );

    // ラベルのスタイル
    final labelStyle = TextStyle(
      color: Colors.white,
      fontSize: ChartConstants.crosshairFontSize,
    );
    final labelBackgroundPaint = Paint()..color = Colors.grey[800]!;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // 価格ラベル (Y軸)
    if (hoveredPrice != null) {
      textPainter.text = TextSpan(
        text: pair.formatPrice(hoveredPrice!),
        style: labelStyle,
      );
      textPainter.layout();
      final labelWidth = textPainter.width + 8;
      final labelHeight = textPainter.height + 4;
      final labelY = (crosshairPosition!.dy - labelHeight / 2)
          .clamp(0, size.height - labelHeight)
          .toDouble();

      final rect = Rect.fromLTWH(
        size.width - labelWidth,
        labelY,
        labelWidth,
        labelHeight,
      );
      canvas.drawRect(rect, labelBackgroundPaint);
      textPainter.paint(
        canvas,
        Offset(size.width - labelWidth + 4, labelY + 2),
      );
    }

    // 時間ラベル (X軸)
    if (hoveredCandle != null) {
      textPainter.text = TextSpan(
        text: hoveredCandle!.formattedDateTime,
        style: labelStyle,
      );
      textPainter.layout();
      final labelWidth = textPainter.width + 8;
      final labelHeight = textPainter.height + 4;
      final labelX = (crosshairPosition!.dx - labelWidth / 2)
          .clamp(0, size.width - labelWidth)
          .toDouble();

      final rect = Rect.fromLTWH(
        labelX,
        size.height - labelHeight,
        labelWidth,
        labelHeight,
      );
      canvas.drawRect(rect, labelBackgroundPaint);
      textPainter.paint(
        canvas,
        Offset(labelX + 4, size.height - labelHeight + 2),
      );
    }
  }

  double _priceToY(double price, double height) {
    final double priceRange = maxPrice - minPrice;
    if (priceRange == 0) return height / 2;
    
    final double normalizedPrice = (price - minPrice) / priceRange;
    return height - (normalizedPrice * height);
  }

  void _drawTimeLabels(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    final TextStyle labelStyle = TextStyle(
      color: Colors.grey[400],
      fontSize: ChartConstants.labelFontSize,
    );

    // 時間ラベルを描画（X軸）（性能最適化：ラベル数を削減）
    final int labelCount = 4; // 6から4に削減
    final int totalCandles = endIndex - startIndex;

    if (totalCandles <= 0) return;

    for (int i = 0; i <= labelCount; i++) {
      final int candleIndex = (totalCandles * i / labelCount).floor();
      final int dataIndex = startIndex + candleIndex;

      if (dataIndex < 0 || dataIndex >= data.length) continue;

      final PriceData candle = data[dataIndex];
      final DateTime time = DateTime.fromMillisecondsSinceEpoch(
        candle.timestamp,
        isUtc: true,
      );

      // 時間フォーマット（MM/dd HH:mm）
      final String timeText =
          '${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

      textPainter.text = TextSpan(text: timeText, style: labelStyle);
      textPainter.layout();

      // K線の位置を計算
      final double totalWidth = candleWidth + spacing;
      final double candleDrawingWidth = size.width - emptySpaceWidth;
      final double rightEdgeX = candleDrawingWidth;
      final double startX = rightEdgeX - (totalCandles * totalWidth);
      final double x = startX + (candleIndex * totalWidth) + (candleWidth / 2);

      // ラベルを描画（画面下部）
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - textPainter.height - 5),
      );
    }
  }

  /// 破線を描画
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double dashWidth = 5.0; // 破線セグメントの長さ
    const double dashSpace = 3.0; // 破線間隔の長さ

    final double distance = (end - start).distance;
    final int dashCount = (distance / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < dashCount; i++) {
      final double startRatio = (i * (dashWidth + dashSpace)) / distance;
      final double endRatio =
          ((i * (dashWidth + dashSpace)) + dashWidth) / distance;

      final Offset dashStart = Offset.lerp(start, end, startRatio)!;
      final Offset dashEnd = Offset.lerp(start, end, endRatio)!;

      canvas.drawLine(dashStart, dashEnd, paint);
    }
  }

  @override
  bool shouldRepaint(CandlestickPainter oldDelegate) {
    return oldDelegate.data != data ||
           oldDelegate.candleWidth != candleWidth ||
           oldDelegate.spacing != spacing ||
           oldDelegate.minPrice != minPrice ||
           oldDelegate.maxPrice != maxPrice ||
           oldDelegate.startIndex != startIndex ||
           oldDelegate.endIndex != endIndex ||
           oldDelegate.chartHeight != chartHeight ||
        oldDelegate.chartWidth != chartWidth ||
        oldDelegate.emptySpaceWidth != emptySpaceWidth ||
        oldDelegate.crosshairPosition != crosshairPosition ||
         oldDelegate.hoveredCandle != hoveredCandle ||
         oldDelegate.hoveredPrice != hoveredPrice ||
         oldDelegate.movingAverages != movingAverages ||
         oldDelegate.maVisibility != maVisibility ||
         oldDelegate.maColorSettings != maColorSettings ||
         oldDelegate.maAlphas != maAlphas ||
        oldDelegate.chartObjects != chartObjects ||
        oldDelegate.isKlineVisible != isKlineVisible;
  }

  /// K線の画面上でのX位置を取得（中心点）
  double _getCandleXPosition(int candleIndex) {
    final int visibleCandles = endIndex - startIndex;
    if (visibleCandles <= 0) {
      return -1;
    }

    // candleWidthは既にスケーリングファクターを含む（candlestick_chart.dartで渡される際に既にスケーリング済み）
    final double totalWidth = candleWidth + spacing;
    final double candleDrawingWidth = chartWidth - emptySpaceWidth;
    final double rightEdgeX = candleDrawingWidth;
    // This is the X of the left edge of the first visible candle in the viewport
    final double startDrawX = rightEdgeX - (visibleCandles * totalWidth);

    final int relativeIndex = candleIndex - startIndex;
    // Return the center of the candle
    return startDrawX + (relativeIndex * totalWidth) + (candleWidth / 2);
  }

  /// 绘制移动平均线趋势背景
  void _drawMaTrendBackground(Canvas canvas, Size size) {
    if (maTrendBackgroundColors == null || maTrendBackgroundColors!.isEmpty) return;
    
    final double totalWidth = candleWidth + spacing;
    final double candleDrawingWidth = size.width - emptySpaceWidth;
    final double rightEdgeX = candleDrawingWidth;
    final int visibleCandles = endIndex - startIndex;
    final double startX = rightEdgeX - (visibleCandles * totalWidth);
    
    // LogService.instance.debug('CandlestickPainter', '开始绘制移动平均线趋势背景: ${maTrendBackgroundColors!.length}个颜色点');
    
    for (int i = 0; i < visibleCandles; i++) {
      final int dataIndex = startIndex + i;
      
      if (dataIndex < 0 || dataIndex >= data.length || dataIndex >= maTrendBackgroundColors!.length) {
        continue;
      }
      
      final Color? trendColor = maTrendBackgroundColors![dataIndex];
      if (trendColor == null) {
        continue;
      }
      
      // 计算K线位置
      final double x = startX + i * totalWidth;
      final double candleX = x;
      final double candleWidth = this.candleWidth;
      
      // 绘制背景矩形
      final Paint backgroundPaint = Paint()
        ..color = trendColor
        ..style = PaintingStyle.fill;
      
      final Rect backgroundRect = Rect.fromLTWH(
        candleX,
        0,
        candleWidth,
        size.height,
      );
      
      canvas.drawRect(backgroundRect, backgroundPaint);
    }
    
    // LogService.instance.debug('CandlestickPainter', '移动平均线趋势背景绘制完成: $drawnBackgrounds个背景, 跳过$skippedBackgrounds个');
  }
}

class _PixelOhlcBucket {
  _PixelOhlcBucket({
    required this.open,
    required this.close,
    required this.high,
    required this.low,
  });

  final double open;
  double close;
  double high;
  double low;
}
