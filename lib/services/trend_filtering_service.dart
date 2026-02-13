import 'dart:math';
import '../models/wave_points.dart';
import '../models/wave_point.dart';
import '../models/price_data.dart';
import 'log_service.dart';
import 'curve_fitting_service.dart';

/// トレンドフィルタリングサービス
/// 150均線を基準に高低点をフィルタリングして、トレンドラインを明確にする
class TrendFilteringService {
  static final TrendFilteringService _instance = TrendFilteringService._internal();
  factory TrendFilteringService() => _instance;
  TrendFilteringService._internal();

  static TrendFilteringService get instance => _instance;

  /// 150均線を基準に高低点をフィルタリング（最適化版）
  /// 
  /// [wavePoints] 元の高低点データ
  /// [priceDataList] 価格データリスト
  /// [ma150Series] 150均線データ
  /// [nearThreshold] 近い距離の閾値（デフォルト: 0.5%）
  /// [farThreshold] 遠い距離の閾値（デフォルト: 1.5%）
  /// [minGapBars] 最低バー間隔（デフォルト: 3）
  /// 
  /// 戻り値: フィルタリングされた高低点データ
  FilteredWavePoints filterByMA150(
    WavePoints wavePoints,
    List<PriceData> priceDataList,
    List<double?> ma150Series, {
    double nearThreshold = 0.005, // 0.5% - より厳密に
    double farThreshold = 0.015,  // 1.5% - より厳密に
    int minGapBars = 3,           // より密な点を許可
  }) {
    final stopwatch = Stopwatch()..start();
    
    LogService.instance.debug('TrendFilteringService', '150均線フィルタリング開始: ${wavePoints.mergedPoints.length}個の点');

    if (wavePoints.mergedPoints.isEmpty || ma150Series.isEmpty) {
      LogService.instance.warning('TrendFilteringService', 'データが空のため、フィルタリングをスキップ');
      return FilteredWavePoints(
        filteredHighPoints: [],
        filteredLowPoints: [],
        trendLines: [],
        originalPoints: wavePoints.mergedPoints,
      );
    }

    final List<Map<String, dynamic>> filteredHighPoints = [];
    final List<Map<String, dynamic>> filteredLowPoints = [];
    final List<TrendLine> trendLines = [];

    // 1. SMA150の傾きを計算（トレンド方向の判定）
    final trendDirection = _calculateTrendDirection(ma150Series);
    LogService.instance.debug('TrendFilteringService', 'トレンド方向: $trendDirection');

    // 2. ピボット高値/安値を検出
    final pivotPoints = _detectPivotPoints(priceDataList, ma150Series);
    LogService.instance.debug('TrendFilteringService', 'ピボットポイント検出: ${pivotPoints.length}個');

    // 3. 各ピボットポイントを150均線の傾きに基づいてフィルタリング
    for (final point in pivotPoints) {
      final index = point['index'] as int;
      if (index >= ma150Series.length) continue;

      final ma150Value = ma150Series[index];
      if (ma150Value == null) continue;

      final pointValue = point['value'] as double;
      final pointType = point['type'] as String;

      // 150均線からの距離を計算（パーセンテージ）
      final distance = (pointValue - ma150Value).abs() / ma150Value;

      // 改良されたフィルタリングロジック：150均線に近い点を優先
      bool isValidPoint = false;
      
      // 基本的な距離チェック：150均線から近すぎず遠すぎない点を選択
      if (distance >= nearThreshold && distance <= farThreshold) {
        isValidPoint = true;
      }
      
      // トレンド方向に基づく追加フィルタリング
      if (trendDirection == 'upward') {
        // 上昇トレンド：高値は150均線より上、安値は150均線より下または近い
        if (pointType == 'high' && pointValue > ma150Value) {
          isValidPoint = true;
        } else if (pointType == 'low' && (pointValue < ma150Value || distance <= nearThreshold * 1.5)) {
          isValidPoint = true;
        }
      } else if (trendDirection == 'downward') {
        // 下降トレンド：高値は150均線より上または近い、安値は150均線より下
        if (pointType == 'high' && (pointValue > ma150Value || distance <= nearThreshold * 1.5)) {
          isValidPoint = true;
        } else if (pointType == 'low' && pointValue < ma150Value) {
          isValidPoint = true;
        }
      }
      
      // 横ばいトレンド：150均線の上下にバランスよく分布する点を選択
      if (trendDirection == 'horizontal') {
        // 150均線から適度な距離にある点を選択
        if (distance >= nearThreshold && distance <= farThreshold) {
          isValidPoint = true;
        }
      }

      if (!isValidPoint) {
        // LogService.instance.debug('TrendFilteringService', 
          // '点を除外: インデックス$index, 価格$pointValue, MA150$ma150Value, 距離${(distance * 100).toStringAsFixed(2)}%, トレンド$trendDirection');
        continue;
      }

      // フィルタリングされた点を分類
      if (pointType == 'high') {
        filteredHighPoints.add(point);
      } else {
        filteredLowPoints.add(point);
      }
    }

    // 4. ノイズ抑制と交互性維持
    final cleanedHighPoints = _removeNoiseAndMaintainAlternation(filteredHighPoints, minGapBars);
    final cleanedLowPoints = _removeNoiseAndMaintainAlternation(filteredLowPoints, minGapBars);

    // 5. トレンドラインを生成
    final highTrendLines = _generateTrendLines(cleanedHighPoints, priceDataList, 'high');
    final lowTrendLines = _generateTrendLines(cleanedLowPoints, priceDataList, 'low');

    trendLines.addAll(highTrendLines);
    trendLines.addAll(lowTrendLines);

    stopwatch.stop();
    LogService.instance.info('TrendFilteringService', 
      '150均線フィルタリング完了: 元${wavePoints.mergedPoints.length}個 → ピボット${pivotPoints.length}個 → 高${cleanedHighPoints.length}個 + 低${cleanedLowPoints.length}個, トレンドライン${trendLines.length}本 (${stopwatch.elapsedMilliseconds}ms)');

    // 6. 150均線に沿った滑らかな折線を生成
    LogService.instance.debug('TrendFilteringService', '滑らかな折線生成開始: 高${cleanedHighPoints.length}個, 低${cleanedLowPoints.length}個');
    final smoothTrendLine = _generateSmoothTrendLineAroundMA150(
      cleanedHighPoints, 
      cleanedLowPoints, 
      ma150Series, 
      priceDataList
    );
    LogService.instance.debug('TrendFilteringService', '滑らかな折線生成結果: ${smoothTrendLine != null ? "成功" : "失敗"}');

    // 7. 生成拟合曲线
    LogService.instance.debug('TrendFilteringService', '拟合曲线生成开始');
    final allFilteredPoints = <WavePoint>[];
    allFilteredPoints.addAll(cleanedHighPoints.map((p) => WavePoint(
      timestamp: p['timestamp'] as int, // timestamp已经是int类型
      price: p['value'] as double,
      type: 'high',
      index: p['index'] as int,
    )));
    allFilteredPoints.addAll(cleanedLowPoints.map((p) => WavePoint(
      timestamp: p['timestamp'] as int, // timestamp已经是int类型
      price: p['value'] as double,
      type: 'low',
      index: p['index'] as int,
    )));
    
    final fittedCurve = CurveFittingService.instance.generateMovingAverageFittedCurve(
      wavePoints: allFilteredPoints,
      priceDataList: priceDataList,
      windowSize: 20,
      smoothingFactor: 0.3,
    );
    LogService.instance.debug('TrendFilteringService', '拟合曲线生成完成: ${fittedCurve.length}个点');

    return FilteredWavePoints(
      filteredHighPoints: cleanedHighPoints,
      filteredLowPoints: cleanedLowPoints,
      trendLines: trendLines,
      originalPoints: pivotPoints, // 元のピボットポイントを返す
      smoothTrendLine: smoothTrendLine, // 滑らかな折線を追加
      fittedCurve: fittedCurve, // 拟合曲线
    );
  }

