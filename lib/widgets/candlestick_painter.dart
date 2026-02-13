import 'package:flutter/material.dart';
import '../models/price_data.dart';
import '../models/vertical_line.dart';
import '../models/kline_selection.dart';
import '../models/manual_high_low_point.dart';
import '../services/trend_filtering_service.dart';
import '../services/cubic_curve_fitting_service.dart';
import '../services/ma60_filtering_service.dart';
import '../services/bollinger_bands_filtering_service.dart';
import '../constants/chart_constants.dart';
import '../utils/kline_timestamp_utils.dart';
import '../services/log_service.dart';
import '../models/trading_pair.dart';
import 'painters/bollinger_bands_painter.dart';

/// キャンドルスティックチャートを描画するカスタムPainter
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
  final List<VerticalLine>? verticalLines; // 縦線データ
  final double? selectionStartX; // 選択区域開始X座標
  final double? selectionEndX; // 選択区域終了X座標
  final int selectedKlineCount; // 選択されたK線数
  final FilteredWavePoints? filteredWavePoints; // フィルタリングされた高低点データ
  final bool isTrendFilteringEnabled; // トレンドフィルタリングが有効かどうか
  final CubicCurveResult? cubicCurveResult; // 3次曲线数据
  final bool isCubicCurveVisible; // 3次曲线是否可见
  final MA60FilteredCurveResult? ma60FilteredCurveResult; // 60均线过滤曲线数据
  final bool isMA60FilteredCurveVisible; // 60均线过滤曲线是否可见
  final BollingerBandsFilteredCurveResult? bollingerBandsFilteredCurveResult; // 布林线过滤曲线数据
  final bool isBollingerBandsFilteredCurveVisible; // 布林线过滤曲线是否可见
  final Map<String, List<double>>? bollingerBands; // 布林通道データ
  final bool isBollingerBandsVisible; // 布林通道が表示されるか
  final Map<String, Color>? bbColors; // 布林通道色設定
  final Map<String, double>? bbAlphas; // 布林通道透明度設定
  final List<KlineSelection>? klineSelections; // 保存されたK線選択区域
  final List<Map<String, dynamic>>? mergedWavePoints; // 最適化：事前にマージとソートされたウェーブポイント
  final bool isWavePointsVisible; // ウェーブポイントが表示されるか
  final bool isWavePointsLineVisible; // ウェーブポイント接続線が表示されるか
  final List<ManualHighLowPoint>? manualHighLowPoints; // 手動高低点データ
  final bool isManualHighLowVisible; // 手動高低点が表示されるか
  final Color? backgroundColor; // 背景色
  final bool isKlineVisible; // K線表示/非表示
  final bool isMaTrendBackgroundEnabled; // 移动平均线趋势背景是否启用
  final List<Color?>? maTrendBackgroundColors; // 移动平均线趋势背景颜色
  final TradingPair? selectedTradingPair;

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
    this.verticalLines,
    this.selectionStartX,
    this.selectionEndX,
    this.selectedKlineCount = 0,
    this.klineSelections,
    this.mergedWavePoints,
    this.isWavePointsVisible = true,
    this.isWavePointsLineVisible = false,
    this.manualHighLowPoints,
    this.isManualHighLowVisible = true,
    this.backgroundColor,
    this.isKlineVisible = true,
    this.filteredWavePoints,
    this.isTrendFilteringEnabled = false,
    this.cubicCurveResult,
    this.isCubicCurveVisible = false,
    this.ma60FilteredCurveResult,
    this.isMA60FilteredCurveVisible = false,
    this.bollingerBandsFilteredCurveResult,
    this.isBollingerBandsFilteredCurveVisible = false,
    this.bollingerBands,
    this.isBollingerBandsVisible = false,
    this.bbColors,
    this.bbAlphas,
    this.isMaTrendBackgroundEnabled = false,
    this.maTrendBackgroundColors,
    this.selectedTradingPair,
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

    // グリッド線を描画
    _drawGrid(canvas, size, gridPaint);

    // キャンドルスティックを描画（K線表示が有効な場合のみ）
    if (isKlineVisible) {
    _drawCandlesticks(canvas, size, bullishPaint, bearishPaint, wickPaint);
    }

    // 移動平均線を描画
    _drawMovingAverages(canvas, size);

    // 縦線を描画
    _drawVerticalLines(canvas, size);

    // 価格ラベルを描画
    _drawPriceLabels(canvas, size);

    // 時間ラベルを描画
    _drawTimeLabels(canvas, size);

    // 十字カーソルとラベルを描画
    _drawCrosshairAndLabels(canvas, size);

    // ウェーブポイントを描画
    if (isWavePointsVisible && mergedWavePoints != null) {
      _drawWavePoints(canvas, size);
    }

    // ウェーブポイント接続線を描画
    if (isWavePointsLineVisible && isWavePointsVisible && mergedWavePoints != null) {
      _drawWavePointsLine(canvas, size);
    }

    // 手動高低点を描画
    if (isManualHighLowVisible && manualHighLowPoints != null) {
      _drawManualHighLowPoints(canvas, size);
    }


    // トレンドフィルタリングされた高低点を描画
    if (isTrendFilteringEnabled) {
      // // LogService.instance.debug('CandlestickPainter', 'トレンドフィルタリング描画開始');
      // // LogService.instance.debug('CandlestickPainter', 'filteredWavePoints: ${filteredWavePoints != null ? "存在" : "null"}');
      _drawFilteredWavePoints(canvas);
      _drawTrendLines(canvas);
      _drawSmoothTrendLine(canvas); // 滑らかな折線を描画
      _drawFittedCurve(canvas); // 拟合曲线を描画
      // // LogService.instance.debug('CandlestickPainter', 'トレンドフィルタリング描画完了');
    } else {
      // // LogService.instance.debug('CandlestickPainter', 'トレンドフィルタリング無効、描画スキップ');
    }

    // 3次曲线绘制
    if (isCubicCurveVisible && cubicCurveResult != null) {
      // // LogService.instance.debug('CandlestickPainter', '3次曲线描画開始');
      _drawCubicCurve(canvas);
      // // LogService.instance.debug('CandlestickPainter', '3次曲线描画完了');
    } else {
      // // LogService.instance.debug('CandlestickPainter', '3次曲线無効、描画スキップ');
    }

    // 60均线过滤曲线绘制
    if (isMA60FilteredCurveVisible && ma60FilteredCurveResult != null) {
      // // LogService.instance.debug('CandlestickPainter', '60均线过滤曲线描画開始');
      _drawMA60FilteredCurve(canvas);
      // // LogService.instance.debug('CandlestickPainter', '60均线过滤曲线描画完了');
    } else {
      // // LogService.instance.debug('CandlestickPainter', '60均线过滤曲线無効、描画スキップ');
    }

    // 布林线过滤曲线绘制
    if (isBollingerBandsFilteredCurveVisible && bollingerBandsFilteredCurveResult != null) {
      _drawBollingerBandsFilteredCurve(canvas);
    }

    // 布林通道绘制
    if (isBollingerBandsVisible && bollingerBands != null && bollingerBands!.isNotEmpty) {
      BollingerBandsPainter.drawBollingerBands(
        canvas,
        size,
        data,
        bollingerBands!,
        bbColors ?? {},
        bbAlphas ?? {},
        candleWidth,
        spacing,
        minPrice,
        maxPrice,
        startIndex,
        endIndex,
        chartHeight,
        chartWidth,
        emptySpaceWidth,
      );
    }

    // 保存されたK線選択区域を描画
    _drawSavedKlineSelections(canvas, size);
    
    // 現在の選択区域を描画
    _drawSelectionArea(canvas, size);

    // 性能監視：描画完了時間
    stopwatch.stop();
    // 性能監視：描画時間が長すぎる場合に警告
    if (stopwatch.elapsedMilliseconds > 16) {
      Log.warning('CandlestickPainter', '描画性能警告: ${stopwatch.elapsedMilliseconds}ms (データ量: ${data.length}, 表示K線: ${endIndex - startIndex})');
    }
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

    // 大量データの場合は描画を制限（性能最適化）
    const int maxDrawCandles = 2000; // 最大描画K線数（大幅削減）
    final int effectiveVisibleCandles = visibleCandles > maxDrawCandles
        ? maxDrawCandles
        : visibleCandles;

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
    
    // 性能最適化：早期終了条件を追加
    final double minVisibleX = -candleWidth; // 左側の描画境界
    final double maxVisibleX = candleDrawingWidth + candleWidth; // 右側の描画境界

    for (int i = 0; i < effectiveVisibleCandles; i++) {
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

  void _drawVerticalLines(Canvas canvas, Size size) {
    if (verticalLines == null || verticalLines!.isEmpty) return;

    // 性能監視：縦線描画開始時間
    final stopwatch = Stopwatch()..start();

    int drawnLines = 0;
    for (final VerticalLine verticalLine in verticalLines!) {
      // 使用工具类根据时间戳查找对应的K线索引
      final candleIndex = _findKlineIndexByTimestamp(verticalLine.timestamp);
      
      // 如果找不到对应的K线，跳过
      if (candleIndex == null) {
        Log.debug('CandlestickPainter', '竖线时间戳 ${KlineTimestampUtils.formatTimestamp(verticalLine.timestamp)} 在当前数据中未找到对应K线');
        continue;
      }
      
      // 检查索引是否在显示范围内
      if (candleIndex < startIndex || candleIndex >= endIndex) {
        continue;
      }

      // 統一された座標計算方法を使用し、K線描画と一致することを保証
      final double x = _getCandleXPosition(candleIndex);
      
      // 座標が有効かチェック
      if (x < 0) continue;

      // 色を解析
      Color lineColor;
      try {
        lineColor = Color(int.parse(verticalLine.color.replaceFirst('#', '0xFF')));
      } catch (e) {
        lineColor = Colors.red; // デフォルト色
      }

      // 縦線を描画
      final Paint linePaint = Paint()
        ..color = lineColor
        ..strokeWidth = verticalLine.width
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        linePaint,
      );
      
      drawnLines++;
    }

    stopwatch.stop();
    
    // 性能監視：縦線描画時間が長すぎる場合に警告を発出
    if (stopwatch.elapsedMilliseconds > 5) {
      Log.warning('CandlestickPainter', '⚠️ 縦線描画性能警告: ${stopwatch.elapsedMilliseconds}ms (描画: $drawnLines本, 総数: ${verticalLines!.length}本)');
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
        oldDelegate.verticalLines != verticalLines ||
        oldDelegate.selectionStartX != selectionStartX ||
        oldDelegate.selectionEndX != selectionEndX ||
        oldDelegate.selectedKlineCount != selectedKlineCount ||
        oldDelegate.klineSelections != klineSelections ||
        oldDelegate.mergedWavePoints != mergedWavePoints ||
        oldDelegate.isWavePointsVisible != isWavePointsVisible ||
        oldDelegate.isWavePointsLineVisible != isWavePointsLineVisible ||
        oldDelegate.isKlineVisible != isKlineVisible;
  }

  /// 選択区域を描画
  void _drawSelectionArea(Canvas canvas, Size size) {
    if (selectionStartX == null || selectionEndX == null) return;

    final double startX = selectionStartX!;
    final double endX = selectionEndX!;
    
    // startX <= endXを保証
    final double minX = startX < endX ? startX : endX;
    final double maxX = startX < endX ? endX : startX;

    // 調整後の境界を計算し、最初と最後のK線が矩形区域内に完全に含まれることを保証
    final double adjustedMinX = _getAdjustedSelectionMinX(minX);
    final double adjustedMaxX = _getAdjustedSelectionMaxX(maxX);

    // 半透明選択区域を描画
    final Paint selectionPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTRB(adjustedMinX, 0, adjustedMaxX, size.height),
      selectionPaint,
    );

    // 選択区域ボーダーを描画
    final Paint borderPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
      Rect.fromLTRB(adjustedMinX, 0, adjustedMaxX, size.height),
      borderPaint,
    );

    // K線数がある場合、統計情報を表示
    if (selectedKlineCount > 0) {
      _drawSelectionInfo(canvas, size, adjustedMinX, adjustedMaxX);
    }
  }

  /// 調整後の選択区域最小X座標を計算し、最初のK線が完全に含まれることを保証
  double _getAdjustedSelectionMinX(double minX) {
    // 最初のK線の左境界を計算
    final double candleLeft = minX - (candleWidth / 2);
    return candleLeft;
  }

  /// 調整後の選択区域最大X座標を計算し、最後のK線が完全に含まれることを保証
  double _getAdjustedSelectionMaxX(double maxX) {
    // 最後のK線の右境界を計算
    final double candleRight = maxX + (candleWidth / 2);
    return candleRight;
  }

  /// 選択区域情報を描画
  void _drawSelectionInfo(Canvas canvas, Size size, double minX, double maxX) {
    final String infoText = '選択されたK線: $selectedKlineCount 本';
    
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: infoText,
        style: TextStyle(
          color: Colors.blue,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white.withValues(alpha: 0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // 選択区域の上に情報を表示
    final double textX = (minX + maxX) / 2 - textPainter.width / 2;
    final double textY = 20.0;
    
    // 背景を描画
    final Paint backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(
      Rect.fromLTWH(
        textX - 4, 
        textY - 2, 
        textPainter.width + 8, 
        textPainter.height + 4
      ),
      backgroundPaint,
    );
    
    // 文字を描画
    textPainter.paint(canvas, Offset(textX, textY));
  }

  /// 保存されたK線選択区域を描画
  void _drawSavedKlineSelections(Canvas canvas, Size size) {
    if (klineSelections == null || klineSelections!.isEmpty) return;

    for (final selection in klineSelections!) {
      // 使用工具类根据时间戳查找对应的K线索引
      final startCandleIndex = _findKlineIndexByTimestamp(selection.startTimestamp);
      final endCandleIndex = _findKlineIndexByTimestamp(selection.endTimestamp);
      
      // 如果找不到对应的K线，跳过
      if (startCandleIndex == null || endCandleIndex == null) {
        Log.debug('CandlestickPainter', 'K线选择区域时间戳范围 ${KlineTimestampUtils.formatTimestamp(selection.startTimestamp)} - ${KlineTimestampUtils.formatTimestamp(selection.endTimestamp)} 在当前数据中未找到对应K线');
        continue;
      }
      
      // 检查索引是否在显示范围内
      if (startCandleIndex < startIndex || endCandleIndex >= endIndex) {
        continue;
      }

      // 選択区域の画面上での位置を計算
      final double startX = _getCandleXPosition(startCandleIndex);
      final double endX = _getCandleXPosition(endCandleIndex);
      
      // 境界を調整して、最初と最後のK線を完全に含める
      final double adjustedStartX = _getAdjustedSelectionMinX(startX);
      final double adjustedEndX = _getAdjustedSelectionMaxX(endX);

      // 半透明選択区域を描画
      final Paint selectionPaint = Paint()
        ..color = _parseColor(selection.color).withValues(alpha: selection.opacity)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTRB(adjustedStartX, 0, adjustedEndX, size.height),
        selectionPaint,
      );

      // 選択区域の境界線を描画
      final Paint borderPaint = Paint()
        ..color = _parseColor(selection.color)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawRect(
        Rect.fromLTRB(adjustedStartX, 0, adjustedEndX, size.height),
        borderPaint,
      );

      // 選択区域情報を描画
      _drawSavedSelectionInfo(canvas, size, adjustedStartX, adjustedEndX, selection);
    }
  }

  /// 保存された選択区域情報を描画
  void _drawSavedSelectionInfo(Canvas canvas, Size size, double minX, double maxX, KlineSelection selection) {
    final String infoText = 'K線: ${selection.klineCount} 本';
    
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: infoText,
        style: TextStyle(
          color: _parseColor(selection.color),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white.withValues(alpha: 0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // 選択区域の上に情報を表示
    final double textX = (minX + maxX) / 2 - textPainter.width / 2;
    final double textY = 10.0;
    
    // 背景を描画
    final Paint backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(
      Rect.fromLTWH(
        textX - 4, 
        textY - 2, 
        textPainter.width + 8, 
        textPainter.height + 4
      ),
      backgroundPaint,
    );
    
    // 文字を描画
    textPainter.paint(canvas, Offset(textX, textY));
  }

  /// 色文字列を解析
  Color _parseColor(String colorString) {
    try {
      // #記号を削除してColorに変換
      final String hexColor = colorString.replaceAll('#', '');
      return Color(int.parse('FF$hexColor', radix: 16));
    } catch (e) {
      return Colors.blue; // デフォルト色
    }
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

  /// ウェーブポイントを描画
  void _drawWavePoints(Canvas canvas, Size size) {
    final Paint highPointBorderPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final Paint lowPointBorderPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    for (final point in mergedWavePoints!) {
      final int index = point['index'] as int;
      if (index < startIndex || index >= endIndex) continue;

      final double x = _getCandleXPosition(index);
      if (x < 0) continue;

      final double y = _priceToY(point['value'] as double, size.height);
      final String type = point['type'] as String;

      final Paint paint = type == 'high' ? highPointBorderPaint : lowPointBorderPaint;

      // マーカーを描画（正方形）
      final double pointSize = 8.0;
      final Rect squareRect = Rect.fromCenter(
        center: Offset(x, y),
        width: pointSize * 2,
        height: pointSize * 2,
      );

      canvas.drawRect(squareRect, paint);
    }
  }

  /// ウェーブポイント接続線を描画
  void _drawWavePointsLine(Canvas canvas, Size size) {
    // 最適化：事前にソートとマージされたmergedWavePointsリストを直接使用
    final allWavePoints = mergedWavePoints!;
    if (allWavePoints.length < 2) return;

    // 接続線を描画
    final Paint linePaint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // 最適化：二分探索を使用して描画開始点を高速で特定し、全リストスキャンを回避
    int firstVisiblePointIndex = _findFirstPointIndex(allWavePoints, startIndex);

    // すべてのポイントが画面左側にある場合、描画不要
    if (firstVisiblePointIndex == -1) {
      if (allWavePoints.isNotEmpty && (allWavePoints.last['index'] as int) < startIndex) {
        return;
      }
      firstVisiblePointIndex = 0; // そうでなければ、最初からチェック
    }

    // 描画開始ポイントインデックスを決定（画面外の左側隣接ポイントを含む）
    int startDrawingIndex = (firstVisiblePointIndex > 0) ? firstVisiblePointIndex - 1 : 0;

    // 線分をループ描画
    for (int i = startDrawingIndex; i < allWavePoints.length - 1; i++) {
      final currentPoint = allWavePoints[i];
      final nextPoint = allWavePoints[i + 1];

      final int currentIndex = currentPoint['index'] as int;
      final int nextIndex = nextPoint['index'] as int;

      // 最適化：現在の点が画面の右側をはるかに超えている場合は、ループを早期に終了できます
      if (currentIndex > endIndex) {
        break;
      }

      // 現在のポイントの位置を計算
      double x1 = _getCandleXPosition(currentIndex);
      double y1 = _priceToY(currentPoint['value'] as double, size.height);

      // 次のポイントの位置を計算
      double x2 = _getCandleXPosition(nextIndex);
      double y2 = _priceToY(nextPoint['value'] as double, size.height);

      // FlutterのCanvasは画面外の描画クリッピングを自動処理するため、直接線を描画
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
    }
  }

  /// 二分探索で、最初の可視ウェーブポイントのリスト内インデックスを見つける
  int _findFirstPointIndex(List<Map<String, dynamic>> points, int startVisibleIndex) {
    int low = 0;
    int high = points.length - 1;
    int result = -1;

    while (low <= high) {
      int mid = low + ((high - low) >> 1);
      if ((points[mid]['index'] as int) >= startVisibleIndex) {
        result = mid;
        high = mid - 1; // より早い（より左の）マッチ項目を見つけようとする
      } else {
        low = mid + 1;
      }
    }
    return result;
  }

  /// 手動高低点を描画
  void _drawManualHighLowPoints(Canvas canvas, Size size) {
    if (manualHighLowPoints == null || manualHighLowPoints!.isEmpty) return;
    final pair = selectedTradingPair ?? TradingPair.eurusd;

    // 性能監視：手動高低点描画開始時間
    final stopwatch = Stopwatch()..start();

    int drawnPoints = 0;
    for (final point in manualHighLowPoints!) {
      // 使用工具类根据时间戳查找对应的K线索引
      final candleIndex = _findKlineIndexByTimestamp(point.timestamp);
      
      // 如果找不到对应的K线，跳过
      if (candleIndex == null) {
        Log.debug('CandlestickPainter', '手動高低点時間戳 ${KlineTimestampUtils.formatTimestamp(point.timestamp)} 在当前数据中未找到对应K线');
        continue;
      }
      
      // 检查索引是否在显示范围内
      if (candleIndex < startIndex || candleIndex >= endIndex) {
        continue;
      }

      // 計算高低点の画面上での位置
      final double x = _getCandleXPosition(candleIndex);
      final double y = _priceToY(point.price, chartHeight);
      
      // 座標が有効かチェック
      if (x < 0 || x > chartWidth || y < 0 || y > chartHeight) {
        continue;
      }

      // 高低点の描画スタイルを設定
      final Paint pointPaint = Paint()
        ..color = point.isHigh ? Colors.orange : Colors.blue
        ..style = PaintingStyle.fill;

      final Paint borderPaint = Paint()
        ..color = point.isHigh ? Colors.red : Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      // 高低点を描画（三角形）
      final Path trianglePath = Path();
      const double triangleSize = 8.0;
      
      if (point.isHigh) {
        // 高値：上向き三角形
        trianglePath.moveTo(x, y - triangleSize);
        trianglePath.lineTo(x - triangleSize, y + triangleSize);
        trianglePath.lineTo(x + triangleSize, y + triangleSize);
        trianglePath.close();
      } else {
        // 安値：下向き三角形
        trianglePath.moveTo(x, y + triangleSize);
        trianglePath.lineTo(x - triangleSize, y - triangleSize);
        trianglePath.lineTo(x + triangleSize, y - triangleSize);
        trianglePath.close();
      }

      // 三角形を描画
      canvas.drawPath(trianglePath, pointPaint);
      canvas.drawPath(trianglePath, borderPaint);

      // 価格ラベルを描画
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: pair.formatPrice(point.price),
          style: TextStyle(
            color: point.isHigh ? Colors.red : Colors.green,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      // ラベルの位置を調整（高低点の近くに配置）
      double labelX = x - textPainter.width / 2;
      double labelY = point.isHigh ? y - triangleSize - textPainter.height - 2 : y + triangleSize + 2;
      
      // ラベルが画面外に出ないように調整
      labelX = labelX.clamp(0, chartWidth - textPainter.width);
      labelY = labelY.clamp(textPainter.height, chartHeight);
      
      textPainter.paint(canvas, Offset(labelX, labelY));

      drawnPoints++;
    }

    // パフォーマンス監視: 手動による最高点と最低点の描画完了時間
    stopwatch.stop();
    if (stopwatch.elapsedMilliseconds > 5) {
      Log.debug('CandlestickPainter', '手動高低点描画時間: ${stopwatch.elapsedMilliseconds}ms, 描画点数: $drawnPoints');
    }
  }




  /// タイムスタンプでK線インデックスを検索（バイナリサーチで最適化）
  ///
  /// @param timestamp 検索するタイムスタンプ
  /// @return K線インデックス。見つからない場合はnull
  int? _findKlineIndexByTimestamp(int timestamp) {
    if (data.isEmpty) {
      return null;
    }

    int low = 0;
    int high = data.length - 1;
    int? result;

    while (low <= high) {
      int mid = low + ((high - low) >> 1);
      final midTimestamp = data[mid].timestamp;

      if (midTimestamp == timestamp) {
        return mid; // 完全一致
      } else if (midTimestamp < timestamp) {
        result = mid; // 候補として保存
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    
    // `result`には、対象のタイムスタンプ以下の最後の要素のインデックスが保持されます。
    // これは、補間された点がどのK線に属するかを決定するための正しい動作です。
    return result;
  }


  /// フィルタリングされた高低点を描画
  void _drawFilteredWavePoints(Canvas canvas) {
    // LogService.instance.debug('CandlestickPainter', '_drawFilteredWavePoints開始');
    
    if (!isTrendFilteringEnabled || filteredWavePoints == null) {
      // LogService.instance.debug('CandlestickPainter', 'フィルタリング条件未満足、描画スキップ');
      return;
    }

    final filteredHighPoints = filteredWavePoints!.filteredHighPoints;
    final filteredLowPoints = filteredWavePoints!.filteredLowPoints;
    final originalPoints = filteredWavePoints!.originalPoints;
    
    // LogService.instance.debug('CandlestickPainter', '元のピボット候補: ${originalPoints.length}個');
    // LogService.instance.debug('CandlestickPainter', 'フィルタリングされた高値点: ${filteredHighPoints.length}個');
    // LogService.instance.debug('CandlestickPainter', 'フィルタリングされた低値点: ${filteredLowPoints.length}個');

    // 1. 元のピボット候補を薄い点で表示（参考用）
    for (final point in originalPoints) {
      final index = point['index'] as int;
      if (index < startIndex || index > endIndex) continue;

      final x = _getCandleXPosition(index);
      final y = _priceToY(point['value'] as double, chartHeight);
      final pointType = point['type'] as String;

      // 元のピボット候補は薄い色で小さく表示
      final paint = Paint()
        ..color = pointType == 'high' 
          ? Colors.green.withValues(alpha: 0.3)
          : Colors.red.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), 3, paint);
    }

    // 2. フィルタリングされた高値点を描画（有効ポイント）
    for (final point in filteredHighPoints) {
      final index = point['index'] as int;
      if (index < startIndex || index > endIndex) continue;

      final x = _getCandleXPosition(index);
      final y = _priceToY(point['value'] as double, chartHeight);

      // フィルタリングされた高値点は緑色の大きな円で描画
      final paint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), 6, paint);

      // 外側に白い枠線
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawCircle(Offset(x, y), 6, borderPaint);
    }

    // 3. フィルタリングされた低値点を描画（有効ポイント）
    for (final point in filteredLowPoints) {
      final index = point['index'] as int;
      if (index < startIndex || index > endIndex) continue;

      final x = _getCandleXPosition(index);
      final y = _priceToY(point['value'] as double, chartHeight);

      // フィルタリングされた低値点は赤色の大きな円で描画
    final paint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), 6, paint);

      // 外側に白い枠線
      final borderPaint = Paint()
        ..color = Colors.white
      ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawCircle(Offset(x, y), 6, borderPaint);
    }

    // 4. 有効ポイント同士を折れ線で連結（スイングライン）
    _drawSwingLines(canvas, filteredHighPoints, filteredLowPoints);
    
    // LogService.instance.debug('CandlestickPainter', '_drawFilteredWavePoints完了');
  }

  /// スイングライン（有効ポイント同士の折れ線）を描画
  void _drawSwingLines(Canvas canvas, List<Map<String, dynamic>> highPoints, List<Map<String, dynamic>> lowPoints) {
    // すべてのポイントを時系列順にマージ
    final List<Map<String, dynamic>> allPoints = [];
    allPoints.addAll(highPoints);
    allPoints.addAll(lowPoints);
    
    if (allPoints.length < 2) return;
    
    // インデックス順にソート
    allPoints.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
    
    // スイングラインを描画
    final Paint swingLinePaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    for (int i = 0; i < allPoints.length - 1; i++) {
      final currentPoint = allPoints[i];
      final nextPoint = allPoints[i + 1];
      
      final currentIndex = currentPoint['index'] as int;
      final nextIndex = nextPoint['index'] as int;
      
      // 表示範囲外の場合はスキップ
      if (currentIndex < startIndex || nextIndex > endIndex) continue;
      
      final x1 = _getCandleXPosition(currentIndex);
      final y1 = _priceToY(currentPoint['value'] as double, chartHeight);
      final x2 = _getCandleXPosition(nextIndex);
      final y2 = _priceToY(nextPoint['value'] as double, chartHeight);
      
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), swingLinePaint);
    }
  }

  /// トレンドラインを描画
  void _drawTrendLines(Canvas canvas) {
    // LogService.instance.debug('CandlestickPainter', '_drawTrendLines開始');
    
    if (!isTrendFilteringEnabled || filteredWavePoints == null) {
      // LogService.instance.debug('CandlestickPainter', 'トレンドライン描画条件未満足、描画スキップ');
      return;
    }

    final trendLines = filteredWavePoints!.trendLines;
    // LogService.instance.debug('CandlestickPainter', 'トレンドライン数: ${trendLines.length}本');
    
    if (trendLines.isEmpty) {
      // LogService.instance.warning('CandlestickPainter', 'トレンドラインが生成されていません！');
      // 临时：绘制测试趋势线
      _drawTestTrendLine(canvas);
      return;
    }
    
    for (final trendLine in trendLines) {
      // トレンドラインの強度に応じて色を決定
      Color lineColor;
      double lineWidth;
      
      switch (trendLine.strengthLevel) {
        case 'strong':
          lineColor = trendLine.type == 'high' ? Colors.green : Colors.red;
          lineWidth = 3.0;
        break;
        case 'moderate':
          lineColor = trendLine.type == 'high' ? Colors.green.shade300 : Colors.red.shade300;
          lineWidth = 2.5;
          break;
        case 'weak':
          lineColor = trendLine.type == 'high' ? Colors.green.shade200 : Colors.red.shade200;
          lineWidth = 2.0;
          break;
        default:
          lineColor = trendLine.type == 'high' ? Colors.green.shade100 : Colors.red.shade100;
          lineWidth = 1.5;
      }

      // トレンドラインの開始点と終了点が表示範囲内かチェック
      if (trendLine.startIndex > endIndex || trendLine.endIndex < startIndex) continue;

      final startX = _getCandleXPosition(trendLine.startIndex);
      final endX = _getCandleXPosition(trendLine.endIndex);
      final startY = _priceToY(trendLine.startValue, chartHeight);
      final endY = _priceToY(trendLine.endValue, chartHeight);

      final paint = Paint()
        ..color = lineColor
        ..strokeWidth = lineWidth
        ..style = PaintingStyle.stroke;

      // トレンドラインを描画
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);

      // トレンドラインの方向を示す矢印を描画
      _drawTrendArrow(canvas, Offset(endX, endY), trendLine.direction, lineColor);
    }
    
    // LogService.instance.debug('CandlestickPainter', '_drawTrendLines完了');
  }

  /// トレンドラインの方向矢印を描画
  void _drawTrendArrow(Canvas canvas, Offset position, String direction, Color color) {
    if (direction == 'horizontal') return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const double arrowSize = 8.0;
    final Path arrowPath = Path();

    if (direction == 'upward') {
      // 上向き矢印
      arrowPath.moveTo(position.dx, position.dy - arrowSize);
      arrowPath.lineTo(position.dx - arrowSize / 2, position.dy);
      arrowPath.lineTo(position.dx + arrowSize / 2, position.dy);
      arrowPath.close();
    } else if (direction == 'downward') {
      // 下向き矢印
      arrowPath.moveTo(position.dx, position.dy + arrowSize);
      arrowPath.lineTo(position.dx - arrowSize / 2, position.dy);
      arrowPath.lineTo(position.dx + arrowSize / 2, position.dy);
      arrowPath.close();
    }

    canvas.drawPath(arrowPath, paint);
  }

  /// 滑らかな折線を描画（150均線に沿った黄色の折線）
  void _drawSmoothTrendLine(Canvas canvas) {
    if (filteredWavePoints?.smoothTrendLine == null) {
      // LogService.instance.warning('CandlestickPainter', '滑らかな折線データが存在しません！filteredWavePoints=${filteredWavePoints != null ? "存在" : "null"}');
      return;
    }

    final smoothTrendLine = filteredWavePoints!.smoothTrendLine!;
    final points = smoothTrendLine.points;
    
    if (points.length < 2) {
      // LogService.instance.debug('CandlestickPainter', '滑らかな折線の点が不足: ${points.length}個');
      return;
    }

    // LogService.instance.debug('CandlestickPainter', '滑らかな折線描画開始: ${points.length}個の点');

    // 黄色の太い線で描画（より目立つ色に変更）
    final paint = Paint()
      ..color = Colors.orange // オレンジ色に変更してより目立つように
      ..strokeWidth = 4.0     // 線を太くしてより見やすく
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    bool isFirstPoint = true;
    int drawnPoints = 0;

    // LogService.instance.debug('CandlestickPainter', '描画範囲: startIndex=$startIndex, endIndex=$endIndex');

    for (final point in points) {
      final index = point['index'] as int;
      // // LogService.instance.debug('CandlestickPainter', '平滑折线点: index=$index, startIndex=$startIndex, endIndex=$endIndex');
      // 移除索引范围限制，让平滑折线始终显示
      // if (index < startIndex || index >= endIndex) {
      //   skippedPoints++;
      //   // LogService.instance.debug('CandlestickPainter', '平滑折线点跳过: index=$index 超出范围');
      //   continue;
      // }

      final x = _getCandleXPosition(index);
      if (x < 0) {
        continue;
      }
      
      final y = _priceToY(point['value'] as double, chartHeight);
      final position = Offset(x, y);

      if (isFirstPoint) {
        path.moveTo(position.dx, position.dy);
        isFirstPoint = false;
        // LogService.instance.debug('CandlestickPainter', '最初の点: index=$index, x=$x, y=$y');
      } else {
        path.lineTo(position.dx, position.dy);
      }
      drawnPoints++;
    }

    // LogService.instance.debug('CandlestickPainter', '描画統計: 描画点=$drawnPoints個, スキップ点=$skippedPoints個');

    if (drawnPoints > 0) {
    canvas.drawPath(path, paint);
      // LogService.instance.debug('CandlestickPainter', '滑らかな折線描画完了: $drawnPoints個の点を描画');
    } else {
      // LogService.instance.debug('CandlestickPainter', '滑らかな折線描画スキップ: 描画可能な点がありません');
    }
  }

  /// 拟合曲线を描画（青色の滑らかな曲線）
  void _drawFittedCurve(Canvas canvas) {
    if (filteredWavePoints?.fittedCurve.isEmpty ?? true) {
      // LogService.instance.warning('CandlestickPainter', '拟合曲线データが存在しません！fittedCurve=${filteredWavePoints?.fittedCurve.length ?? 0}個');
      return;
    }

    final fittedCurve = filteredWavePoints!.fittedCurve;
    
    if (fittedCurve.length < 2) {
      // LogService.instance.debug('CandlestickPainter', '拟合曲线の点が不足: ${fittedCurve.length}個');
      return;
    }

    // LogService.instance.debug('CandlestickPainter', '拟合曲线描画開始: ${fittedCurve.length}個の点');

    // 青色の滑らかな曲線で描画
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    bool isFirstPoint = true;
    int drawnPoints = 0;

    // LogService.instance.debug('CandlestickPainter', '拟合曲线描画範囲: startIndex=$startIndex, endIndex=$endIndex');

    for (final point in fittedCurve) {
      final index = point['index'] as int;
      // // LogService.instance.debug('CandlestickPainter', '拟合曲线点: index=$index, startIndex=$startIndex, endIndex=$endIndex');
      // 移除索引范围限制，让拟合曲线始终显示
      // if (index < startIndex || index >= endIndex) {
      //   skippedPoints++;
      //   // LogService.instance.debug('CandlestickPainter', '拟合曲线点跳过: index=$index 超出范围');
      //   continue;
      // }

      final x = _getCandleXPosition(index);
      if (x < 0) {
        continue;
      }

      final y = _priceToY(point['value'] as double, chartHeight);
      final position = Offset(x, y);

      if (isFirstPoint) {
        path.moveTo(position.dx, position.dy);
        isFirstPoint = false;
        // LogService.instance.debug('CandlestickPainter', '拟合曲线最初の点: index=$index, x=$x, y=$y');
      } else {
        path.lineTo(position.dx, position.dy);
      }
      drawnPoints++;
    }

    // LogService.instance.debug('CandlestickPainter', '拟合曲线描画統計: 描画点=$drawnPoints個, スキップ点=$skippedPoints個');

    if (drawnPoints > 0) {
      canvas.drawPath(path, paint);
      // LogService.instance.debug('CandlestickPainter', '拟合曲线描画完了: $drawnPoints個の点を描画');
      } else {
      // LogService.instance.debug('CandlestickPainter', '拟合曲线描画スキップ: 描画可能な点がありません');
    }
  }

  /// 测试趋势线绘制（临时方法）
  void _drawTestTrendLine(Canvas canvas) {
    // LogService.instance.info('CandlestickPainter', '绘制测试趋势线');
    
    final paint = Paint()
      ..color = Colors.purple
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    
    // 绘制一条从左上到右下的测试线
    final startX = 100.0;
    final startY = 100.0;
    final endX = chartWidth - 100.0;
    final endY = chartHeight - 100.0;
    
    canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
  }

  /// 3次曲线绘制
  void _drawCubicCurve(Canvas canvas) {
    if (cubicCurveResult == null || cubicCurveResult!.points.isEmpty) {
      // LogService.instance.debug('CandlestickPainter', '3次曲线数据为空，跳过绘制');
      return;
    }

    final points = cubicCurveResult!.points;
    // LogService.instance.debug('CandlestickPainter', '3次曲线绘制开始: ${points.length}个点, R²=${cubicCurveResult!.rSquared.toStringAsFixed(4)}');

    // 紫色曲线绘制
    final paint = Paint()
      ..color = Colors.purple
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    bool isFirstPoint = true;
    int drawnPoints = 0;

    for (final point in points) {
      final x = _getCandleXPosition(point.index);
      if (x < 0) {
        continue;
      }

      final y = _priceToY(point.value, chartHeight);
      final position = Offset(x, y);

      if (isFirstPoint) {
        path.moveTo(position.dx, position.dy);
        isFirstPoint = false;
      } else {
        path.lineTo(position.dx, position.dy);
      }
      drawnPoints++;
    }

    if (drawnPoints > 0) {
      canvas.drawPath(path, paint);
      // LogService.instance.debug('CandlestickPainter', '3次曲线绘制完成: $drawnPoints个点, 跳过$skippedPoints个点');
    } else {
      // LogService.instance.debug('CandlestickPainter', '3次曲线绘制跳过: 没有可绘制的点');
    }
  }

  /// 60均线过滤曲线绘制
  void _drawMA60FilteredCurve(Canvas canvas) {
    if (ma60FilteredCurveResult == null || ma60FilteredCurveResult!.points.isEmpty) {
      // LogService.instance.debug('CandlestickPainter', '60均线过滤曲线数据为空，跳过绘制');
      return;
    }

    final points = ma60FilteredCurveResult!.points;
    // LogService.instance.debug('CandlestickPainter', '60均线过滤曲线绘制开始: ${points.length}个点');

    // 青色曲线绘制
    final paint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    bool isFirstPoint = true;
    int drawnPoints = 0;

    for (final point in points) {
      final x = _getCandleXPosition(point.index);
      if (x < 0) {
        continue;
      }

      final y = _priceToY(point.value, chartHeight);
      final position = Offset(x, y);

      if (isFirstPoint) {
        path.moveTo(position.dx, position.dy);
        isFirstPoint = false;
      } else {
        path.lineTo(position.dx, position.dy);
      }
      drawnPoints++;
    }

    if (drawnPoints > 0) {
      canvas.drawPath(path, paint);
      // LogService.instance.debug('CandlestickPainter', '60均线过滤曲线绘制完成: $drawnPoints个点, 跳过$skippedPoints个点');
    } else {
      // LogService.instance.debug('CandlestickPainter', '60均线过滤曲线绘制跳过: 没有可绘制的点');
    }
  }

  /// 布林线过滤曲线绘制
  void _drawBollingerBandsFilteredCurve(Canvas canvas) {
    if (bollingerBandsFilteredCurveResult == null || bollingerBandsFilteredCurveResult!.points.isEmpty) {
      return;
    }

    final points = bollingerBandsFilteredCurveResult!.points;

    // 紫色曲线绘制
    final linePaint = Paint()
      ..color = Colors.purple
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    bool isFirstPoint = true;
    int drawnPoints = 0;

    // 先绘制连接线
    for (final point in points) {
      final x = _getCandleXPosition(point['index']);
      if (x < 0) {
        continue;
      }

      final y = _priceToY(point['value'], chartHeight);
      final position = Offset(x, y);

      if (isFirstPoint) {
        path.moveTo(position.dx, position.dy);
        isFirstPoint = false;
      } else {
        path.lineTo(position.dx, position.dy);
      }
      drawnPoints++;
    }

    if (drawnPoints > 0) {
      canvas.drawPath(path, linePaint);
    }

    // 绘制实心填充的高低点
    for (final point in points) {
      final x = _getCandleXPosition(point['index']);
      if (x < 0) {
        continue;
      }

      final y = _priceToY(point['value'], chartHeight);
      final position = Offset(x, y);

      // 根据点的类型选择颜色
      final pointType = point['originalType'] as String?;
      Color fillColor;
      
      if (pointType == 'high') {
        fillColor = Colors.red; // 高点用红色
      } else if (pointType == 'low') {
        fillColor = Colors.green; // 低点用绿色
      } else {
        fillColor = Colors.purple; // 默认用紫色
      }

      // 绘制实心圆点
      final dotPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill;

      canvas.drawCircle(position, 4.0, dotPaint);

      // 绘制白色边框
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawCircle(position, 4.0, borderPaint);
    }
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
