import 'dart:math' as math;
import '../models/wave_point.dart';
import '../models/wave_points.dart';
import '../models/price_data.dart';
import 'wave_denoising_service.dart';
import 'log_service.dart';

/// フラクタル構造データクラス
class FractalStructure {
  final int startIndex;
  final int endIndex;
  final int level;
  final double score;
  final WavePoint centerPoint;
  
  FractalStructure({
    required this.startIndex,
    required this.endIndex,
    required this.level,
    required this.score,
    required this.centerPoint,
  });
}

/// ウェーブ補間サービス
/// ChaikinとCatmull-Rom補間アルゴリズムを提供してウェーブラインを平滑化
class WaveInterpolationService {
  
  /// WavePointsからWavePointリストへの変換
  static List<WavePoint> _convertWavePointsToWavePointList(
    WavePoints wavePoints,
    List<PriceData> priceDataList,
  ) {
    Log.info('WaveInterpolationService', 'WavePoints変換開始: ${wavePoints.mergedPoints.length}個のmergedPoint → ${priceDataList.length}個のPriceData');
    final stopwatch = Stopwatch()..start();
    
    List<WavePoint> wavePointList = [];
    int skippedCount = 0;
    
    for (final point in wavePoints.mergedPoints) {
      final index = point['index'] as int?;
      if (index == null || index < 0 || index >= priceDataList.length) {
        Log.warning('WaveInterpolationService', '無効なインデックスを持つmergedPointをスキップ: $point');
        skippedCount++;
        continue;
      }
      
      final priceData = priceDataList[index];
      final timestamp = priceData.timestamp;
      final price = point['value'] as double;
      final type = point['type'] as String;
      
      wavePointList.add(WavePoint(
        timestamp: timestamp,
        price: price,
        type: type,
        index: index,
      ));
    }
    
    // タイムスタンプでソート
    wavePointList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    stopwatch.stop();
    Log.info('WaveInterpolationService', 'WavePoints変換完了: ${wavePointList.length}個の点生成, $skippedCount個スキップ ($stopwatch.elapsedMilliseconds ms)');
    return wavePointList;
  }
  
  /// Chaikin反復補間（WavePoints版）
  /// 反復細分化によって曲線を平滑化
  static List<WavePoint> chaikinInterpolationFromWavePoints(
    WavePoints wavePoints,
    List<PriceData> priceDataList, {
    int iterations = 3,
  }) {
    Log.info('WaveInterpolationService', 'Chaikin補間（WavePoints版）開始: ${wavePoints.mergedPoints.length}個の点, 反復回数=$iterations');
    final stopwatch = Stopwatch()..start();
    
    final points = _convertWavePointsToWavePointList(wavePoints, priceDataList);
    final result = chaikinInterpolation(points, iterations: iterations);
    
    stopwatch.stop();
    Log.info('WaveInterpolationService', 'Chaikin補間（WavePoints版）完了: ${result.length}個の点生成 (${stopwatch.elapsedMilliseconds}ms)');
    return result;
  }

  /// Chaikin反復補間
  /// 反復細分化によって曲線を平滑化
  static List<WavePoint> chaikinInterpolation(List<WavePoint> points, {int iterations = 3}) {
    Log.info('WaveInterpolationService', 'Chaikin補間開始: ${points.length}個の点, 反復回数=$iterations');
    final stopwatch = Stopwatch()..start();
    
    if (points.length < 2) {
      Log.info('WaveInterpolationService', 'Chaikin補間完了: 点が少なすぎるためスキップ (${points.length}個)');
      return points;
    }
    
    List<WavePoint> currentPoints = List.from(points);
    
    for (int i = 0; i < iterations; i++) {
      currentPoints = _chaikinIteration(currentPoints);
    }
    
    stopwatch.stop();
    Log.info('WaveInterpolationService', 'Chaikin補間完了: ${points.length} -> ${currentPoints.length} 点 ($iterations回反復, ${stopwatch.elapsedMilliseconds}ms)');
    return currentPoints;
  }
  
  /// Chaikin単回反復
  static List<WavePoint> _chaikinIteration(List<WavePoint> points) {
    if (points.length < 2) return points;
    
    List<WavePoint> newPoints = [];
    
    // 最初の点を追加
    newPoints.add(points.first);
    
    // 隣接する点のペアごとに補間
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      
      // Chaikin補間公式: 1/4 * p1 + 3/4 * p2 と 3/4 * p1 + 1/4 * p2
      final newP1 = WavePoint(
        timestamp: (p1.timestamp * 0.75 + p2.timestamp * 0.25).round(),
        price: p1.price * 0.75 + p2.price * 0.25,
        type: p1.type,
      );
      
      final newP2 = WavePoint(
        timestamp: (p1.timestamp * 0.25 + p2.timestamp * 0.75).round(),
        price: p1.price * 0.25 + p2.price * 0.75,
        type: p2.type,
      );
      
      newPoints.add(newP1);
      newPoints.add(newP2);
    }
    
    // 最後の点を追加
    newPoints.add(points.last);
    