  /// トレンドラインを生成
  List<TrendLine> _generateTrendLines(
    List<Map<String, dynamic>> points,
    List<PriceData> priceDataList,
    String type,
  ) {
    if (points.length < 2) return [];

    final List<TrendLine> trendLines = [];
    
    // 時系列順にソート
    points.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));

    // 連続する3点以上でトレンドラインを生成
    for (int i = 0; i < points.length - 2; i++) {
      final List<Map<String, dynamic>> trendPoints = [points[i]];
      
      // 次の点を探す
      for (int j = i + 1; j < points.length; j++) {
        final currentPoint = points[j];
        
        // トレンドの方向性をチェック
        if (_isValidTrendPoint(trendPoints, currentPoint, type)) {
          trendPoints.add(currentPoint);
        }
      }

      // 3点以上の場合、トレンドラインを生成
      if (trendPoints.length >= 3) {
        final trendLine = _createTrendLine(trendPoints, priceDataList, type);
        if (trendLine != null) {
          trendLines.add(trendLine);
        }
      }
    }

    return trendLines;
  }

  /// トレンドポイントが有効かチェック
  bool _isValidTrendPoint(
    List<Map<String, dynamic>> existingPoints,
    Map<String, dynamic> newPoint,
    String type,
  ) {
      if (existingPoints.length < 2) return true;

      final secondLastPoint = existingPoints[existingPoints.length - 2];
    
    // トレンドの方向性をチェック
    final lastPoint = existingPoints.last;
    final lastValue = lastPoint['value'] as double;
    final secondLastValue = secondLastPoint['value'] as double;
    final newValue = newPoint['value'] as double;

    if (type == 'high') {
      // 高値の場合：上昇トレンドまたは下降トレンドの一貫性をチェック
      final lastTrend = lastValue > secondLastValue;
      final newTrend = newValue > lastValue;
      return lastTrend == newTrend;
    } else {
      // 低値の場合：下降トレンドまたは上昇トレンドの一貫性をチェック
      final lastTrend = lastValue < secondLastValue;
      final newTrend = newValue < lastValue;
      return lastTrend == newTrend;
    }
  }

  /// トレンドラインを作成
  TrendLine? _createTrendLine(
    List<Map<String, dynamic>> points,
    List<PriceData> priceDataList,
    String type,
  ) {
    if (points.length < 2) return null;

    // 最初と最後の点を使用してトレンドラインを生成
    final startPoint = points.first;
    final endPoint = points.last;
    
    final startIndex = startPoint['index'] as int;
    final endIndex = endPoint['index'] as int;
    final startValue = startPoint['value'] as double;
    final endValue = endPoint['value'] as double;

    // 傾きを計算
    final slope = (endValue - startValue) / (endIndex - startIndex);

    // トレンドラインの強度を計算（R²値）
    final strength = _calculateTrendStrength(points, slope, startValue, startIndex);

    return TrendLine(
      startIndex: startIndex,
      endIndex: endIndex,
      startValue: startValue,
      endValue: endValue,
      slope: slope,
      strength: strength,
      type: type,
      points: points,
    );
  }

  /// トレンドラインの強度を計算（R²値）
  double _calculateTrendStrength(
    List<Map<String, dynamic>> points,
    double slope,
    double startValue,
    int startIndex,
  ) {
    if (points.length < 3) return 1.0;

    double totalSumSquares = 0.0;
    double residualSumSquares = 0.0;
    double meanValue = 0.0;

    // 平均値を計算
    for (final point in points) {
      meanValue += point['value'] as double;
    }
    meanValue /= points.length;

    // R²値を計算
    for (final point in points) {
      final actualValue = point['value'] as double;
      final index = point['index'] as int;
      final predictedValue = startValue + slope * (index - startIndex);
      
      totalSumSquares += pow(actualValue - meanValue, 2);
      residualSumSquares += pow(actualValue - predictedValue, 2);
    }

    if (totalSumSquares == 0) return 1.0;
    
    final rSquared = 1 - (residualSumSquares / totalSumSquares);
    return rSquared.clamp(0.0, 1.0);
  }

  /// SMA150の傾きを計算してトレンド方向を判定
  String _calculateTrendDirection(List<double?> ma150Series) {
    if (ma150Series.length < 10) return 'horizontal';
    
    // 最近10期間の傾きを計算
    final recentValues = <double>[];
    for (int i = max(0, ma150Series.length - 10); i < ma150Series.length; i++) {
      if (ma150Series[i] != null) {
        recentValues.add(ma150Series[i]!);
      }
    }
    
    if (recentValues.length < 5) return 'horizontal';
    
    // 線形回帰で傾きを計算
    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    final n = recentValues.length;
    
    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += recentValues[i];
      sumXY += i * recentValues[i];
      sumXX += i * i;
    }
    
    final slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    
    // 傾きの閾値で判定（0.1%以上の変化でトレンドとみなす）
    if (slope > 0.001) return 'upward';
    if (slope < -0.001) return 'downward';
    return 'horizontal';
  }

  /// ピボット高値/安値を検出
  List<Map<String, dynamic>> _detectPivotPoints(
    List<PriceData> priceDataList,
    List<double?> ma150Series,
  ) {
    final List<Map<String, dynamic>> pivotPoints = [];
    const int lookback = 5; // 左右5期間を確認
    
    for (int i = lookback; i < priceDataList.length - lookback; i++) {
      final currentData = priceDataList[i];
      bool isPivotHigh = true;
      bool isPivotLow = true;
      
      // ピボット高値の検出
      for (int j = i - lookback; j <= i + lookback; j++) {
        if (j == i) continue;
        if (j < 0 || j >= priceDataList.length) {
          isPivotHigh = false;
          break;
        }
        if (priceDataList[j].high >= currentData.high) {
          isPivotHigh = false;
          break;
        }
      }
      
      // ピボット安値の検出
      for (int j = i - lookback; j <= i + lookback; j++) {
        if (j == i) continue;
        if (j < 0 || j >= priceDataList.length) {
          isPivotLow = false;
          break;
        }
        if (priceDataList[j].low <= currentData.low) {
          isPivotLow = false;
          break;
        }
      }
      
      // ピボットポイントを追加
      if (isPivotHigh) {
        pivotPoints.add({
          'index': i,
          'value': currentData.high,
          'type': 'high',
          'timestamp': currentData.timestamp,
        });
      }
      
      if (isPivotLow) {
        pivotPoints.add({
          'index': i,
          'value': currentData.low,
          'type': 'low',
          'timestamp': currentData.timestamp,
        });
      }
    }
    
    return pivotPoints;
  }

  /// ノイズ抑制と交互性維持
  List<Map<String, dynamic>> _removeNoiseAndMaintainAlternation(
    List<Map<String, dynamic>> points,
    int minGapBars,
  ) {
    if (points.length < 2) return points;
    
    // インデックス順にソート
    points.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
    
    final List<Map<String, dynamic>> cleanedPoints = [points.first];
    
    for (int i = 1; i < points.length; i++) {
      final currentPoint = points[i];
      final lastPoint = cleanedPoints.last;
      
      // 最低バー間隔をチェック
      final gap = (currentPoint['index'] as int) - (lastPoint['index'] as int);
      if (gap < minGapBars) {
        // より強い点を選択（価格の絶対値が大きい方）
        final currentValue = (currentPoint['value'] as double).abs();
        final lastValue = (lastPoint['value'] as double).abs();
        
        if (currentValue > lastValue) {
          cleanedPoints.removeLast();
          cleanedPoints.add(currentPoint);
        }
      } else {
        cleanedPoints.add(currentPoint);
      }
    }
    
    return cleanedPoints;
  }

  /// 動的な距離閾値を計算
  /// ボラティリティに基づいて閾値を調整
  double calculateDynamicThreshold(
    List<PriceData> priceDataList,
    List<double?> ma150Series,
  ) {
    if (priceDataList.length < 20) return 0.005; // デフォルト0.5%

    // 最近20期間のボラティリティを計算
    double totalVolatility = 0.0;
    int validPeriods = 0;

    for (int i = max(0, priceDataList.length - 20); i < priceDataList.length; i++) {
      if (i >= ma150Series.length || ma150Series[i] == null) continue;
      
      final priceData = priceDataList[i];
      final ma150Value = ma150Series[i]!;
      
      // 高値と低値の平均からの乖離を計算
      final highDeviation = (priceData.high - ma150Value).abs() / ma150Value;
      final lowDeviation = (priceData.low - ma150Value).abs() / ma150Value;
      
      totalVolatility += (highDeviation + lowDeviation) / 2;
      validPeriods++;
    }

    if (validPeriods == 0) return 0.005;

    final averageVolatility = totalVolatility / validPeriods;
    
    // ボラティリティの0.3倍を閾値として使用（最小0.2%、最大2%）
    final dynamicThreshold = (averageVolatility * 0.3).clamp(0.002, 0.02);
    
    LogService.instance.debug('TrendFilteringService', 
      '動的閾値計算: 平均ボラティリティ${(averageVolatility * 100).toStringAsFixed(2)}%, 閾値${(dynamicThreshold * 100).toStringAsFixed(2)}%');
    
    return dynamicThreshold;
  }
}

/// フィルタリングされた高低点データ
class FilteredWavePoints {
  final List<Map<String, dynamic>> filteredHighPoints;
  final List<Map<String, dynamic>> filteredLowPoints;
  final List<TrendLine> trendLines;
  final List<Map<String, dynamic>> originalPoints;
  final SmoothTrendLine? smoothTrendLine; // 滑らかな折線
  final List<Map<String, dynamic>> fittedCurve; // 拟合曲线

  FilteredWavePoints({
    required this.filteredHighPoints,
    required this.filteredLowPoints,
    required this.trendLines,
    required this.originalPoints,
    this.smoothTrendLine,
    this.fittedCurve = const [],
  });

  /// フィルタリングされた点の総数
  int get totalFilteredPoints => filteredHighPoints.length + filteredLowPoints.length;

  /// フィルタリング率
  double get filteringRate {
    if (originalPoints.isEmpty) return 0.0;
    return (totalFilteredPoints / originalPoints.length);
  }
}

/// トレンドライン
class TrendLine {
  final int startIndex;
  final int endIndex;
  final double startValue;
  final double endValue;
  final double slope;
  final double strength; // R²値 (0.0-1.0)
  final String type; // 'high' or 'low'
  final List<Map<String, dynamic>> points;

  TrendLine({
    required this.startIndex,
    required this.endIndex,
    required this.startValue,
    required this.endValue,
    required this.slope,
    required this.strength,
    required this.type,
    required this.points,
  });