    return newPoints;
  }
  
  /// Catmull-Romスプライン補間（WavePoints版）
  /// 平滑なスプライン曲線を生成
  static List<WavePoint> catmullRomInterpolationFromWavePoints(
    WavePoints wavePoints,
    List<PriceData> priceDataList, {
    int segmentsPerInterval = 10,
  }) {
    Log.info('WaveInterpolationService', 'Catmull-Rom補間（WavePoints版）開始: ${wavePoints.mergedPoints.length}個の点, セグメント数=$segmentsPerInterval');
    final stopwatch = Stopwatch()..start();
    
    final points = _convertWavePointsToWavePointList(wavePoints, priceDataList);
    final result = catmullRomInterpolation(points, segmentsPerInterval: segmentsPerInterval);
    
    stopwatch.stop();
    Log.info('WaveInterpolationService', 'Catmull-Rom補間（WavePoints版）完了: ${result.length}個の点生成 (${stopwatch.elapsedMilliseconds}ms)');
    return result;
  }

  /// Catmull-Romスプライン補間
  /// 平滑なスプライン曲線を生成
  static List<WavePoint> catmullRomInterpolation(List<WavePoint> points, {int segmentsPerInterval = 10}) {
    Log.info('WaveInterpolationService', 'Catmull-Rom補間開始: ${points.length}個の点, セグメント数=$segmentsPerInterval');
    final stopwatch = Stopwatch()..start();
    
    if (points.length < 2) {
      Log.info('WaveInterpolationService', 'Catmull-Rom補間完了: 点が少なすぎるためスキップ (${points.length}個)');
      return points;
    }
    
    List<WavePoint> interpolatedPoints = [];
    
    // 最初の点を追加
    interpolatedPoints.add(points.first);
    
    // 隣接する点のペアごとにCatmull-Rom補間
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : points[i + 1];
      
      // 補間点を生成
      for (int j = 1; j <= segmentsPerInterval; j++) {
        final t = j / segmentsPerInterval;
        final interpolatedPoint = _catmullRomInterpolate(p0, p1, p2, p3, t);
        interpolatedPoints.add(interpolatedPoint);
      }
    }
    
    // 最後の点を追加
    interpolatedPoints.add(points.last);
    
    stopwatch.stop();
    Log.info('WaveInterpolationService', 'Catmull-Rom補間完了: ${points.length} -> ${interpolatedPoints.length} 点 (各セグメント$segmentsPerInterval点, ${stopwatch.elapsedMilliseconds}ms)');
    return interpolatedPoints;
  }
  
  /// Catmull-Rom補間計算
  static WavePoint _catmullRomInterpolate(WavePoint p0, WavePoint p1, WavePoint p2, WavePoint p3, double t) {
    // Catmull-Romスプライン公式
    final t2 = t * t;
    final t3 = t2 * t;
    
    final x = 0.5 * (
      (2 * p1.timestamp) +
      (-p0.timestamp + p2.timestamp) * t +
      (2 * p0.timestamp - 5 * p1.timestamp + 4 * p2.timestamp - p3.timestamp) * t2 +
      (-p0.timestamp + 3 * p1.timestamp - 3 * p2.timestamp + p3.timestamp) * t3
    );
    
    final y = 0.5 * (
      (2 * p1.price) +
      (-p0.price + p2.price) * t +
      (2 * p0.price - 5 * p1.price + 4 * p2.price - p3.price) * t2 +
      (-p0.price + 3 * p1.price - 3 * p2.price + p3.price) * t3
    );
    
    return WavePoint(
      timestamp: x.round(),
      price: y,
      type: p1.type, // 最初の点のタイプを使用
    );
  }
  
  /// 線形補間（WavePoints版）
  static List<WavePoint> linearInterpolationFromWavePoints(
    WavePoints wavePoints,
    List<PriceData> priceDataList, {
    int segmentsPerInterval = 5,
  }) {
    Log.info('WaveInterpolationService', '線形補間（WavePoints版）開始: ${wavePoints.mergedPoints.length}個の点, セグメント数=$segmentsPerInterval');
    final stopwatch = Stopwatch()..start();
    
    final points = _convertWavePointsToWavePointList(wavePoints, priceDataList);
    final result = linearInterpolation(points, segmentsPerInterval: segmentsPerInterval);
    
    stopwatch.stop();
    Log.info('WaveInterpolationService', '線形補間（WavePoints版）完了: ${result.length}個の点生成 (${stopwatch.elapsedMilliseconds}ms)');
    return result;
  }

  /// 線形補間（比較用）
  static List<WavePoint> linearInterpolation(List<WavePoint> points, {int segmentsPerInterval = 5}) {
    Log.info('WaveInterpolationService', '線形補間開始: ${points.length}個の点, セグメント数=$segmentsPerInterval');
    final stopwatch = Stopwatch()..start();
    
    if (points.length < 2) {
      Log.info('WaveInterpolationService', '線形補間完了: 点が少なすぎるためスキップ (${points.length}個)');
      return points;
    }
    
    List<WavePoint> interpolatedPoints = [];
    
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      
      interpolatedPoints.add(p1);
      
      // 線形補間
      for (int j = 1; j < segmentsPerInterval; j++) {
        final t = j / segmentsPerInterval;
        final interpolatedPoint = WavePoint(
          timestamp: (p1.timestamp + (p2.timestamp - p1.timestamp) * t).round(),
          price: p1.price + (p2.price - p1.price) * t,
          type: p1.type,
        );
        interpolatedPoints.add(interpolatedPoint);
      }
    }
    
    interpolatedPoints.add(points.last);
    
    stopwatch.stop();
    Log.info('WaveInterpolationService', '線形補間完了: ${points.length} -> ${interpolatedPoints.length} 点 (各セグメント$segmentsPerInterval点, ${stopwatch.elapsedMilliseconds}ms)');
    return interpolatedPoints;
  }
  
  /// 小さすぎるウェーブ点をフィルタリング（WavePoints版）
  /// 価格変化が小さすぎる点を除去
  static List<WavePoint> filterSmallWavesFromWavePoints(
    WavePoints wavePoints,
    List<PriceData> priceDataList, {
    double minPriceChange = 0.0001,
  }) {
    Log.info('WaveInterpolationService', '小ウェーブフィルタリング（WavePoints版）開始: ${wavePoints.mergedPoints.length}個の点, 最小変化=$minPriceChange');
    final stopwatch = Stopwatch()..start();
    
    final points = _convertWavePointsToWavePointList(wavePoints, priceDataList);
    final result = filterSmallWaves(points, minPriceChange: minPriceChange);
    
    stopwatch.stop();
    Log.info('WaveInterpolationService', '小ウェーブフィルタリング（WavePoints版）完了: ${result.length}個の点生成 (${stopwatch.elapsedMilliseconds}ms)');
    return result;
  }

  /// 小さすぎるウェーブ点をフィルタリング
  /// 価格変化が小さすぎる点を除去
  static List<WavePoint> filterSmallWaves(List<WavePoint> points, {double minPriceChange = 0.0001}) {
    Log.info('WaveInterpolationService', '小ウェーブフィルタリング開始: ${points.length}個の点, 最小変化=$minPriceChange');
    final stopwatch = Stopwatch()..start();
    
    if (points.length < 3) {
      Log.info('WaveInterpolationService', '小ウェーブフィルタリング完了: 点が少なすぎるためスキップ (${points.length}個)');
      return points;
    }
    
    List<WavePoint> filteredPoints = [points.first];
    
    for (int i = 1; i < points.length - 1; i++) {
      final prevPoint = filteredPoints.last;
      final currentPoint = points[i];
      final nextPoint = points[i + 1];
      
      // 価格変化を計算
      final priceChangeFromPrev = (currentPoint.price - prevPoint.price).abs();
      final priceChangeToNext = (nextPoint.price - currentPoint.price).abs();
      
      // 価格変化が十分大きい場合、この点を保持
      if (priceChangeFromPrev >= minPriceChange || priceChangeToNext >= minPriceChange) {
        filteredPoints.add(currentPoint);
      }
    }
    
    filteredPoints.add(points.last);
    
    stopwatch.stop();
    Log.info('WaveInterpolationService', '小ウェーブフィルタリング完了: ${points.length} -> ${filteredPoints.length} 点 (最小変化: $minPriceChange, ${stopwatch.elapsedMilliseconds}ms)');
    return filteredPoints;
  }
  
  /// 幾何平滑化（WavePoints版）- 幾何距離に基づく平滑化アルゴリズム
  /// 非線形トレンドに適応し、重要な特徴を保持
  static List<WavePoint> geometricSmoothingFromWavePoints(
    WavePoints wavePoints,
    List<PriceData> priceDataList, {
    double smoothingFactor = 0.3,
  }) {
    final points = _convertWavePointsToWavePointList(wavePoints, priceDataList);
    return geometricSmoothing(points, smoothingFactor: smoothingFactor);
  }

  /// 幾何平滑化 - 幾何距離に基づく平滑化アルゴリズム
  /// 非線形トレンドに適応し、重要な特徴を保持
  static List<WavePoint> geometricSmoothing(List<WavePoint> points, {double smoothingFactor = 0.3}) {
    if (points.length < 3) return points;
    
    List<WavePoint> smoothedPoints = [points.first];
    
    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final current = points[i];
      final next = points[i + 1];
      
      // 幾何中心を計算
      final centerTimestamp = (prev.timestamp + current.timestamp + next.timestamp) / 3;
      final centerPrice = (prev.price + current.price + next.price) / 3;
      
      // 幾何中心までの距離重みを計算
      final distanceToCenter = _calculateGeometricDistance(current, centerTimestamp, centerPrice);
      final maxDistance = _calculateGeometricDistance(prev, centerTimestamp, centerPrice);
      
      // 距離重みに基づいて平滑化度を調整
      final adaptiveSmoothingFactor = smoothingFactor * (distanceToCenter / maxDistance).clamp(0.1, 1.0);
      
      // 幾何平滑化を適用
      final smoothedTimestamp = (current.timestamp * (1 - adaptiveSmoothingFactor) + 
                                centerTimestamp * adaptiveSmoothingFactor).round();
      final smoothedPrice = current.price * (1 - adaptiveSmoothingFactor) + 
                           centerPrice * adaptiveSmoothingFactor;
      
      smoothedPoints.add(WavePoint(
        timestamp: smoothedTimestamp,
        price: smoothedPrice,
        type: current.type,
      ));
    }
    
    smoothedPoints.add(points.last);
    
    Log.info('WaveInterpolationService', '幾何平滑化完了: ${points.length} -> ${smoothedPoints.length} 点 (平滑化因子: $smoothingFactor)');
    return smoothedPoints;
  }
  
  /// 統計平滑化（WavePoints版）- 統計特徴に基づく平滑化アルゴリズム
  /// 移動統計ウィンドウを使用した適応的平滑化
  static List<WavePoint> statisticalSmoothingFromWavePoints(
    WavePoints wavePoints,
    List<PriceData> priceDataList, {
    int windowSize = 5,
  }) {
    final points = _convertWavePointsToWavePointList(wavePoints, priceDataList);
    return statisticalSmoothing(points, windowSize: windowSize);
  }

  /// 統計平滑化 - 統計特徴に基づく平滑化アルゴリズム
  /// 移動統計ウィンドウを使用した適応的平滑化
  static List<WavePoint> statisticalSmoothing(List<WavePoint> points, {int windowSize = 5}) {
    if (points.length < windowSize) return points;
    
    List<WavePoint> smoothedPoints = [];
    
    for (int i = 0; i < points.length; i++) {
      final current = points[i];
      
      // 統計ウィンドウを計算
      final start = (i - windowSize ~/ 2).clamp(0, points.length - 1);
      final end = (i + windowSize ~/ 2 + 1).clamp(0, points.length);
      final window = points.sublist(start, end);
      
      // 統計特徴を計算
      final meanPrice = window.map((p) => p.price).reduce((a, b) => a + b) / window.length;
      
      // 標準偏差を計算
      final variance = window.map((p) => (p.price - meanPrice) * (p.price - meanPrice))
                          .reduce((a, b) => a + b) / window.length;
      final stdDev = math.sqrt(variance);
      
      // 統計特徴に基づいて適応的平滑化
      final priceDeviation = (current.price - meanPrice).abs();
      final smoothingStrength = (priceDeviation / (stdDev + 0.0001)).clamp(0.0, 1.0);
      
      // 統計平滑化を適用
      final smoothedPrice = current.price * (1 - smoothingStrength * 0.3) + 
                           meanPrice * smoothingStrength * 0.3;
      
      smoothedPoints.add(WavePoint(
        timestamp: current.timestamp,
        price: smoothedPrice,
        type: current.type,
      ));
    }
    
    Log.info('WaveInterpolationService', '統計平滑化完了: ${points.length} -> ${smoothedPoints.length} 点 (ウィンドウサイズ: $windowSize)');
    return smoothedPoints;
  }
  
  /// 混合平滑化（WavePoints版）- 幾何と統計平滑化の利点を結合
  static List<WavePoint> hybridSmoothingFromWavePoints(
    WavePoints wavePoints,
    List<PriceData> priceDataList, {
    double geometricWeight = 0.6,
    double statisticalWeight = 0.4,
    double smoothingFactor = 0.3,
    int windowSize = 5,
  }) {
    final points = _convertWavePointsToWavePointList(wavePoints, priceDataList);
    return hybridSmoothing(
      points,
      geometricWeight: geometricWeight,
      statisticalWeight: statisticalWeight,
      smoothingFactor: smoothingFactor,
      windowSize: windowSize,
    );
  }

  /// 混合平滑化 - 幾何と統計平滑化の利点を結合
  static List<WavePoint> hybridSmoothing(List<WavePoint> points, {
    double geometricWeight = 0.6,
    double statisticalWeight = 0.4,
    double smoothingFactor = 0.3,
    int windowSize = 5,
  }) {
    if (points.length < 3) return points;
    
    final geometricSmoothed = geometricSmoothing(points, smoothingFactor: smoothingFactor);
    final statisticalSmoothed = statisticalSmoothing(points, windowSize: windowSize);
    
    List<WavePoint> hybridPoints = [];
    
    for (int i = 0; i < points.length; i++) {
      final original = points[i];
      final geometric = geometricSmoothed[i];
      final statistical = statisticalSmoothed[i];
      
      // 2つの平滑化結果を混合
      final hybridPrice = geometric.price * geometricWeight + 
                         statistical.price * statisticalWeight;
      
      hybridPoints.add(WavePoint(
        timestamp: original.timestamp,
        price: hybridPrice,
        type: original.type,
      ));
    }
    
    Log.info('WaveInterpolationService', '混合平滑化完了: ${points.length} -> ${hybridPoints.length} 点 (幾何重み: $geometricWeight, 統計重み: $statisticalWeight)');
    return hybridPoints;
  }
  
  /// 幾何距離を計算
  static double _calculateGeometricDistance(WavePoint point, double centerTimestamp, double centerPrice) {
    final timeDiff = (point.timestamp - centerTimestamp).abs();
    final priceDiff = (point.price - centerPrice).abs();
    return math.sqrt(timeDiff * timeDiff + priceDiff * priceDiff);
  }
  
  /// フラクタルフィルタリング（WavePoints版）- フラクタル幾何学に基づくウェーブフィルタリングアルゴリズム
  /// 自己相似性を持つ重要なウェーブ構造を識別・保持
  static List<WavePoint> fractalFilteringFromWavePoints(
    WavePoints wavePoints,
    List<PriceData> priceDataList, {
    double fractalThreshold = 0.618, // 黄金比をフラクタル閾値として使用
    int minFractalLevel = 2, // 最小フラクタルレベル
    double scaleFactor = 1.5, // スケール因子
  }) {
    final points = _convertWavePointsToWavePointList(wavePoints, priceDataList);
    return fractalFiltering(
      points,
      fractalThreshold: fractalThreshold,
      minFractalLevel: minFractalLevel,
      scaleFactor: scaleFactor,
    );
  }

  /// フラクタルフィルタリング - フラクタル幾何学に基づくウェーブフィルタリングアルゴリズム
  /// 自己相似性を持つ重要なウェーブ構造を識別・保持
  static List<WavePoint> fractalFiltering(List<WavePoint> points, {
    double fractalThreshold = 0.618, // 黄金比をフラクタル閾値として使用
    int minFractalLevel = 2, // 最小フラクタルレベル
    double scaleFactor = 1.5, // スケール因子
  }) {
    if (points.length < 5) return points;
    
    // 1. フラクタル次元を計算
    final fractalDimension = _calculateFractalDimension(points);
    Log.info('WaveInterpolationService', 'フラクタル次元: $fractalDimension');
    
    // 2. フラクタル構造を識別
    final fractalStructures = _identifyFractalStructures(points, fractalThreshold, minFractalLevel);
    Log.info('WaveInterpolationService', '${fractalStructures.length} 個のフラクタル構造を識別');
    
    // 3. フラクタル重要性に基づいて点をフィルタリング
    final filteredPoints = _filterByFractalImportance(points, fractalStructures, scaleFactor);
    
    Log.info('WaveInterpolationService', 'フラクタルフィルタリング完了: ${points.length} -> ${filteredPoints.length} 点 (閾値: $fractalThreshold)');
    return filteredPoints;
  }
  
  /// フラクタル次元を計算 (Hausdorff次元の近似)
  static double _calculateFractalDimension(List<WavePoint> points) {
    if (points.length < 3) return 1.0;
    
    // ボックスカウント法を使用してフラクタル次元を計算
    final List<double> scales = [1.0, 2.0, 4.0, 8.0, 16.0];
    final List<double> counts = [];
    
    for (final scale in scales) {
      final count = _boxCount(points, scale);
      counts.add(count);
    }
    
    // フラクタル次元を計算 (log-log回帰の傾き)
    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    final n = scales.length;
    
    for (int i = 0; i < n; i++) {
      final x = math.log(scales[i]);
      final y = math.log(counts[i]);
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
    }
    
    final slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    return -slope; // フラクタル次元
  }
  
  /// ボックスカウント法
  static double _boxCount(List<WavePoint> points, double scale) {
    if (points.isEmpty) return 0;
    
    // データ範囲を計算
    final timestamps = points.map((p) => p.timestamp.toDouble()).toList();
    final prices = points.map((p) => p.price).toList();
    
    final minTime = timestamps.reduce(math.min);
    final maxTime = timestamps.reduce(math.max);
    final minPrice = prices.reduce(math.min);
    final maxPrice = prices.reduce(math.max);
    
    // ボックスサイズを計算
    final timeRange = maxTime - minTime;
    final priceRange = maxPrice - minPrice;
    final boxSize = math.max(timeRange, priceRange) / scale;
    
    if (boxSize <= 0) return 0;
    
    // 必要なボックス数を計算（デバッグ用、現在未使用）
    // final timeBoxes = (timeRange / boxSize).ceil();
    // final priceBoxes = (priceRange / boxSize).ceil();
    
    // 非空ボックスを統計
    final Set<String> occupiedBoxes = {};
    
    for (final point in points) {
      final timeBox = ((point.timestamp - minTime) / boxSize).floor();
      final priceBox = ((point.price - minPrice) / boxSize).floor();
      occupiedBoxes.add('$timeBox,$priceBox');
    }
    
    return occupiedBoxes.length.toDouble();
  }
  
  /// フラクタル構造を識別
  static List<FractalStructure> _identifyFractalStructures(
    List<WavePoint> points, 
    double threshold, 
    int minLevel
  ) {
    List<FractalStructure> structures = [];
    
    // 再帰的方法を使用して異なるスケールのフラクタル構造を識別
    _identifyFractalRecursive(points, 0, points.length - 1, threshold, minLevel, structures);
    
    return structures;
  }
  
  /// 再帰的にフラクタル構造を識別
  static void _identifyFractalRecursive(
    List<WavePoint> points,
    int start,
    int end,
    double threshold,
    int level,
    List<FractalStructure> structures,
  ) {
    if (end - start < 3) return;
    
    // 現在の区間のフラクタル特徴を計算
    final segment = points.sublist(start, end + 1);
    final fractalScore = _calculateFractalScore(segment);
    
    if (fractalScore >= threshold && level >= 2) {
      // フラクタル構造を発見
      structures.add(FractalStructure(
        startIndex: start,
        endIndex: end,
        level: level,
        score: fractalScore,
        centerPoint: segment[segment.length ~/ 2],
      ));
    }
    
    // 再帰的にサブ区間をチェック
    if (end - start > 6) {
      final mid = (start + end) ~/ 2;
      _identifyFractalRecursive(points, start, mid, threshold, level + 1, structures);
      _identifyFractalRecursive(points, mid, end, threshold, level + 1, structures);
    }
  }
  
  /// フラクタルスコアを計算
  static double _calculateFractalScore(List<WavePoint> segment) {
    if (segment.length < 3) return 0.0;
    
    // 自己相似性スコアを計算
    double similarityScore = 0.0;
    final n = segment.length;
    
    // 異なるスケールの類似性をチェック
    for (int scale = 2; scale <= n ~/ 2; scale++) {
      final subSegments = _createSubSegments(segment, scale);
      if (subSegments.length >= 2) {
        final similarity = _calculateSegmentSimilarity(subSegments);
        similarityScore += similarity / scale; // スケール重み
      }
    }
    
    // 黄金比適合度を計算
    final goldenRatioScore = _calculateGoldenRatioScore(segment);
    
    // 総合スコア
    return (similarityScore + goldenRatioScore) / 2.0;
  }
  
  /// サブセグメントを作成
  static List<List<WavePoint>> _createSubSegments(List<WavePoint> segment, int scale) {
    List<List<WavePoint>> subSegments = [];
    
    for (int i = 0; i <= segment.length - scale; i += scale ~/ 2) {
      final end = math.min(i + scale, segment.length);
      subSegments.add(segment.sublist(i, end));
    }
    
    return subSegments;
  }
  
  /// セグメント類似性を計算
  static double _calculateSegmentSimilarity(List<List<WavePoint>> segments) {
    if (segments.length < 2) return 0.0;
    
    double totalSimilarity = 0.0;
    int comparisons = 0;
    
    for (int i = 0; i < segments.length - 1; i++) {
      for (int j = i + 1; j < segments.length; j++) {
        final similarity = _calculateShapeSimilarity(segments[i], segments[j]);
        totalSimilarity += similarity;
        comparisons++;
      }
    }
    
    return comparisons > 0 ? totalSimilarity / comparisons : 0.0;
  }
  
  /// 形状類似性を計算
  static double _calculateShapeSimilarity(List<WavePoint> seg1, List<WavePoint> seg2) {
    if (seg1.length != seg2.length || seg1.length < 2) return 0.0;
    
    // 2つのセグメントを正規化
    final normalized1 = _normalizeSegment(seg1);
    final normalized2 = _normalizeSegment(seg2);
    
    // 相関係数を計算
    double correlation = 0.0;
    double sum1 = 0, sum2 = 0, sum1Sq = 0, sum2Sq = 0, sum12 = 0;
    
    for (int i = 0; i < normalized1.length; i++) {
      final p1 = normalized1[i];
      final p2 = normalized2[i];
      
      sum1 += p1.price;
      sum2 += p2.price;
      sum1Sq += p1.price * p1.price;
      sum2Sq += p2.price * p2.price;
      sum12 += p1.price * p2.price;
    }
    
    final n = normalized1.length.toDouble();
    final numerator = n * sum12 - sum1 * sum2;
    final denominator = math.sqrt((n * sum1Sq - sum1 * sum1) * (n * sum2Sq - sum2 * sum2));
    
    if (denominator > 0) {
      correlation = numerator / denominator;
    }
    
    return correlation.abs();
  }
  
  /// セグメントを正規化
  static List<WavePoint> _normalizeSegment(List<WavePoint> segment) {
    if (segment.isEmpty) return [];
    
    final prices = segment.map((p) => p.price).toList();
    final minPrice = prices.reduce(math.min);
    final maxPrice = prices.reduce(math.max);
    final range = maxPrice - minPrice;
    
    if (range == 0) return segment;
    
    return segment.map((point) => WavePoint(
      timestamp: point.timestamp,
      price: (point.price - minPrice) / range,
      type: point.type,
    )).toList();
  }
  
  /// 黄金比適合度を計算
  static double _calculateGoldenRatioScore(List<WavePoint> segment) {
    if (segment.length < 3) return 0.0;
    
    const goldenRatio = 1.618033988749895;
    double score = 0.0;
    
    // 価格比率が黄金比に適合するかチェック
    for (int i = 1; i < segment.length - 1; i++) {
      final prev = segment[i - 1];
      final current = segment[i];
      final next = segment[i + 1];
      
      final ratio1 = (current.price - prev.price) / (next.price - current.price).abs();
      final ratio2 = (next.price - current.price) / (current.price - prev.price).abs();
      
      final deviation1 = (ratio1 - goldenRatio).abs() / goldenRatio;
      final deviation2 = (ratio2 - goldenRatio).abs() / goldenRatio;
      
      score += math.exp(-math.min(deviation1, deviation2));
    }
    
    return score / (segment.length - 2);
  }
  
  /// フラクタル重要性に基づいて点をフィルタリング
  static List<WavePoint> _filterByFractalImportance(
    List<WavePoint> points,
    List<FractalStructure> structures,
    double scaleFactor,
  ) {
    if (structures.isEmpty) return points;
    
    List<WavePoint> filteredPoints = [];
    final importanceScores = List<double>.filled(points.length, 0.0);
    
    // 各点の重要性スコアを計算
    for (final structure in structures) {
      final weight = structure.score * math.pow(scaleFactor, structure.level);
      
      for (int i = structure.startIndex; i <= structure.endIndex; i++) {
        if (i < importanceScores.length) {
          importanceScores[i] += weight;
        }
      }
    }
    
    // 重要性閾値を計算
    final maxScore = importanceScores.reduce(math.max);
    final threshold = maxScore * 0.3; // 最も重要な30%の点を保持
    
    // 点をフィルタリング
    for (int i = 0; i < points.length; i++) {
      if (importanceScores[i] >= threshold || 
          i == 0 || 
          i == points.length - 1) { // 最初と最後の点を保持
        filteredPoints.add(points[i]);
      }
    }
    
    return filteredPoints;
  }
  
  /// 移動平均線参照トレンドに基づく高低点フィルタリング（WavePoints版）
  /// 移動平均線を参照トレンドとして使用して高低点の有意性を判断
  static List<WavePoint> maTrendFilteringFromWavePoints(
    WavePoints wavePoints,
    List<PriceData> priceDataList,
    List<double> maValues, {
    int maPeriod = 150,
    double significanceThreshold = 0.02, // 2%の有意性閾値
    double trendStrengthMultiplier = 1.5, // トレンド強度乗数
    bool useAdaptiveThreshold = true, // 適応的閾値を使用するか
  }) {
    final points = _convertWavePointsToWavePointList(wavePoints, priceDataList);
    return maTrendFiltering(
      points,
      maValues,
      maPeriod: maPeriod,
      significanceThreshold: significanceThreshold,
      trendStrengthMultiplier: trendStrengthMultiplier,
      useAdaptiveThreshold: useAdaptiveThreshold,
    );
  }

  /// 強化版MAトレンドフィルタリング（WavePoints版）- 複数の戦略を結合
  static List<WavePoint> enhancedMaTrendFilteringFromWavePoints(
    WavePoints wavePoints,
    List<PriceData> priceDataList,
    List<double> maValues, {
    int maPeriod = 150,
    double significanceThreshold = 0.02,
    double trendStrengthMultiplier = 1.5,
    bool useVolumeWeighting = false, // 出来高重み付けを使用するか
    bool useTimeDecay = false, // 時間減衰を使用するか
    double timeDecayFactor = 0.95, // 時間減衰因子
  }) {
    final points = _convertWavePointsToWavePointList(wavePoints, priceDataList);
    return enhancedMaTrendFiltering(
      points,
      maValues,
      maPeriod: maPeriod,
      significanceThreshold: significanceThreshold,
      trendStrengthMultiplier: trendStrengthMultiplier,
      useVolumeWeighting: useVolumeWeighting,
      useTimeDecay: useTimeDecay,
      timeDecayFactor: timeDecayFactor,
    );
  }

  /// 移動平均線参照トレンドに基づく高低点フィルタリング
  /// 移動平均線を参照トレンドとして使用して高低点の有意性を判断
  static List<WavePoint> maTrendFiltering(
    List<WavePoint> points,
    List<double> maValues, {
    int maPeriod = 150,
    double significanceThreshold = 0.02, // 2%の有意性閾値
    double trendStrengthMultiplier = 1.5, // トレンド強度乗数
    bool useAdaptiveThreshold = true, // 適応的閾値を使用するか
  }) {
    if (points.isEmpty || maValues.isEmpty) {
      Log.warning('WaveInterpolationService', 'MAトレンドフィルタリング: 入力データが空です');
      return points;
    }
    
    List<WavePoint> significantPoints = [];
    
    // トレンド強度を計算
    final trendStrength = _calculateTrendStrength(maValues);
    Log.info('WaveInterpolationService', 'MAトレンド強度: $trendStrength');
    
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      if (point.index == null || point.index! >= maValues.length) {
        significantPoints.add(point); // Keep points without index (e.g., interpolated)
        continue;
      }
      final maValue = maValues[point.index!];
      if (maValue.isNaN) continue; // Skip if MA value is not available
      
      // 価格とMAの偏差を計算
      final priceDeviation = (point.price - maValue).abs();
      final relativeDeviation = priceDeviation / maValue;
      
      // 適応的閾値調整
      double adaptiveThreshold = significanceThreshold;
      if (useAdaptiveThreshold) {
        // トレンド強度に基づいて閾値を調整
        adaptiveThreshold *= (1.0 + trendStrength * trendStrengthMultiplier);
      }
      
      // 有意な高低点かどうかを判断
      final isSignificant = _isSignificantPoint(
        point, 
        maValue, 
        relativeDeviation, 
        adaptiveThreshold,
        i,
        points,
        maValues,
      );
      
      if (isSignificant) {
        significantPoints.add(point);
      }
    }
    
    Log.info('WaveInterpolationService', 'MAトレンドフィルタリング完了: ${points.length} -> ${significantPoints.length} 点 (MA周期: $maPeriod, 閾値: $significanceThreshold)');
    return significantPoints;
  }
  
  /// トレンド強度を計算
  static double _calculateTrendStrength(List<double> maValues) {
    if (maValues.length < 2) return 0.0;
    
    // MAの傾き変化を計算
    List<double> slopes = [];
    for (int i = 1; i < maValues.length; i++) {
      final slope = maValues[i] - maValues[i - 1];
      slopes.add(slope);
    }
    
    // 傾きの分散をトレンド強度指標として計算
    final meanSlope = slopes.reduce((a, b) => a + b) / slopes.length;
    final variance = slopes.map((s) => (s - meanSlope) * (s - meanSlope))
                          .reduce((a, b) => a + b) / slopes.length;
    
    return math.sqrt(variance);
  }
  
  /// 有意な高低点かどうかを判断
  static bool _isSignificantPoint(
    WavePoint point,
    double maValue,
    double relativeDeviation,
    double threshold,
    int index,
    List<WavePoint> allPoints,
    List<double> allMaValues,
  ) {
    // 1. 基礎有意性チェック
    if (relativeDeviation < threshold) return false;
    
    // 2. トレンド方向一貫性チェック
    final trendDirection = _getTrendDirection(point, maValue, index, allPoints, allMaValues);
    if (!trendDirection.isConsistent) return false;
    
    // 3. 局所極値チェック
    if (!_isLocalExtremum(point, index, allPoints)) return false;
    
    // 4. 変動幅チェック
    if (!_hasSignificantAmplitude(point, index, allPoints, threshold)) return false;
    
    return true;
  }
  
  /// トレンド方向を取得
  static TrendDirection _getTrendDirection(
    WavePoint point,
    double maValue,
    int index,
    List<WavePoint> allPoints,
    List<double> allMaValues,
  ) {
    // 前後のいくつかの点のトレンド方向をチェック
    final lookback = math.min(5, index);
    final lookforward = math.min(5, allPoints.length - index - 1);
    
    int upwardCount = 0;
    int downwardCount = 0;
    
    // 前向きトレンドをチェック
    for (int i = math.max(0, index - lookback); i < index; i++) {
      if (allPoints[i].price < allMaValues[i]) {
        downwardCount++;
      } else {
        upwardCount++;
      }
    }
    
    // 後向きトレンドをチェック
    for (int i = index + 1; i < math.min(allPoints.length, index + lookforward + 1); i++) {
      if (allPoints[i].price < allMaValues[i]) {
        downwardCount++;
      } else {
        upwardCount++;
      }
    }
    
    final totalCount = upwardCount + downwardCount;
    if (totalCount == 0) return TrendDirection.neutral;
    
    final upwardRatio = upwardCount / totalCount;
    final downwardRatio = downwardCount / totalCount;
    
    // トレンド一貫性を判断
    if (upwardRatio > 0.6) {
      return TrendDirection.upward;
    } else if (downwardRatio > 0.6) {
      return TrendDirection.downward;
    } else {
      return TrendDirection.neutral;
    }
  }
  
  /// 局所極値かどうかをチェック
  static bool _isLocalExtremum(WavePoint point, int index, List<WavePoint> allPoints) {
    if (index <= 0 || index >= allPoints.length - 1) return true; // 境界点
    
    final prev = allPoints[index - 1];
    final current = point;
    final next = allPoints[index + 1];
    
    // 局所高値または安値かどうかをチェック
    if (point.type == 'high') {
      return current.price > prev.price && current.price > next.price;
    } else if (point.type == 'low') {
      return current.price < prev.price && current.price < next.price;
    }
    
    return false;
  }
  
  /// 有意な変動幅があるかどうかをチェック
  static bool _hasSignificantAmplitude(
    WavePoint point,
    int index,
    List<WavePoint> allPoints,
    double threshold,
  ) {
    // 局所変動幅を計算
    final windowSize = math.min(10, allPoints.length);
    final start = math.max(0, index - windowSize ~/ 2);
    final end = math.min(allPoints.length, index + windowSize ~/ 2);
    
    final localPrices = allPoints.sublist(start, end).map((p) => p.price).toList();
    final minPrice = localPrices.reduce(math.min);
    final maxPrice = localPrices.reduce(math.max);
    final amplitude = (maxPrice - minPrice) / minPrice;
    
    return amplitude > threshold;
  }
  
  /// 強化版MAトレンドフィルタリング - 複数の戦略を結合
  static List<WavePoint> enhancedMaTrendFiltering(
    List<WavePoint> points,
    List<double> maValues, {
    int maPeriod = 150,
    double significanceThreshold = 0.02,
    double trendStrengthMultiplier = 1.5,
    bool useVolumeWeighting = false, // 出来高重み付けを使用するか
    bool useTimeDecay = false, // 時間減衰を使用するか
    double timeDecayFactor = 0.95, // 時間減衰因子
  }) {
    if (points.length < maPeriod || maValues.length != points.length) {
      Log.warning('WaveInterpolationService', '強化MAトレンドフィルタリング: データ不足またはMA値が一致しません');
      return points;
    }
    
    List<WavePoint> significantPoints = [];
    
    // 動的閾値を計算
    final dynamicThreshold = _calculateDynamicThreshold(maValues, significanceThreshold);
    
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final maValue = maValues[i];
      
      // 価格とMAの偏差を計算
      final priceDeviation = (point.price - maValue).abs();
      final relativeDeviation = priceDeviation / maValue;
      
      // 動的閾値を適用
      final currentThreshold = dynamicThreshold[i];
      
      // 時間減衰調整
      double timeWeight = 1.0;
      if (useTimeDecay) {
        final timeFromStart = i / points.length;
        timeWeight = math.pow(timeDecayFactor, timeFromStart).toDouble();
      }
      
      // 出来高重み付け調整（出来高データがある場合）
      double volumeWeight = 1.0;
      if (useVolumeWeighting) {
        // ここで出来高重み付けロジックを追加できます
        // volumeWeight = _calculateVolumeWeight(point, i, allPoints);
      }
      
      // 総合重み調整
      final adjustedThreshold = currentThreshold * timeWeight * volumeWeight;
      
      // 有意な高低点かどうかを判断
      final isSignificant = _isSignificantPoint(
        point, 
        maValue, 
        relativeDeviation, 
        adjustedThreshold,
        i,
        points,
        maValues,
      );
      
      if (isSignificant) {
        significantPoints.add(point);
      }
    }
    
    Log.info('WaveInterpolationService', '強化MAトレンドフィルタリング完了: ${points.length} -> ${significantPoints.length} 点');
    return significantPoints;
  }
  
  /// 動的閾値を計算
  static List<double> _calculateDynamicThreshold(List<double> maValues, double baseThreshold) {
    List<double> dynamicThresholds = [];
    
    // MAの変動性を計算
    final volatility = _calculateVolatility(maValues);
    
    for (int i = 0; i < maValues.length; i++) {
      // 局所変動性に基づいて閾値を調整
      final localVolatility = _getLocalVolatility(maValues, i);
      final adjustedThreshold = baseThreshold * (1.0 + localVolatility / volatility);
      dynamicThresholds.add(adjustedThreshold);
    }
    
    return dynamicThresholds;
  }
  
  /// 変動性を計算
  static double _calculateVolatility(List<double> values) {
    if (values.length < 2) return 0.0;
    
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => (v - mean) * (v - mean))
                          .reduce((a, b) => a + b) / values.length;
    
    return math.sqrt(variance);
  }
  
  /// 局所変動性を取得
  static double _getLocalVolatility(List<double> values, int index) {
    final windowSize = math.min(20, values.length);
    final start = math.max(0, index - windowSize ~/ 2);
    final end = math.min(values.length, index + windowSize ~/ 2);
    
    final localValues = values.sublist(start, end);
    return _calculateVolatility(localValues);
  }
  
  /// 150移動平均線に基づく連続重みマッピングと軟化処理（WavePoints版）
  /// 相対距離、幾何適合度、峰の有意性を結合して平滑重みを生成
  static List<WavePoint> continuousWeightFilteringFromWavePoints(
    WavePoints wavePoints,
    List<PriceData> priceDataList,
    List<double> ma150Values, {
    int maPeriod = 150,
    double distanceWeight = 0.4, // 距離重み
    double geometryWeight = 0.3, // 幾何適合度重み
    double significanceWeight = 0.3, // 峰有意性重み
    double timeFilterAlpha = 0.3, // 時間フィルタ係数
    double shrinkFactor = 0.7, // 軟化因子
    bool useAdaptiveWeights = true, // 適応的重みを使用するか
  }) {
    final points = _convertWavePointsToWavePointList(wavePoints, priceDataList);
    return continuousWeightFiltering(
      points,
      ma150Values,
      maPeriod: maPeriod,
      distanceWeight: distanceWeight,
      geometryWeight: geometryWeight,
      significanceWeight: significanceWeight,
      timeFilterAlpha: timeFilterAlpha,
      shrinkFactor: shrinkFactor,
      useAdaptiveWeights: useAdaptiveWeights,
    );
  }

  /// 150移動平均線に基づく連続重みマッピングと軟化処理
  /// 相対距離、幾何適合度、峰の有意性を結合して平滑重みを生成
  static List<WavePoint> continuousWeightFiltering(
    List<WavePoint> points,
    List<double> ma150Values, {
    int maPeriod = 150,
    double distanceWeight = 0.4, // 距離重み
    double geometryWeight = 0.3, // 幾何適合度重み
    double significanceWeight = 0.3, // 峰有意性重み
    double timeFilterAlpha = 0.3, // 時間フィルタ係数
    double shrinkFactor = 0.7, // 軟化因子
    bool useAdaptiveWeights = true, // 適応的重みを使用するか
  }) {
    if (points.isEmpty || ma150Values.isEmpty) {
      Log.warning('WaveInterpolationService', '連続重みフィルタリング: 入力データが空です');
      return points;
    }
    
    // 1. 各点の連続重みを計算
    final List<double> rawWeights = _calculateContinuousWeights(
      points, 
      ma150Values, 
      distanceWeight, 
      geometryWeight, 
      significanceWeight,
      useAdaptiveWeights,
    );
    
    // 2. 重みに時間フィルタを適用
    final List<double> filteredWeights = _applyTimeFilter(rawWeights, timeFilterAlpha);
    
    // 3. 重みに基づいて軟化処理
    final List<WavePoint> softenedPoints = _applySoftShrinking(
      points, 
      filteredWeights, 
      ma150Values, 
      shrinkFactor,
    );
    
    Log.info('WaveInterpolationService', '連続重みフィルタリング完了: ${points.length} -> ${softenedPoints.length} 点');
    return softenedPoints;
  }
  
  /// 連続重みを計算
  static List<double> _calculateContinuousWeights(
    List<WavePoint> points,
    List<double> ma150Values,
    double distanceWeight,
    double geometryWeight,
    double significanceWeight,
    bool useAdaptiveWeights,
  ) {
    List<double> weights = [];
    
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      if (point.index == null || point.index! >= ma150Values.length) {
        weights.add(0.5); // Default weight for points without an index
        continue;
      }
      final maValue = ma150Values[point.index!];
      if (maValue.isNaN) { weights.add(0.5); continue; }
      
      // 1. 150MAとの相対距離重み
      final double distanceScore = _calculateDistanceScore(point, maValue);
      
      // 2. 局所チャネルとの幾何適合度重み
      final double geometryScore = _calculateGeometryScore(point, i, points, ma150Values);
      
      // 3. 峰の有意性重み
      final double significanceScore = _calculateSignificanceScore(point, i, points);
      
      // 4. 適応的重み調整
      double adaptiveDistanceWeight = distanceWeight;
      double adaptiveGeometryWeight = geometryWeight;
      double adaptiveSignificanceWeight = significanceWeight;
      
      if (useAdaptiveWeights) {
        final adaptiveWeights = _calculateAdaptiveWeights(point, i, points, ma150Values);
        adaptiveDistanceWeight = adaptiveWeights['distance']!;
        adaptiveGeometryWeight = adaptiveWeights['geometry']!;
        adaptiveSignificanceWeight = adaptiveWeights['significance']!;
      }
      
      // 5. 総合重み計算
      final double combinedWeight = (distanceScore * adaptiveDistanceWeight +
                                   geometryScore * adaptiveGeometryWeight +
                                   significanceScore * adaptiveSignificanceWeight);
      
      // 6. 重みを[0,1]範囲に正規化
      final double normalizedWeight = _normalizeWeight(combinedWeight, i, points.length);
      
      weights.add(normalizedWeight);
    }
    
    return weights;
  }
  
  /// 距離スコアを計算
  static double _calculateDistanceScore(WavePoint point, double maValue) {
    // 相対距離を計算
    if (maValue == 0) return 0.0;
    final double relativeDistance = (point.price - maValue).abs() / maValue;
    
    // sigmoid関数を使用して距離を[0,1]範囲にマッピング
    // 距離が大きいほどスコアが高くなるが、増加は徐々に減速
    final double sigmoidScore = 1.0 / (1.0 + math.exp(-10.0 * (relativeDistance - 0.02)));
    
    return sigmoidScore;
  }
  
  /// 幾何適合度スコアを計算
  static double _calculateGeometryScore(
    WavePoint point, 
    int index, 
    List<WavePoint> allPoints, 
    List<double> allMaValues,
  ) {
    // 局所チャネルを計算
    final channelInfo = _calculateLocalChannel(point.index ?? index, allPoints, allMaValues);
    
    // 点がチャネル内にあるかチェック
    final double lower = channelInfo['lower']!;
    final double upper = channelInfo['upper']!;
    final bool isInChannel = point.price >= lower && point.price <= upper;
    
    if (!isInChannel && lower > 0 && upper > 0) {
      // チャネル外の場合、偏差度を計算
      final double deviation = point.price < lower 
          ? (lower - point.price) / lower
          : (point.price - upper) / upper;
      
      // 偏差が大きいほどスコアが高い
      return math.min(1.0, deviation * 5.0);
    } else if (isInChannel && lower > 0 && upper > 0) {
      // チャネル内の場合、チャネル境界との距離を計算
      final double distanceToLower = (point.price - lower) / lower;
      final double distanceToUpper = (upper - point.price) / upper;
      final double minDistance = math.min(distanceToLower, distanceToUpper);
      
      // 境界に近いほどスコアが高い
      return math.min(1.0, minDistance * 10.0);
    } else {
      return 0.0;
    }
  }
  
  /// 峰の有意性スコアを計算
  static double _calculateSignificanceScore(WavePoint point, int index, List<WavePoint> allPoints) {
    // 局所峰谷特徴を計算
    final peakInfo = _calculateLocalPeakInfo(point, index, allPoints);
    
    // 峰谷特徴を総合
    final double peakStrength = peakInfo['strength']!;
    final double peakSharpness = peakInfo['sharpness']!;
    final double peakIsolation = peakInfo['isolation']!;
    
    // 重み付き組み合わせ
    return (peakStrength * 0.4 + peakSharpness * 0.3 + peakIsolation * 0.3);
  }
  
  /// 局所チャネル情報を計算
  static Map<String, double> _calculateLocalChannel(
    int index, 
    List<WavePoint> allPoints, 
    List<double> allMaValues,
  ) {
    final windowSize = math.min(20, allPoints.length);
    final start = math.max(0, index - windowSize ~/ 2);
    final end = math.min(allPoints.length, index + windowSize ~/ 2);
    
    final localPoints = allPoints.sublist(start, end);
    final localMaValues = allMaValues.sublist(start, end);
    
    // 価格範囲を計算
    final prices = localPoints.map((p) => p.price).toList();
    final minPrice = prices.reduce(math.min);
    final maxPrice = prices.reduce(math.max);
    
    // MA範囲を計算
    final maMin = localMaValues.reduce(math.min);
    final maMax = localMaValues.reduce(math.max);
    
    // チャネル境界
    final double channelWidth = (maxPrice - minPrice) * 0.1; // 10%のチャネル幅
    final double lower = maMin - channelWidth;
    final double upper = maMax + channelWidth;
    
    return {
      'lower': lower,
      'upper': upper,
      'width': channelWidth,
      'center': (lower + upper) / 2,
    };
  }
  
  /// 局所峰谷情報を計算
  static Map<String, double> _calculateLocalPeakInfo(
    WavePoint point, 
    int index, 
    List<WavePoint> allPoints,
  ) {
    final windowSize = math.min(10, allPoints.length);
    final start = math.max(0, index - windowSize ~/ 2);
    final end = math.min(allPoints.length, index + windowSize ~/ 2);
    
    final localPoints = allPoints.sublist(start, end);
    final localPrices = localPoints.map((p) => p.price).toList();
    
    // 峰強度：周囲の点との差異
    final double peakStrength = _calculatePeakStrength(point.price, localPrices);
    
    // 峰鋭度：価格変化の急峻さ
    final double peakSharpness = _calculatePeakSharpness(point, index, allPoints);
    
    // 峰孤立性：隣接峰との距離
    final double peakIsolation = _calculatePeakIsolation(point, index, allPoints);
    
    return {
      'strength': peakStrength,
      'sharpness': peakSharpness,
      'isolation': peakIsolation,
    };
  }
  
  /// 峰強度を計算
  static double _calculatePeakStrength(double pointPrice, List<double> localPrices) {
    final double meanPrice = localPrices.reduce((a, b) => a + b) / localPrices.length;
    final double stdDev = _calculateVolatility(localPrices);
    
    if (stdDev == 0) return 0.0;
    
    final double zScore = (pointPrice - meanPrice).abs() / stdDev;
    return math.min(1.0, zScore / 3.0); // 3-sigmaルール
  }
  
  /// 峰鋭度を計算
  static double _calculatePeakSharpness(WavePoint point, int index, List<WavePoint> allPoints) {
    if (index <= 0 || index >= allPoints.length - 1) return 0.0;
    
    final prev = allPoints[index - 1];
    final next = allPoints[index + 1];
    
    // 価格変化率を計算
    final double leftSlope = (point.price - prev.price) / (point.timestamp - prev.timestamp);
    final double rightSlope = (next.price - point.price) / (next.timestamp - point.timestamp);
    
    // 鋭度 = 傾き変化の絶対値
    final double sharpness = (leftSlope - rightSlope).abs();
    
    return math.min(1.0, sharpness * 1000); // 正規化
  }
  
  /// 峰孤立性を計算
  static double _calculatePeakIsolation(WavePoint point, int index, List<WavePoint> allPoints) {
    // 最も近い隣接峰を検索
    int leftPeakIndex = -1;
    int rightPeakIndex = -1;
    
    // 左方向に検索
    for (int i = index - 1; i >= 0; i--) {
      if (_isLocalPeak(allPoints[i], i, allPoints)) {
        leftPeakIndex = i;
        break;
      }
    }
    
    // 右方向に検索
    for (int i = index + 1; i < allPoints.length; i++) {
      if (_isLocalPeak(allPoints[i], i, allPoints)) {
        rightPeakIndex = i;
        break;
      }
    }
    
    // 孤立性を計算
    double isolation = 1.0;
    if (leftPeakIndex != -1) {
      final double leftDistance = (point.timestamp - allPoints[leftPeakIndex].timestamp).abs().toDouble();
      isolation *= math.min(1.0, leftDistance / 1000); // 時間距離正規化
    }
    
    if (rightPeakIndex != -1) {
      final double rightDistance = (allPoints[rightPeakIndex].timestamp - point.timestamp).abs().toDouble();
      isolation *= math.min(1.0, rightDistance / 1000);
    }
    
    return isolation;
  }
  
  /// 局所峰かどうかを判断
  static bool _isLocalPeak(WavePoint point, int index, List<WavePoint> allPoints) {
    if (index <= 0 || index >= allPoints.length - 1) return false;
    
    final prev = allPoints[index - 1];
    final next = allPoints[index + 1];
    
    if (point.type == 'high') {
      return point.price > prev.price && point.price > next.price;
    } else if (point.type == 'low') {
      return point.price < prev.price && point.price < next.price;
    }
    
    return false;
  }
  
  /// 適応的重みを計算
  static Map<String, double> _calculateAdaptiveWeights(
    WavePoint point, 
    int index, 
    List<WavePoint> allPoints, 
    List<double> allMaValues,
  ) {
    // 市場状態に基づいて重みを調整
    final marketState = _analyzeMarketState(point.index ?? index, allPoints, allMaValues);
    
    double distanceWeight = 0.4;
    double geometryWeight = 0.3;
    double significanceWeight = 0.3;
    
    switch (marketState) {
      case MarketState.trending:
        // トレンド市場：距離と有意性をより重視
        distanceWeight = 0.5;
        geometryWeight = 0.2;
        significanceWeight = 0.3;
        break;
      case MarketState.ranging:
        // レンジ市場：幾何適合度をより重視
        distanceWeight = 0.2;
        geometryWeight = 0.5;
        significanceWeight = 0.3;
        break;
      case MarketState.volatile:
        // ボラティリティ市場：有意性をより重視
        distanceWeight = 0.3;
        geometryWeight = 0.2;
        significanceWeight = 0.5;
        break;
    }
    
    return {
      'distance': distanceWeight,
      'geometry': geometryWeight,
      'significance': significanceWeight,
    };
  }
  
  /// 市場状態を分析
  static MarketState _analyzeMarketState(int index, List<WavePoint> allPoints, List<double> allMaValues) {
    final windowSize = math.min(50, allPoints.length);
    final start = math.max(0, index - windowSize ~/ 2);
    final end = math.min(allPoints.length, index + windowSize ~/ 2);
    
    final localPoints = allPoints.sublist(start, end);
    final localMaValues = allMaValues.sublist(start, end);
    
    // トレンド強度を計算
    final double trendStrength = _calculateTrendStrength(localMaValues);
    
    // 変動性を計算
    final double volatility = _calculateVolatility(localPoints.map((p) => p.price).toList());
    
    // 市場状態を判断
    if (trendStrength > 0.5) {
      return MarketState.trending;
    } else if (volatility > 0.02) {
      return MarketState.volatile;
    } else {
      return MarketState.ranging;
    }
  }
  
  /// 重み正規化
  static double _normalizeWeight(double weight, int index, int totalLength) {
    // sigmoid関数を使用して正規化
    final double normalized = 1.0 / (1.0 + math.exp(-5.0 * (weight - 0.5)));
    
    // 時間減衰：新しい点ほど重みが高い
    final double timeDecay = 1.0 - (index / totalLength) * 0.2;
    
    return normalized * timeDecay;
  }
  
  /// 時間フィルタを適用
  static List<double> _applyTimeFilter(List<double> weights, double alpha) {
    if (weights.isEmpty) return weights;
    
    List<double> filteredWeights = [weights.first];
    
    for (int i = 1; i < weights.length; i++) {
      // 指数移動平均フィルタ
      final double filtered = alpha * weights[i] + (1 - alpha) * filteredWeights.last;
      filteredWeights.add(filtered);
    }
    
    return filteredWeights;
  }
  
  /// 軟化処理を適用
  static List<WavePoint> _applySoftShrinking(
    List<WavePoint> points,
    List<double> weights,
    List<double> ma150Values,
    double shrinkFactor,
  ) {
    List<WavePoint> softenedPoints = [];
    
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final weight = weights[i];
      if (point.index == null || point.index! >= ma150Values.length) {
        softenedPoints.add(point);
        continue;
      }
      final maValue = ma150Values[point.index!];
      if (maValue.isNaN) { softenedPoints.add(point); continue; }
      
      // 重み閾値：重みが十分高い点のみ保持
      if (weight < 0.3) continue;
      
      // 軟化処理：MA方向に収縮
      final double shrinkage = (1.0 - weight) * shrinkFactor;
      final double softenedPrice = point.price * (1 - shrinkage) + maValue * shrinkage;
      
      softenedPoints.add(WavePoint(
        timestamp: point.timestamp,
        price: softenedPrice,
        type: point.type,
      ));
    }
    
    return softenedPoints;
  }
  
  /// 150移動平均線制約に基づくN字構造特徴分析（WavePoints版）
  /// N字構造、チャネル/プラットフォーム幾何法則、ウェーブ強度特徴、時間間隔制約、波高制約を結合
  static List<WavePoint> nStructureAnalysisFromWavePoints(
    WavePoints wavePoints,
    List<PriceData> priceDataList,
    List<double> ma150Values, {
    int maPeriod = 150,
    double nStructureWeight = 0.25, // N字構造重み
    double channelWeight = 0.25, // チャネル/プラットフォーム重み
    double waveStrengthWeight = 0.2, // ウェーブ強度重み
    double timeIntervalWeight = 0.15, // 時間間隔重み
    double waveHeightWeight = 0.15, // 波高制約重み
    double timeFilterAlpha = 0.3, // 時間フィルタ係数
    double shrinkFactor = 0.7, // 軟化因子
  }) {
    final points = _convertWavePointsToWavePointList(wavePoints, priceDataList);
    return nStructureAnalysis(
      points,
      ma150Values,
      maPeriod: maPeriod,
      nStructureWeight: nStructureWeight,
      channelWeight: channelWeight,
      waveStrengthWeight: waveStrengthWeight,
      timeIntervalWeight: timeIntervalWeight,
      waveHeightWeight: waveHeightWeight,
      timeFilterAlpha: timeFilterAlpha,
      shrinkFactor: shrinkFactor,
    );
  }

  /// 150移動平均線制約に基づくN字構造特徴分析
  /// N字構造、チャネル/プラットフォーム幾何法則、ウェーブ強度特徴、時間間隔制約、波高制約を結合
  static List<WavePoint> nStructureAnalysis(
    List<WavePoint> points,
    List<double> ma150Values, {
    int maPeriod = 150,
    double nStructureWeight = 0.25, // N字構造重み
    double channelWeight = 0.25, // チャネル/プラットフォーム重み
    double waveStrengthWeight = 0.2, // ウェーブ強度重み
    double timeIntervalWeight = 0.15, // 時間間隔重み
    double waveHeightWeight = 0.15, // 波高制約重み
    double timeFilterAlpha = 0.3, // 時間フィルタ係数
    double shrinkFactor = 0.7, // 軟化因子
  }) {
    Log.info('WaveInterpolationService', 'N字構造分析開始: ${points.length}個の点, MA150データ=${ma150Values.length}個, MA周期=$maPeriod');
    final stopwatch = Stopwatch()..start();
    
    if (points.isEmpty || ma150Values.isEmpty) {
      Log.warning('WaveInterpolationService', 'N字構造分析: 入力データが空です - points=${points.length}, ma150Values=${ma150Values.length}');
      return points;
    }
    
    // 1. 候補極値検出：峰谷検出 + 局所"N字"確認
    final List<double> nStructureScores = _calculateNStructureScores(points);
    
    // 2. チャネル/プラットフォームフィッティング：各点とチャネル/プラットフォーム中心線の距離を計算
    final List<double> channelScores = _calculateChannelScores(points, ma150Values);
    
    // 3. 波幅と強度検出：各波の振幅、傾き、強度を計算
    final List<double> waveStrengthScores = _calculateWaveStrengthScores(points, ma150Values);
    
    // 4. 時間間隔チェック：各波高低点間隔制約
    final List<double> timeIntervalScores = _calculateTimeIntervalScores(points);
    
    // 5. 波高制約：各波高さ制約
    final List<double> waveHeightScores = _calculateWaveHeightScores(points, ma150Values);
    
    // 6. 総合重み生成
    final List<double> combinedWeights = _combineStructureWeights(
      nStructureScores,
      channelScores,
      waveStrengthScores,
      timeIntervalScores,
      waveHeightScores,
      nStructureWeight,
      channelWeight,
      waveStrengthWeight,
      timeIntervalWeight,
      waveHeightWeight,
    );
    
    // 7. 時間フィルタ
    final List<double> filteredWeights = _applyTimeFilter(combinedWeights, timeFilterAlpha);
    
    // 8. 軟化処理
    final List<WavePoint> processedPoints = _applySoftShrinking(
      points,
      filteredWeights,
      ma150Values,
      shrinkFactor,
    );
    
    stopwatch.stop();
    Log.info('WaveInterpolationService', 'N字構造分析完了: ${points.length} -> ${processedPoints.length} 点 (${stopwatch.elapsedMilliseconds}ms)');
    return processedPoints;
  }
  
  /// N字構造スコアを計算
  static List<double> _calculateNStructureScores(List<WavePoint> points) {
    List<double> scores = [];
    
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      
      // 完全なN字構造が形成されているかチェック
      final double nStructureScore = _analyzeNStructure(point, i, points);
      scores.add(nStructureScore);
    }
    
    return scores;
  }
  
  /// N字構造を分析
  static double _analyzeNStructure(WavePoint point, int index, List<WavePoint> allPoints) {
    // 局所N字構造を検索
    final nStructureInfo = _findLocalNStructure(point, index, allPoints);
    
    if (nStructureInfo == null) return 0.0;
    
    // N字構造の完全性スコアを計算
    final double completeness = _calculateNStructureCompleteness(nStructureInfo);
    
    // N字構造の対称性スコアを計算
    final double symmetry = _calculateNStructureSymmetry(nStructureInfo);
    
    // N字構造の強度スコアを計算
    final double strength = _calculateNStructureStrength(nStructureInfo);
    
    // 総合スコア
    return (completeness * 0.4 + symmetry * 0.3 + strength * 0.3);
  }
  
  /// 局所N字構造を検索
  static Map<String, dynamic>? _findLocalNStructure(WavePoint point, int index, List<WavePoint> allPoints) {
    // 前後方向に検索して、可能なN字構造を探す
    final windowSize = math.min(20, allPoints.length);
    final start = math.max(0, index - windowSize ~/ 2);
    final end = math.min(allPoints.length, index + windowSize ~/ 2);
    
    final localPoints = allPoints.sublist(start, end);
    
    // 峰谷交互パターンを検索
    List<WavePoint> peaks = [];
    List<WavePoint> troughs = [];
    
    for (int i = 1; i < localPoints.length - 1; i++) {
      final current = localPoints[i];
      final prev = localPoints[i - 1];
      final next = localPoints[i + 1];
      
      if (current.price > prev.price && current.price > next.price) {
        peaks.add(current);
      } else if (current.price < prev.price && current.price < next.price) {
        troughs.add(current);
      }
    }
    
    // N字構造が形成されているかチェック
    if (peaks.length >= 2 && troughs.isNotEmpty) {
      // 上昇N字：安値-高値-安値-高値
      if (point.type == 'high' && peaks.length >= 2) {
        final firstPeak = peaks[0];
        final secondPeak = peaks[1];
        final middleTrough = troughs.isNotEmpty ? troughs[0] : null;
        
        if (middleTrough != null && 
            firstPeak.timestamp < middleTrough.timestamp && 
            middleTrough.timestamp < secondPeak.timestamp) {
          return {
            'type': 'rising_n',
            'first_peak': firstPeak,
            'trough': middleTrough,
            'second_peak': secondPeak,
            'current_point': point,
          };
        }
      }
    }
    
    if (troughs.length >= 2 && peaks.isNotEmpty) {
      // 下降N字：高値-安値-高値-安値
      if (point.type == 'low' && troughs.length >= 2) {
        final firstTrough = troughs[0];
        final secondTrough = troughs[1];
        final middlePeak = peaks.isNotEmpty ? peaks[0] : null;
        
        if (middlePeak != null && 
            firstTrough.timestamp < middlePeak.timestamp && 
            middlePeak.timestamp < secondTrough.timestamp) {
          return {
            'type': 'falling_n',
            'first_trough': firstTrough,
            'peak': middlePeak,
            'second_trough': secondTrough,
            'current_point': point,
          };
        }
      }
    }
    
    return null;
  }
  
  /// N字構造の完全性を計算
  static double _calculateNStructureCompleteness(Map<String, dynamic> nStructure) {
    // N字構造が完全かどうかをチェック
    final String type = nStructure['type'];
    
    if (type == 'rising_n') {
      final firstPeak = nStructure['first_peak'] as WavePoint;
      final trough = nStructure['trough'] as WavePoint;
      final secondPeak = nStructure['second_peak'] as WavePoint;
      
      // 価格関係をチェック
      final bool priceOrder = firstPeak.price > trough.price && secondPeak.price > trough.price;
      final bool timeOrder = firstPeak.timestamp < trough.timestamp && trough.timestamp < secondPeak.timestamp;
      
      return (priceOrder && timeOrder) ? 1.0 : 0.5;
    } else if (type == 'falling_n') {
      final firstTrough = nStructure['first_trough'] as WavePoint;
      final peak = nStructure['peak'] as WavePoint;
      final secondTrough = nStructure['second_trough'] as WavePoint;
      
      // 価格関係をチェック
      final bool priceOrder = firstTrough.price < peak.price && secondTrough.price < peak.price;
      final bool timeOrder = firstTrough.timestamp < peak.timestamp && peak.timestamp < secondTrough.timestamp;
      
      return (priceOrder && timeOrder) ? 1.0 : 0.5;
    }
    
    return 0.0;
  }
  
  /// N字構造の対称性を計算
  static double _calculateNStructureSymmetry(Map<String, dynamic> nStructure) {
    final String type = nStructure['type'];
    
    if (type == 'rising_n') {
      final firstPeak = nStructure['first_peak'] as WavePoint;
      final trough = nStructure['trough'] as WavePoint;
      final secondPeak = nStructure['second_peak'] as WavePoint;
      
      // 時間対称性を計算
      final double firstInterval = (trough.timestamp - firstPeak.timestamp).toDouble();
      final double secondInterval = (secondPeak.timestamp - trough.timestamp).toDouble();
      final double timeSum = firstInterval + secondInterval;
      final double timeSymmetry = timeSum > 0 ? 1.0 - (firstInterval - secondInterval).abs() / timeSum : 1.0;
      
      // 価格対称性を計算
      final double firstAmplitude = firstPeak.price - trough.price;
      final double secondAmplitude = secondPeak.price - trough.price;
      final double priceSum = firstAmplitude + secondAmplitude;
      final double priceSymmetry = priceSum > 0 ? 1.0 - (firstAmplitude - secondAmplitude).abs() / priceSum : 1.0;
      
      return (timeSymmetry + priceSymmetry) / 2.0;
    } else if (type == 'falling_n') {
      final firstTrough = nStructure['first_trough'] as WavePoint;
      final peak = nStructure['peak'] as WavePoint;
      final secondTrough = nStructure['second_trough'] as WavePoint;
      
      // 時間対称性を計算
      final double firstInterval = (peak.timestamp - firstTrough.timestamp).toDouble();
      final double secondInterval = (secondTrough.timestamp - peak.timestamp).toDouble();
      final double timeSum = firstInterval + secondInterval;
      final double timeSymmetry = timeSum > 0 ? 1.0 - (firstInterval - secondInterval).abs() / timeSum : 1.0;
      
      // 価格対称性を計算
      final double firstAmplitude = peak.price - firstTrough.price;
      final double secondAmplitude = peak.price - secondTrough.price;
      final double priceSum = firstAmplitude + secondAmplitude;
      final double priceSymmetry = priceSum > 0 ? 1.0 - (firstAmplitude - secondAmplitude).abs() / priceSum : 1.0;
      
      return (timeSymmetry + priceSymmetry) / 2.0;
    }
    
    return 0.0;
  }
  
  /// N字構造の強度を計算
  static double _calculateNStructureStrength(Map<String, dynamic> nStructure) {
    final String type = nStructure['type'];
    
    if (type == 'rising_n') {
      final firstPeak = nStructure['first_peak'] as WavePoint;
      final secondPeak = nStructure['second_peak'] as WavePoint;
      
      // 総体振幅を計算
      final double totalAmplitude = secondPeak.price - firstPeak.price;
      // ゼロ除算を避ける
      final double basePrice = math.max(0.00001, math.min(firstPeak.price, secondPeak.price));
      final double relativeAmplitude = totalAmplitude / basePrice;
      
      // 時間スパンを計算
      final double timeSpan = (secondPeak.timestamp - firstPeak.timestamp).toDouble();
      final double timeStrength = math.min(1.0, timeSpan / 1000); // 正規化時間スパン
      
      return (relativeAmplitude * 0.7 + timeStrength * 0.3);
    } else if (type == 'falling_n') {
      final firstTrough = nStructure['first_trough'] as WavePoint;
      final secondTrough = nStructure['second_trough'] as WavePoint;
      
      // 総体振幅を計算
      final double totalAmplitude = firstTrough.price - secondTrough.price;
      // ゼロ除算を避ける
      final double basePrice = math.max(0.00001, math.max(firstTrough.price, secondTrough.price));
      final double relativeAmplitude = totalAmplitude / basePrice;
      
      // 時間スパンを計算
      final double timeSpan = (secondTrough.timestamp - firstTrough.timestamp).toDouble();
      final double timeStrength = math.min(1.0, timeSpan / 1000);
      
      return (relativeAmplitude * 0.7 + timeStrength * 0.3);
    }
    
    return 0.0;
  }
  
  /// チャネル/プラットフォームスコアを計算
  static List<double> _calculateChannelScores(List<WavePoint> points, List<double> ma150Values) {
    List<double> scores = [];
    
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      if (point.index == null || point.index! >= ma150Values.length) {
        scores.add(0.5); // Default score
        continue;
      }
      final maValue = ma150Values[point.index!];
      if (maValue.isNaN) { scores.add(0.5); continue; }
      
      // MA150との距離スコアを計算
      final double distanceScore = _calculateDistanceScore(point, maValue);
      
      // チャネルフィットスコアを計算
      final double channelFitScore = _calculateChannelFitScore(point, i, points, ma150Values);
      
      // 総合スコア
      scores.add((distanceScore * 0.6 + channelFitScore * 0.4));
    }
    
    return scores;
  }
  
  /// チャネルフィットスコアを計算
  static double _calculateChannelFitScore(
    WavePoint point, 
    int index, 
    List<WavePoint> allPoints, 
    List<double> allMaValues,
  ) {
    // 局所チャネルを計算
    final channelInfo = _calculateLocalChannel(index, allPoints, allMaValues);
    
    // ポイントとチャネルのフィット度を計算
    final double channelCenter = channelInfo['center']!;
    final double channelWidth = channelInfo['width']!;
    
    // 正規化距離を計算
    final double normalizedDistance = (point.price - channelCenter).abs() / channelWidth;
    
    // sigmoid関数を使用して[0,1]にマッピング
    return 1.0 / (1.0 + math.exp(5.0 * (normalizedDistance - 1.0)));
  }
  
  /// 波の強度スコアを計算
  static List<double> _calculateWaveStrengthScores(List<WavePoint> points, List<double> ma150Values) {
    List<double> scores = [];
    
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      if (point.index == null || point.index! >= ma150Values.length) {
        scores.add(0.5); // Default score
        continue;
      }
      
      // 波幅を計算
      final double amplitude = _calculateWaveAmplitude(point, i, points);
      
      // 傾斜を計算
      final double slope = _calculateWaveSlope(point, i, points);
      
      // 強度減衰/急上昇を計算
      final double strengthChange = _calculateStrengthChange(point, i, points, ma150Values);
      
      // 総合スコア
      final double combinedScore = (amplitude * 0.4 + slope * 0.3 + strengthChange * 0.3);
      scores.add(combinedScore);
    }
    
    return scores;
  }
  
  /// 波幅を計算
  static double _calculateWaveAmplitude(WavePoint point, int index, List<WavePoint> allPoints) {
    // 隣接する峰谷を検索
    final adjacentPoints = _findAdjacentPeaksTroughs(point, index, allPoints);
    
    if (adjacentPoints.isEmpty) return 0.0;
    
    // 最大振幅を計算
    double maxAmplitude = 0.0;
    for (final adjacentPoint in adjacentPoints) {
      final double amplitude = (point.price - adjacentPoint.price).abs();
      maxAmplitude = math.max(maxAmplitude, amplitude);
    }
    
    // 正規化
    return math.min(1.0, maxAmplitude / point.price);
  }
  
  /// 傾斜を計算
  static double _calculateWaveSlope(WavePoint point, int index, List<WavePoint> allPoints) {
    if (index <= 0 || index >= allPoints.length - 1) return 0.0;
    
    final prev = allPoints[index - 1];
    final next = allPoints[index + 1];
    
    // 左右の傾斜を計算
    final double leftSlope = (point.price - prev.price) / (point.timestamp - prev.timestamp);
    final double rightSlope = (next.price - point.price) / (next.timestamp - point.timestamp);
    
    // 傾斜変化率
    final double slopeChange = (leftSlope - rightSlope).abs();
    
    return math.min(1.0, slopeChange * 1000); // 正規化
  }
  
  /// 強度変化を計算
  static double _calculateStrengthChange(
    WavePoint point, 
    int index, 
    List<WavePoint> allPoints, 
    List<double> ma150Values,
  ) {
    // 現在の波の強度を計算
    final double currentStrength = _calculateCurrentWaveStrength(point, index, allPoints, ma150Values);
    
    // 履歴平均強度を計算
    final double averageStrength = _calculateAverageWaveStrength(index, allPoints, ma150Values);
    
    if (averageStrength == 0) return 0.0;
    
    // 強度変化率を計算
    final double strengthRatio = currentStrength / averageStrength;
    
    // [0,1]にマッピング、1.0は正常な強度を表す
    return math.min(1.0, 2.0 - strengthRatio.abs());
  }
  
  /// 現在の波の強度を計算
  static double _calculateCurrentWaveStrength(
    WavePoint point, 
    int index, 
    List<WavePoint> allPoints, 
    List<double> ma150Values,
  ) {
    // 波の境界を検索
    final waveBounds = _findWaveBounds(point, index, allPoints);
    
    if (waveBounds == null) return 0.0;
    
    final double startPrice = waveBounds['start_price']!;
    final double endPrice = waveBounds['end_price']!;
    final double timeSpan = waveBounds['time_span']!;
    
    // 強度 = 価格変化 / 時間スパン
    final double priceChange = (endPrice - startPrice).abs();
    final double strength = priceChange / (timeSpan + 1); // ゼロ除算を避ける
    
    return strength;
  }
  
  /// 平均波の強度を計算
  static double _calculateAverageWaveStrength(int index, List<WavePoint> allPoints, List<double> ma150Values) {
    final windowSize = math.min(20, allPoints.length);
    final start = math.max(0, index - windowSize);
    final end = math.min(allPoints.length, index + windowSize);
    
    double totalStrength = 0.0;
    int count = 0;
    
    for (int i = start; i < end - 1; i++) {
      final double strength = _calculateCurrentWaveStrength(allPoints[i], i, allPoints, ma150Values);
      totalStrength += strength;
      count++;
    }
    
    return count > 0 ? totalStrength / count : 0.0;
  }
  
  /// 隣接する峰谷を検索
  static List<WavePoint> _findAdjacentPeaksTroughs(WavePoint point, int index, List<WavePoint> allPoints) {
    List<WavePoint> adjacentPoints = [];
    
    // 前方検索
    for (int i = index - 1; i >= 0 && i >= index - 10; i--) {
      if (_isLocalPeak(allPoints[i], i, allPoints)) {
        adjacentPoints.add(allPoints[i]);
        break;
      }
    }
    
    // 後方検索
    for (int i = index + 1; i < allPoints.length && i <= index + 10; i++) {
      if (_isLocalPeak(allPoints[i], i, allPoints)) {
        adjacentPoints.add(allPoints[i]);
        break;
      }
    }
    
    return adjacentPoints;
  }
  
  /// 波の境界を検索
  static Map<String, double>? _findWaveBounds(WavePoint point, int index, List<WavePoint> allPoints) {
    // 波の起点と終点を検索
    int startIndex = index;
    int endIndex = index;
    
    // 前方に起点を検索
    for (int i = index - 1; i >= 0; i--) {
      if (_isLocalPeak(allPoints[i], i, allPoints)) {
        startIndex = i;
        break;
      }
    }
    
    // 後方に終点を検索
    for (int i = index + 1; i < allPoints.length; i++) {
      if (_isLocalPeak(allPoints[i], i, allPoints)) {
        endIndex = i;
        break;
      }
    }
    
    if (startIndex == endIndex) return null;
    
    return {
      'start_price': allPoints[startIndex].price,
      'end_price': allPoints[endIndex].price,
      'time_span': (allPoints[endIndex].timestamp - allPoints[startIndex].timestamp).toDouble(),
    };
  }
  
  /// 時間間隔スコアを計算
  static List<double> _calculateTimeIntervalScores(List<WavePoint> points) {
    List<double> scores = [];
    
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      
      // 隣接する峰谷との時間間隔を計算
      final double timeInterval = _calculateTimeInterval(point, i, points);
      
      // 局所平均波周期を計算
      final double averagePeriod = _calculateAveragePeriod(i, points);
      
      // 3倍制約を超えているかチェック
      final double constraintRatio = timeInterval / (averagePeriod * 3.0);
      final double score = constraintRatio <= 1.0 ? 1.0 : math.max(0.0, 1.0 - (constraintRatio - 1.0));
      
      scores.add(score);
    }
    
    return scores;
  }
  
  /// 時間間隔を計算
  static double _calculateTimeInterval(WavePoint point, int index, List<WavePoint> allPoints) {
    // 最も近い隣接峰谷を検索
    final adjacentPoints = _findAdjacentPeaksTroughs(point, index, allPoints);
    
    if (adjacentPoints.isEmpty) return 0.0;
    
    // 最小時間間隔を計算
    double minInterval = double.infinity;
    for (final adjacentPoint in adjacentPoints) {
      final double interval = (point.timestamp - adjacentPoint.timestamp).abs().toDouble();
      minInterval = math.min(minInterval, interval);
    }
    
    return minInterval == double.infinity ? 0.0 : minInterval;
  }
  
  /// 平均周期を計算
  static double _calculateAveragePeriod(int index, List<WavePoint> allPoints) {
    final windowSize = math.min(20, allPoints.length);
    final start = math.max(0, index - windowSize);
    final end = math.min(allPoints.length, index + windowSize);
    
    List<double> periods = [];
    
    for (int i = start; i < end - 1; i++) {
      final double interval = _calculateTimeInterval(allPoints[i], i, allPoints);
      if (interval > 0) {
        periods.add(interval);
      }
    }
    
    if (periods.isEmpty) return 1000.0; // デフォルト周期
    
    return periods.reduce((a, b) => a + b) / periods.length;
  }
  
  /// 波高制約スコアを計算
  static List<double> _calculateWaveHeightScores(List<WavePoint> points, List<double> ma150Values) {
    List<double> scores = [];
    
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      if (point.index == null || point.index! >= ma150Values.length) {
        scores.add(0.5); // Default score
        continue;
      }
      
      // 現在の波幅を計算
      final double currentAmplitude = _calculateWaveAmplitude(point, i, points);
      
      // 中枢波幅を計算
      final double centralAmplitude = _calculateCentralAmplitude(i, points, ma150Values);
      
      // 3倍制約を超えているかチェック
      final double amplitudeRatio = centralAmplitude > 0 ? currentAmplitude / (centralAmplitude * 3.0) : 1.0;
      final double score = amplitudeRatio <= 1.0 ? 1.0 : math.max(0.0, 1.0 - (amplitudeRatio - 1.0) * 0.5);
      
      scores.add(score);
    }
    
    return scores;
  }
  
  /// 中枢波幅を計算
  static double _calculateCentralAmplitude(int index, List<WavePoint> allPoints, List<double> ma150Values) {
    final windowSize = math.min(20, allPoints.length);
    final start = math.max(0, index - windowSize ~/ 2);
    final end = math.min(allPoints.length, index + windowSize ~/ 2);
    
    final localPoints = allPoints.sublist(start, end);
    if (localPoints.isEmpty) return 0.0;

    final localMaIndices = localPoints.map((p) => p.index).where((i) => i != null).cast<int>().toList();
    if (localMaIndices.isEmpty) return 0.0;
    if (localMaIndices.isEmpty) return 0.0; // MAインデックスを持つ点がない

    final localMaValues = localMaIndices.map((i) => ma150Values[i]).where((v) => !v.isNaN).toList();
    if (localMaValues.isEmpty) return 0.0;
    
    // 価格範囲を計算
    final prices = localPoints.map((p) => p.price).toList();
    final minPrice = prices.reduce(math.min);
    final maxPrice = prices.reduce(math.max);
    
    // MA範囲を計算
    final maMin = localMaValues.reduce(math.min);
    final maMax = localMaValues.reduce(math.max);
    
    // 中枢波幅 = (価格範囲 + MA範囲) / 2
    final double priceRange = maxPrice - minPrice;
    final double maRange = maMax - maMin;
    
    return (priceRange + maRange) / 2.0;
  }
  
  /// 総合構造重み
  static List<double> _combineStructureWeights(
    List<double> nStructureScores,
    List<double> channelScores,
    List<double> waveStrengthScores,
    List<double> timeIntervalScores,
    List<double> waveHeightScores,
    double nStructureWeight,
    double channelWeight,
    double waveStrengthWeight,
    double timeIntervalWeight,
    double waveHeightWeight,
  ) {
    List<double> combinedWeights = [];
    
    for (int i = 0; i < nStructureScores.length; i++) {
      final double combinedScore = 
          nStructureScores[i] * nStructureWeight +
          channelScores[i] * channelWeight +
          waveStrengthScores[i] * waveStrengthWeight +
          timeIntervalScores[i] * timeIntervalWeight +
          waveHeightScores[i] * waveHeightWeight;
      
      // [0,1]に正規化
      final double normalizedWeight = _normalizeWeight(combinedScore, i, nStructureScores.length);
      combinedWeights.add(normalizedWeight);
    }
    
    return combinedWeights;
  }

  /// 按需生成单一的格式化波浪方法
  static Map<String, List<WavePoint>> _generateSingleMethodFromWavePoints(
    String methodName,
    List<WavePoint> originalPoints,
    List<double>? maValues,
    int maPeriod,
  ) {
    final result = <String, List<WavePoint>>{};
    Log.info('WaveInterpolationService', '按需生成方法: $methodName');
    Log.info('WaveInterpolationService', '入力データ: ${originalPoints.length}個の点, MAデータ=${maValues != null ? "${maValues.length}個" : "null"}');

    // 1. 基础点集处理
    List<WavePoint> basePoints = filterSmallWaves(originalPoints, minPriceChange: 0.0001);
    Log.info('WaveInterpolationService', '基礎点集処理完了: ${basePoints.length}個の点');
    
    // 检查是否需要去噪
    if (methodName.contains('denoised')) {
      Log.info('WaveInterpolationService', 'ノイズ除去処理開始');
      basePoints = WaveDenoisingService.denoiseWavePoints(basePoints);
      Log.info('WaveInterpolationService', 'ノイズ除去処理完了: ${basePoints.length}個の点');
    }
    // 检查是否需要分形过滤
    if (methodName.contains('fractal')) {
      Log.info('WaveInterpolationService', 'フラクタルフィルタリング開始');
      basePoints = fractalFiltering(basePoints, fractalThreshold: 0.618);
      Log.info('WaveInterpolationService', 'フラクタルフィルタリング完了: ${basePoints.length}個の点');
    }

    // 2. 主要过滤处理 (MA趋势, 连续权重等)
    List<WavePoint> processedPoints = basePoints;
    Log.info('WaveInterpolationService', '主要フィルタ処理開始: ${processedPoints.length}個の点');
    
    if (maValues != null) {
      Log.info('WaveInterpolationService', 'MAデータあり、フィルタ処理実行');
      if (methodName.contains('maTrend')) {
        Log.info('WaveInterpolationService', 'MAトレンドフィルタリング実行');
        processedPoints = maTrendFiltering(basePoints, maValues, maPeriod: maPeriod);
      } else if (methodName.contains('continuousWeight')) {
        Log.info('WaveInterpolationService', '連続重みフィルタリング実行');
        processedPoints = continuousWeightFiltering(basePoints, maValues, maPeriod: maPeriod);
      } else if (methodName.contains('nStructure')) {
        Log.info('WaveInterpolationService', 'N字構造分析実行');
        processedPoints = nStructureAnalysis(basePoints, maValues, maPeriod: maPeriod);
      }
      Log.info('WaveInterpolationService', '主要フィルタ処理完了: ${processedPoints.length}個の点');
    } else if (methodName.contains('maTrend') || methodName.contains('continuousWeight') || methodName.contains('nStructure')) {
      Log.warning('WaveInterpolationService', '无法生成 $methodName，因为缺少MA数据');
      Log.warning('WaveInterpolationService', 'MAデータ状況: maValues=$maValues, maPeriod=$maPeriod');
      result[methodName] = [];
      return result;
    } else {
      Log.info('WaveInterpolationService', 'MAデータなし、フィルタ処理スキップ');
    }

    // 3. 最终插值或平滑处理
    Log.info('WaveInterpolationService', '最終処理開始: ${processedPoints.length}個の点');
    
    if (methodName.endsWith('Chaikin')) {
      Log.info('WaveInterpolationService', 'Chaikin補間実行');
      result[methodName] = chaikinInterpolation(processedPoints, iterations: 2);
    } else if (methodName.endsWith('CatmullRom')) {
      Log.info('WaveInterpolationService', 'Catmull-Rom補間実行');
      result[methodName] = catmullRomInterpolation(processedPoints, segmentsPerInterval: 8);
    } else if (methodName.endsWith('Linear')) {
      Log.info('WaveInterpolationService', '線形補間実行');
      result[methodName] = linearInterpolation(processedPoints, segmentsPerInterval: 5);
    } else if (methodName.endsWith('Geometric')) {
      Log.info('WaveInterpolationService', '幾何平滑化実行');
      result[methodName] = geometricSmoothing(processedPoints, smoothingFactor: 0.3);
    } else if (methodName.endsWith('Statistical')) {
      Log.info('WaveInterpolationService', '統計平滑化実行');
      result[methodName] = statisticalSmoothing(processedPoints, windowSize: 5);
    } else if (methodName.endsWith('Hybrid')) {
      Log.info('WaveInterpolationService', 'ハイブリッド平滑化実行');
      result[methodName] = hybridSmoothing(processedPoints, geometricWeight: 0.6, statisticalWeight: 0.4);
    } else {
      Log.info('WaveInterpolationService', 'デフォルト処理実行');
      // 如果没有插值/平滑后缀 (例如 'filtered', 'denoised', 'maTrend')
      // 则直接返回处理后的点集
      // Also handle base methods like 'original', 'chaikin', 'catmullRom', 'linear'
      switch (methodName) {
        case 'original': result[methodName] = originalPoints; break;
        case 'filtered': result[methodName] = basePoints; break;
        case 'chaikin': result[methodName] = chaikinInterpolation(basePoints, iterations: 2); break;
        case 'catmullRom': result[methodName] = catmullRomInterpolation(basePoints, segmentsPerInterval: 8); break;
        case 'linear': result[methodName] = linearInterpolation(basePoints, segmentsPerInterval: 5); break;
        default: result[methodName] = processedPoints; break;
      }
    }
    
    Log.info('WaveInterpolationService', '方法生成詳細: $methodName -> ${result[methodName]?.length ?? 0}個の点');

    Log.info('WaveInterpolationService', '按需生成完成，方法: $methodName, 点数: ${result[methodName]?.length ?? 0}');
    return result;
  }

  /// フォーマットされた波線を生成（WavePoints版）
  /// フィルタリングと補間を組み合わせ
  static Map<String, List<WavePoint>> generateFormattedWavesFromWavePoints(
    WavePoints wavePoints,
    List<PriceData> priceDataList, {
    List<double>? maValues,
    int maPeriod = 150,
    String? selectedMethod, // 只生成选择的方法
  }) {
    Log.info('WaveInterpolationService', 'フォーマット波線生成（WavePoints版）開始: ${wavePoints.mergedPoints.length}個の点, 選択方法=$selectedMethod, MAデータ=${maValues != null ? "あり" : "なし"}');
    final stopwatch = Stopwatch()..start();
    
    // 如果指定了选择的方法，只生成该方法以提高性能
    if (selectedMethod != null) {
      final result = _generateSingleMethod(selectedMethod, wavePoints, priceDataList, maValues, maPeriod);
      stopwatch.stop();
      Log.info('WaveInterpolationService', 'フォーマット波線生成（WavePoints版）完了（単一方法）: ${result.length}個の方法生成 (${stopwatch.elapsedMilliseconds}ms)');
      Log.info('WaveInterpolationService', '選択方法「$selectedMethod」の結果: ${result[selectedMethod]?.length ?? 0}個の点');
      return result;
    }
    
    // WavePointsからWavePointリストへ変換
    final originalPoints = _convertWavePointsToWavePointList(wavePoints, priceDataList);
    
    // 既存のメソッドを呼び出し
    final result = generateFormattedWaves(
      originalPoints,
      maValues: maValues,
      maPeriod: maPeriod,
      selectedMethod: selectedMethod,
    );
    
    stopwatch.stop();
    Log.info('WaveInterpolationService', 'フォーマット波線生成（WavePoints版）完了: ${result.length}個の方法生成 (${stopwatch.elapsedMilliseconds}ms)');
    Log.info('WaveInterpolationService', '選択方法「$selectedMethod」の結果: ${result[selectedMethod]?.length ?? 0}個の点');
    return result;
  }

   /// 按需生成单一的格式化波浪方法
  static Map<String, List<WavePoint>> _generateSingleMethod(
    String methodName,
    WavePoints wavePoints,
    List<PriceData> priceDataList,
    List<double>? maValues,
    int maPeriod,
  ) {
      // WavePointsからWavePointリストへ変換
      final originalPoints = _convertWavePointsToWavePointList(wavePoints, priceDataList);

      return _generateSingleMethodFromWavePoints(
        methodName,
        originalPoints,
        maValues,
        maPeriod,
      );
  }

  /// フォーマットされた波線を生成
  /// フィルタリングと補間を組み合わせ
  static Map<String, List<WavePoint>> generateFormattedWaves(
    List<WavePoint> originalPoints, {
    List<double>? maValues,
    int maPeriod = 150,
    String? selectedMethod, // 只生成选择的方法
  }) {
    Log.info('WaveInterpolationService', 'フォーマット波線生成開始: ${originalPoints.length}個の点, 選択方法=$selectedMethod, MAデータ=${maValues != null ? "あり" : "なし"}');
    final stopwatch = Stopwatch()..start();
    
    // 如果指定了选择的方法，只生成该方法以提高性能
    if (selectedMethod != null) {
      final result = _generateSingleMethodFromWavePoints(selectedMethod, originalPoints, maValues, maPeriod);
      stopwatch.stop();
      Log.info('WaveInterpolationService', 'フォーマット波線生成完了（単一方法）: ${result.length}個の方法生成 (${stopwatch.elapsedMilliseconds}ms)');
      return result;
    }

    // --- Fallback: Generate all methods if no specific one is selected ---
    // まず小さな波をフィルタリング
    final filteredPoints = filterSmallWaves(originalPoints, minPriceChange: 0.0001);
    
    // ノイズ除去アルゴリズムを適用
    final denoisedPoints = WaveDenoisingService.denoiseWavePoints(filteredPoints);
    
    // フラクタルフィルタリングを適用
    final fractalFiltered = fractalFiltering(filteredPoints, fractalThreshold: 0.618);
    final denoisedFractal = fractalFiltering(denoisedPoints, fractalThreshold: 0.618);
    
    // MAトレンドフィルタリングを適用（MAデータがある場合）
    List<WavePoint> maTrendFiltered = filteredPoints;
    List<WavePoint> denoisedMaTrend = denoisedPoints;
    List<WavePoint> continuousWeightFiltered = filteredPoints;
    List<WavePoint> denoisedContinuousWeight = denoisedPoints;
    List<WavePoint> nStructureFiltered = filteredPoints;
    List<WavePoint> denoisedNStructure = denoisedPoints;
    if (maValues != null) {
      maTrendFiltered = maTrendFiltering(filteredPoints, maValues, maPeriod: maPeriod);
      denoisedMaTrend = maTrendFiltering(denoisedPoints, maValues, maPeriod: maPeriod);
      
      // 連続重みフィルタリングを適用
      continuousWeightFiltered = continuousWeightFiltering(filteredPoints, maValues, maPeriod: maPeriod);
      denoisedContinuousWeight = continuousWeightFiltering(denoisedPoints, maValues, maPeriod: maPeriod);
      
      // N字構造分析を適用
      nStructureFiltered = nStructureAnalysis(filteredPoints, maValues, maPeriod: maPeriod);
      denoisedNStructure = nStructureAnalysis(denoisedPoints, maValues, maPeriod: maPeriod);
    }

    // 異なる補間方法の波線を生成
    final chaikinWaves = chaikinInterpolation(filteredPoints, iterations: 2);
    final catmullRomWaves = catmullRomInterpolation(filteredPoints, segmentsPerInterval: 8);
    final linearWaves = linearInterpolation(filteredPoints, segmentsPerInterval: 5);
    
    // ノイズ除去後のポイントも補間
    final denoisedChaikin = chaikinInterpolation(denoisedPoints, iterations: 2);
    final denoisedCatmullRom = catmullRomInterpolation(denoisedPoints, segmentsPerInterval: 8);
    final denoisedLinear = linearInterpolation(denoisedPoints, segmentsPerInterval: 5);
    
    // フラクタルフィルタリング後のポイントを補間
    final fractalChaikin = chaikinInterpolation(fractalFiltered, iterations: 2);
    final fractalCatmullRom = catmullRomInterpolation(fractalFiltered, segmentsPerInterval: 8);
    final fractalLinear = linearInterpolation(fractalFiltered, segmentsPerInterval: 5);
    
    // ノイズ除去+フラクタルフィルタリング後のポイントを補間
    final denoisedFractalChaikin = chaikinInterpolation(denoisedFractal, iterations: 2);
    final denoisedFractalCatmullRom = catmullRomInterpolation(denoisedFractal, segmentsPerInterval: 8);
    final denoisedFractalLinear = linearInterpolation(denoisedFractal, segmentsPerInterval: 5);
    
    // 新規幾何/統計平滑化方法
    final geometricSmoothed = geometricSmoothing(filteredPoints, smoothingFactor: 0.3);
    final statisticalSmoothed = statisticalSmoothing(filteredPoints, windowSize: 5);
    final hybridSmoothed = hybridSmoothing(filteredPoints, geometricWeight: 0.6, statisticalWeight: 0.4);
    
    // ノイズ除去後のポイントも幾何/統計平滑化
    final denoisedGeometric = geometricSmoothing(denoisedPoints, smoothingFactor: 0.3);
    final denoisedStatistical = statisticalSmoothing(denoisedPoints, windowSize: 5);
    final denoisedHybrid = hybridSmoothing(denoisedPoints, geometricWeight: 0.6, statisticalWeight: 0.4);
    
    // フラクタルフィルタリング後のポイントを幾何/統計平滑化
    final fractalGeometric = geometricSmoothing(fractalFiltered, smoothingFactor: 0.3);
    final fractalStatistical = statisticalSmoothing(fractalFiltered, windowSize: 5);
    final fractalHybrid = hybridSmoothing(fractalFiltered, geometricWeight: 0.6, statisticalWeight: 0.4);
    
    // ノイズ除去+フラクタルフィルタリング後のポイントを幾何/統計平滑化
    final denoisedFractalGeometric = geometricSmoothing(denoisedFractal, smoothingFactor: 0.3);
    final denoisedFractalStatistical = statisticalSmoothing(denoisedFractal, windowSize: 5);
    final denoisedFractalHybrid = hybridSmoothing(denoisedFractal, geometricWeight: 0.6, statisticalWeight: 0.4);
    
    // MAトレンドフィルタリング後のポイントを補間
    final maTrendChaikin = chaikinInterpolation(maTrendFiltered, iterations: 2);
    final maTrendCatmullRom = catmullRomInterpolation(maTrendFiltered, segmentsPerInterval: 8);
    final maTrendLinear = linearInterpolation(maTrendFiltered, segmentsPerInterval: 5);
    
    // ノイズ除去+MAトレンドフィルタリング後のポイントを補間
    final denoisedMaTrendChaikin = chaikinInterpolation(denoisedMaTrend, iterations: 2);
    final denoisedMaTrendCatmullRom = catmullRomInterpolation(denoisedMaTrend, segmentsPerInterval: 8);
    final denoisedMaTrendLinear = linearInterpolation(denoisedMaTrend, segmentsPerInterval: 5);
    
    // MAトレンドフィルタリング後のポイントを幾何/統計平滑化
    final maTrendGeometric = geometricSmoothing(maTrendFiltered, smoothingFactor: 0.3);
    final maTrendStatistical = statisticalSmoothing(maTrendFiltered, windowSize: 5);
    final maTrendHybrid = hybridSmoothing(maTrendFiltered, geometricWeight: 0.6, statisticalWeight: 0.4);
    
    // ノイズ除去+MAトレンドフィルタリング後のポイントを幾何/統計平滑化
    final denoisedMaTrendGeometric = geometricSmoothing(denoisedMaTrend, smoothingFactor: 0.3);
    final denoisedMaTrendStatistical = statisticalSmoothing(denoisedMaTrend, windowSize: 5);
    final denoisedMaTrendHybrid = hybridSmoothing(denoisedMaTrend, geometricWeight: 0.6, statisticalWeight: 0.4);
    
    // 連続重みフィルタリング後のポイントを補間
    final continuousWeightChaikin = chaikinInterpolation(continuousWeightFiltered, iterations: 2);
    final continuousWeightCatmullRom = catmullRomInterpolation(continuousWeightFiltered, segmentsPerInterval: 8);
    final continuousWeightLinear = linearInterpolation(continuousWeightFiltered, segmentsPerInterval: 5);
    
    // ノイズ除去+連続重みフィルタリング後のポイントを補間
    final denoisedContinuousWeightChaikin = chaikinInterpolation(denoisedContinuousWeight, iterations: 2);
    final denoisedContinuousWeightCatmullRom = catmullRomInterpolation(denoisedContinuousWeight, segmentsPerInterval: 8);
    final denoisedContinuousWeightLinear = linearInterpolation(denoisedContinuousWeight, segmentsPerInterval: 5);
    
    // 連続重みフィルタリング後のポイントを幾何/統計平滑化
    final continuousWeightGeometric = geometricSmoothing(continuousWeightFiltered, smoothingFactor: 0.3);
    final continuousWeightStatistical = statisticalSmoothing(continuousWeightFiltered, windowSize: 5);
    final continuousWeightHybrid = hybridSmoothing(continuousWeightFiltered, geometricWeight: 0.6, statisticalWeight: 0.4);
    
    // ノイズ除去+連続重みフィルタリング後のポイントを幾何/統計平滑化
    final denoisedContinuousWeightGeometric = geometricSmoothing(denoisedContinuousWeight, smoothingFactor: 0.3);
    final denoisedContinuousWeightStatistical = statisticalSmoothing(denoisedContinuousWeight, windowSize: 5);
    final denoisedContinuousWeightHybrid = hybridSmoothing(denoisedContinuousWeight, geometricWeight: 0.6, statisticalWeight: 0.4);
    
    // N字構造分析後のポイントを補間
    final nStructureChaikin = chaikinInterpolation(nStructureFiltered, iterations: 2);
    final nStructureCatmullRom = catmullRomInterpolation(nStructureFiltered, segmentsPerInterval: 8);
    final nStructureLinear = linearInterpolation(nStructureFiltered, segmentsPerInterval: 5);
    
    // ノイズ除去+N字構造分析後のポイントを補間
    final denoisedNStructureChaikin = chaikinInterpolation(denoisedNStructure, iterations: 2);
    final denoisedNStructureCatmullRom = catmullRomInterpolation(denoisedNStructure, segmentsPerInterval: 8);
    final denoisedNStructureLinear = linearInterpolation(denoisedNStructure, segmentsPerInterval: 5);
    
    // N字構造分析後のポイントを幾何/統計平滑化
    final nStructureGeometric = geometricSmoothing(nStructureFiltered, smoothingFactor: 0.3);
    final nStructureStatistical = statisticalSmoothing(nStructureFiltered, windowSize: 5);
    final nStructureHybrid = hybridSmoothing(nStructureFiltered, geometricWeight: 0.6, statisticalWeight: 0.4);
    
    // ノイズ除去+N字構造分析後のポイントを幾何/統計平滑化
    final denoisedNStructureGeometric = geometricSmoothing(denoisedNStructure, smoothingFactor: 0.3);
    final denoisedNStructureStatistical = statisticalSmoothing(denoisedNStructure, windowSize: 5);
    final denoisedNStructureHybrid = hybridSmoothing(denoisedNStructure, geometricWeight: 0.6, statisticalWeight: 0.4);
    
    final result = {
      'original': originalPoints,
      'filtered': filteredPoints,
      'denoised': denoisedPoints,
      'fractal': fractalFiltered,
      'denoisedFractal': denoisedFractal,
      'chaikin': chaikinWaves,
      'catmullRom': catmullRomWaves,
      'linear': linearWaves,
      'denoisedChaikin': denoisedChaikin,
      'denoisedCatmullRom': denoisedCatmullRom,
      'denoisedLinear': denoisedLinear,
      'fractalChaikin': fractalChaikin,
      'fractalCatmullRom': fractalCatmullRom,
      'fractalLinear': fractalLinear,
      'denoisedFractalChaikin': denoisedFractalChaikin,
      'denoisedFractalCatmullRom': denoisedFractalCatmullRom,
      'denoisedFractalLinear': denoisedFractalLinear,
      'geometric': geometricSmoothed,
      'statistical': statisticalSmoothed,
      'hybrid': hybridSmoothed,
      'denoisedGeometric': denoisedGeometric,
      'denoisedStatistical': denoisedStatistical,
      'denoisedHybrid': denoisedHybrid,
      'fractalGeometric': fractalGeometric,
      'fractalStatistical': fractalStatistical,
      'fractalHybrid': fractalHybrid,
      'denoisedFractalGeometric': denoisedFractalGeometric,
      'denoisedFractalStatistical': denoisedFractalStatistical,
      'denoisedFractalHybrid': denoisedFractalHybrid,
    };
    
    // MAデータがある場合、MAトレンドフィルタリングと連続重みフィルタリングの結果を追加
    if (maValues != null) {
      result.addAll({
        'maTrend': maTrendFiltered,
        'denoisedMaTrend': denoisedMaTrend,
        'maTrendChaikin': maTrendChaikin,
        'maTrendCatmullRom': maTrendCatmullRom,
        'maTrendLinear': maTrendLinear,
        'denoisedMaTrendChaikin': denoisedMaTrendChaikin,
        'denoisedMaTrendCatmullRom': denoisedMaTrendCatmullRom,
        'denoisedMaTrendLinear': denoisedMaTrendLinear,
        'maTrendGeometric': maTrendGeometric,
        'maTrendStatistical': maTrendStatistical,
        'maTrendHybrid': maTrendHybrid,
        'denoisedMaTrendGeometric': denoisedMaTrendGeometric,
        'denoisedMaTrendStatistical': denoisedMaTrendStatistical,
        'denoisedMaTrendHybrid': denoisedMaTrendHybrid,
        'continuousWeight': continuousWeightFiltered,
        'denoisedContinuousWeight': denoisedContinuousWeight,
        'continuousWeightChaikin': continuousWeightChaikin,
        'continuousWeightCatmullRom': continuousWeightCatmullRom,
        'continuousWeightLinear': continuousWeightLinear,
        'denoisedContinuousWeightChaikin': denoisedContinuousWeightChaikin,
        'denoisedContinuousWeightCatmullRom': denoisedContinuousWeightCatmullRom,
        'denoisedContinuousWeightLinear': denoisedContinuousWeightLinear,
        'continuousWeightGeometric': continuousWeightGeometric,
        'continuousWeightStatistical': continuousWeightStatistical,
        'continuousWeightHybrid': continuousWeightHybrid,
        'denoisedContinuousWeightGeometric': denoisedContinuousWeightGeometric,
        'denoisedContinuousWeightStatistical': denoisedContinuousWeightStatistical,
        'denoisedContinuousWeightHybrid': denoisedContinuousWeightHybrid,
        'nStructure': nStructureFiltered,
        'denoisedNStructure': denoisedNStructure,
        'nStructureChaikin': nStructureChaikin,
        'nStructureCatmullRom': nStructureCatmullRom,
        'nStructureLinear': nStructureLinear,
        'denoisedNStructureChaikin': denoisedNStructureChaikin,
        'denoisedNStructureCatmullRom': denoisedNStructureCatmullRom,
        'denoisedNStructureLinear': denoisedNStructureLinear,
        'nStructureGeometric': nStructureGeometric,
        'nStructureStatistical': nStructureStatistical,
        'nStructureHybrid': nStructureHybrid,
        'denoisedNStructureGeometric': denoisedNStructureGeometric,
        'denoisedNStructureStatistical': denoisedNStructureStatistical,
        'denoisedNStructureHybrid': denoisedNStructureHybrid,
      });
    }
    
    return result;
  }
}


/// トレンド方向列挙
enum TrendDirection {
  upward,
  downward,
  neutral;
  
  bool get isConsistent => this != TrendDirection.neutral;
}

/// 市場状態列挙
enum MarketState {
  trending,   // トレンド市場
  ranging,    // レンジ市場
  volatile,   // ボラティリティ市場
}