  /// 指定されたインデックスでの予測価格
  double getValueAt(int index) {
    return startValue + slope * (index - startIndex);
  }

  /// トレンドラインの長さ（期間数）
  int get length => endIndex - startIndex;

  /// トレンドラインの価格変動幅
  double get priceRange => (endValue - startValue).abs();

  /// トレンドの方向性
  String get direction {
    if (slope > 0) return 'upward';
    if (slope < 0) return 'downward';
    return 'horizontal';
  }

  /// トレンドラインの強度レベル
  String get strengthLevel {
    if (strength >= 0.8) return 'strong';
    if (strength >= 0.6) return 'moderate';
    if (strength >= 0.4) return 'weak';
    return 'very_weak';
  }
}

/// 150均線に沿った滑らかな折線データ
class SmoothTrendLine {
  final List<Map<String, dynamic>> points;
  final String type;
  final double averageDistanceFromMA;
  
  const SmoothTrendLine({
    required this.points,
    required this.type,
    required this.averageDistanceFromMA,
  });
}

/// 150均線に沿った滑らかな折線を生成
SmoothTrendLine? _generateSmoothTrendLineAroundMA150(
  List<Map<String, dynamic>> highPoints,
  List<Map<String, dynamic>> lowPoints,
  List<double?> ma150Series,
  List<PriceData> priceDataList,
) {
  LogService.instance.debug('TrendFilteringService', '_generateSmoothTrendLineAroundMA150開始: 高${highPoints.length}個, 低${lowPoints.length}個');
  
  if (highPoints.isEmpty && lowPoints.isEmpty) {
    LogService.instance.debug('TrendFilteringService', '高低点が空のため滑らかな折線生成をスキップ');
    return null;
  }
  
  // 全ての点を時系列順にマージ
  final List<Map<String, dynamic>> allPoints = [];
  allPoints.addAll(highPoints);
  allPoints.addAll(lowPoints);
  
  // 時系列順にソート
  allPoints.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
  
  LogService.instance.debug('TrendFilteringService', '全点マージ後: ${allPoints.length}個');
  
  if (allPoints.length < 2) {
    LogService.instance.debug('TrendFilteringService', '全点が2個未満のため滑らかな折線生成をスキップ');
    return null;
  }
  
  // 150均線に近い点を選択して滑らかな折線を生成
  final List<Map<String, dynamic>> smoothPoints = [];
  double totalDistance = 0.0;
  int validPointCount = 0;
  
  for (final point in allPoints) {
    final index = point['index'] as int;
    if (index >= ma150Series.length) continue;
    
    final ma150Value = ma150Series[index];
    if (ma150Value == null) continue;
    
    final pointValue = point['value'] as double;
    final distance = (pointValue - ma150Value).abs() / ma150Value;
    
    // 150均線から適度な距離にある点を選択（0.1% - 2.0%）- より緩い条件
    if (distance >= 0.001 && distance <= 0.02) {
      smoothPoints.add(point);
      totalDistance += distance;
      validPointCount++;
    }
  }
  
  LogService.instance.debug('TrendFilteringService', '滑らかな折線候補点: ${smoothPoints.length}個');
  
  if (smoothPoints.length < 2) {
    LogService.instance.debug('TrendFilteringService', '滑らかな折線候補点が2個未満のため生成をスキップ');
    return null;
  }
  
  final averageDistance = validPointCount > 0 ? totalDistance / validPointCount : 0.0;
  
  LogService.instance.debug('TrendFilteringService', '滑らかな折線生成成功: ${smoothPoints.length}個の点, 平均距離: ${(averageDistance * 100).toStringAsFixed(2)}%');
  
  return SmoothTrendLine(
    points: smoothPoints,
    type: 'smooth_trend',
    averageDistanceFromMA: averageDistance,
  );
}
