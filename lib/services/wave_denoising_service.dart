import 'dart:math';
import '../models/wave_point.dart';
import 'log_service.dart';

/// 波ノイズ除去サービス
/// 信号処理とロバスト統計に基づくノイズ除去アルゴリズム
class WaveDenoisingService {
  
  /// ノイズ除去設定パラメータ
  static const int _windowSize = 6; // 候補点ウィンドウサイズ
  static const double _outlierThreshold = 2.5; // 外れ値閾値（MAD倍数）
  static const int _polynomialDegree = 2; // 多項式フィット次数
  static const double _loessBandwidth = 0.3; // LOESS帯域幅パラメータ
  
  /// 主要ノイズ除去方法
  static List<WavePoint> denoiseWavePoints(List<WavePoint> originalPoints) {
    if (originalPoints.length < _windowSize) {
      Log.warning('WaveDenoisingService', 'データポイントが少なすぎてノイズ除去できません: ${originalPoints.length}');
      return originalPoints;
    }
    
    try {
      // 1. 候補高低点を抽出
      final candidates = _extractCandidatePoints(originalPoints);
      Log.info('WaveDenoisingService', '候補点を抽出: ${candidates.length}個');
      
      if (candidates.length < 3) {
        Log.warning('WaveDenoisingService', '候補点が少なすぎるため、元のデータを返します');
        return originalPoints;
      }
      
      // 2. 参考曲線をフィット
      final fittedCurve = _fitReferenceCurve(candidates);
      Log.info('WaveDenoisingService', '参考曲線フィット完了');
      
      // 3. 残差を計算して外れ値を検出
      final significantPoints = _detectSignificantPoints(candidates, fittedCurve);
      Log.info('WaveDenoisingService', '有意な点を検出: ${significantPoints.length}個');
      
      // 4. ノイズ除去後の波線を生成
      final denoisedPoints = _generateDenoisedWave(significantPoints, originalPoints);
      Log.info('WaveDenoisingService', 'ノイズ除去完了: ${originalPoints.length} -> ${denoisedPoints.length} 点');
      
      return denoisedPoints;
    } catch (e) {
      Log.error('WaveDenoisingService', 'ノイズ除去プロセスでエラーが発生: $e');
      return originalPoints;
    }
  }
  
  /// 1. 候補高低点を抽出（局所極値）
  static List<WavePoint> _extractCandidatePoints(List<WavePoint> points) {
    List<WavePoint> candidates = [];
    
    for (int i = 1; i < points.length - 1; i++) {
      final current = points[i];
      final prev = points[i - 1];
      final next = points[i + 1];
      
      // 检测局部极值
      bool isLocalExtremum = false;
      String extremumType = '';
      
      if (current.type == 'high') {
        // 高点：当前点比前后点都高
        isLocalExtremum = current.price > prev.price && current.price > next.price;
        extremumType = 'high';
      } else if (current.type == 'low') {
        // 低点：当前点比前后点都低
        isLocalExtremum = current.price < prev.price && current.price < next.price;
        extremumType = 'low';
      }
      
      if (isLocalExtremum) {
        candidates.add(WavePoint(
          timestamp: current.timestamp,
          price: current.price,
          type: extremumType,
        ));
      }
    }
    
    return candidates;
  }
  
  /// 2. 拟合参考曲线（多种方法）
  static FittedCurve _fitReferenceCurve(List<WavePoint> candidates) {
    // 尝试多种拟合方法，选择最佳
    final polynomialCurve = _fitPolynomialCurve(candidates);
    final loessCurve = _fitLoessCurve(candidates);
    
    // 选择拟合误差最小的方法
    final polynomialError = _calculateFittingError(candidates, polynomialCurve);
    final loessError = _calculateFittingError(candidates, loessCurve);
    
    if (polynomialError <= loessError) {
      Log.info('WaveDenoisingService', '选择多项式拟合 (误差: $polynomialError)');
      return polynomialCurve;
    } else {
      Log.info('WaveDenoisingService', '选择LOESS拟合 (误差: $loessError)');
      return loessCurve;
    }
  }
  
  /// 多项式拟合
  static FittedCurve _fitPolynomialCurve(List<WavePoint> points) {
    final x = points.map((p) => p.timestamp.toDouble()).toList();
    final y = points.map((p) => p.price).toList();
    
    // 使用最小二乘法拟合多项式
    final coefficients = _polynomialLeastSquares(x, y, _polynomialDegree);
    
    return FittedCurve(
      type: 'polynomial',
      coefficients: coefficients,
      points: points,
    );
  }
  
  /// LOESS拟合（局部加权回归）
  static FittedCurve _fitLoessCurve(List<WavePoint> points) {
    final n = points.length;
    final x = points.map((p) => p.timestamp.toDouble()).toList();
    final y = points.map((p) => p.price).toList();
    
    // 计算每个点的LOESS拟合值
    List<double> fittedValues = [];
    
    for (int i = 0; i < n; i++) {
      final fittedValue = _loessFit(x[i], x, y, _loessBandwidth);
      fittedValues.add(fittedValue);
    }
    
    return FittedCurve(
      type: 'loess',
      fittedValues: fittedValues,
      points: points,
    );
  }
  
  /// 3. 检测显著点（离群点检测）
  static List<WavePoint> _detectSignificantPoints(List<WavePoint> candidates, FittedCurve curve) {
    // 计算残差
    List<double> residuals = [];
    for (int i = 0; i < candidates.length; i++) {
      final point = candidates[i];
      final fittedValue = _getFittedValue(point.timestamp, curve);
      final residual = (point.price - fittedValue).abs();
      residuals.add(residual);
    }
    
    // 使用MAD（中位数绝对偏差）检测离群点
    final mad = _calculateMAD(residuals);
    final threshold = _outlierThreshold * mad;
    
    List<WavePoint> significantPoints = [];
    for (int i = 0; i < candidates.length; i++) {
      if (residuals[i] > threshold) {
        significantPoints.add(candidates[i]);
      }
    }
    
    Log.info('WaveDenoisingService', 'MAD: $mad, 阈值: $threshold, 显著点: ${significantPoints.length}/${candidates.length}');
    
    return significantPoints;
  }
  
  /// 4. 生成去噪后的波浪线
  static List<WavePoint> _generateDenoisedWave(List<WavePoint> significantPoints, List<WavePoint> originalPoints) {
    if (significantPoints.isEmpty) {
      return originalPoints;
    }
    
    // 按时间排序
    significantPoints.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    // 在显著点之间进行插值
    List<WavePoint> denoisedPoints = [];
    
    for (int i = 0; i < significantPoints.length - 1; i++) {
      final current = significantPoints[i];
      final next = significantPoints[i + 1];
      
      // 添加当前显著点
      denoisedPoints.add(current);
      
      // 在两点之间插值
      final interpolatedPoints = _interpolateBetweenPoints(current, next);
      denoisedPoints.addAll(interpolatedPoints);
    }
    
    // 添加最后一个点
    if (significantPoints.isNotEmpty) {
      denoisedPoints.add(significantPoints.last);
    }
    
    return denoisedPoints;
  }
  
  /// 辅助方法：多项式最小二乘拟合
  static List<double> _polynomialLeastSquares(List<double> x, List<double> y, int degree) {
    final n = x.length;
    final m = degree + 1;
    
    // 构建范德蒙德矩阵
    // ignore: non_constant_identifier_names
    List<List<double>> A = [];
    for (int i = 0; i < n; i++) {
      List<double> row = [];
      for (int j = 0; j < m; j++) {
        row.add(pow(x[i], j).toDouble());
      }
      A.add(row);
    }
    
    // 使用正规方程求解：A^T * A * c = A^T * y
    // ignore: non_constant_identifier_names
    List<List<double>> AtA = List.generate(m, (_) => List.filled(m, 0.0));
    // ignore: non_constant_identifier_names
    List<double> Aty = List.filled(m, 0.0);
    
    for (int i = 0; i < m; i++) {
      for (int j = 0; j < m; j++) {
        for (int k = 0; k < n; k++) {
          AtA[i][j] += A[k][i] * A[k][j];
        }
      }
      for (int k = 0; k < n; k++) {
        Aty[i] += A[k][i] * y[k];
      }
    }
    
    // 求解线性方程组（使用高斯消元法）
    return _solveLinearSystem(AtA, Aty);
  }
  
  /// 辅助方法：LOESS拟合
  static double _loessFit(double x, List<double> xData, List<double> yData, double bandwidth) {
    final n = xData.length;
    final h = bandwidth * (xData.last - xData.first);
    
    double numerator = 0.0;
    double denominator = 0.0;
    
    for (int i = 0; i < n; i++) {
      final distance = (x - xData[i]).abs();
      if (distance <= h) {
        final weight = _tricubeWeight(distance / h);
        numerator += weight * yData[i];
        denominator += weight;
      }
    }
    
    return denominator > 0 ? numerator / denominator : 0.0;
  }
  
  /// 三立方权重函数
  static double _tricubeWeight(double u) {
    if (u >= 1.0) return 0.0;
    final t = 1.0 - u * u * u;
    return t * t * t;
  }
  
  /// 计算拟合误差
  static double _calculateFittingError(List<WavePoint> points, FittedCurve curve) {
    double totalError = 0.0;
    for (final point in points) {
      final fittedValue = _getFittedValue(point.timestamp, curve);
      totalError += (point.price - fittedValue) * (point.price - fittedValue);
    }
    return sqrt(totalError / points.length);
  }
  
  /// 获取拟合值
  static double _getFittedValue(int timestamp, FittedCurve curve) {
    if (curve.type == 'polynomial') {
      double value = 0.0;
      for (int i = 0; i < curve.coefficients!.length; i++) {
        value += curve.coefficients![i] * pow(timestamp, i).toDouble();
      }
      return value;
    } else if (curve.type == 'loess') {
      // 对于LOESS，需要找到最接近的时间戳
      final x = curve.points.map((p) => p.timestamp.toDouble()).toList();
      final y = curve.fittedValues!;
      
      // 简单线性插值
      for (int i = 0; i < x.length - 1; i++) {
        if (timestamp >= x[i] && timestamp <= x[i + 1]) {
          final t = (timestamp - x[i]) / (x[i + 1] - x[i]);
          return y[i] + t * (y[i + 1] - y[i]);
        }
      }
      return y.first;
    }
    return 0.0;
  }
  
  /// 计算中位数绝对偏差（MAD）
  static double _calculateMAD(List<double> values) {
    if (values.isEmpty) return 0.0;
    
    // 计算中位数
    final sorted = List<double>.from(values)..sort();
    final median = sorted.length % 2 == 0
        ? (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2
        : sorted[sorted.length ~/ 2];
    
    // 计算绝对偏差
    final deviations = values.map((v) => (v - median).abs()).toList();
    deviations.sort();
    
    // 返回MAD
    return deviations.length % 2 == 0
        ? (deviations[deviations.length ~/ 2 - 1] + deviations[deviations.length ~/ 2]) / 2
        : deviations[deviations.length ~/ 2];
  }
  
  /// 在两点之间插值
  static List<WavePoint> _interpolateBetweenPoints(WavePoint p1, WavePoint p2) {
    List<WavePoint> interpolated = [];
    
    final timeDiff = p2.timestamp - p1.timestamp;
    final priceDiff = p2.price - p1.price;
    
    // 如果时间间隔太大，添加插值点
    if (timeDiff > 1000) { // 假设时间戳单位是秒
      final steps = (timeDiff / 500).round(); // 每500秒一个点
      for (int i = 1; i < steps; i++) {
        final t = p1.timestamp + (timeDiff * i / steps).round();
        final price = p1.price + (priceDiff * i / steps);
        final type = (p1.type == p2.type) ? p1.type : 'interpolated';
        
        interpolated.add(WavePoint(
          timestamp: t,
          price: price,
          type: type,
        ));
      }
    }
    
    return interpolated;
  }
  
  /// 求解线性方程组（高斯消元法）
  // ignore: non_constant_identifier_names
  static List<double> _solveLinearSystem(List<List<double>> A, List<double> b) {
    final n = A.length;
    final augmented = List.generate(n, (i) => [...A[i], b[i]]);
    
    // 前向消元
    for (int i = 0; i < n; i++) {
      // 找到主元
      int maxRow = i;
      for (int k = i + 1; k < n; k++) {
        if (augmented[k][i].abs() > augmented[maxRow][i].abs()) {
          maxRow = k;
        }
      }
      
      // 交换行
      if (maxRow != i) {
        final temp = augmented[i];
        augmented[i] = augmented[maxRow];
        augmented[maxRow] = temp;
      }
      
      // 消元
      for (int k = i + 1; k < n; k++) {
        final factor = augmented[k][i] / augmented[i][i];
        for (int j = i; j <= n; j++) {
          augmented[k][j] -= factor * augmented[i][j];
        }
      }
    }
    
    // 回代
    final x = List.filled(n, 0.0);
    for (int i = n - 1; i >= 0; i--) {
      x[i] = augmented[i][n];
      for (int j = i + 1; j < n; j++) {
        x[i] -= augmented[i][j] * x[j];
      }
      x[i] /= augmented[i][i];
    }
    
    return x;
  }
}

/// 拟合曲线数据类
class FittedCurve {
  final String type;
  final List<double>? coefficients; // 多项式系数
  final List<double>? fittedValues; // LOESS拟合值
  final List<WavePoint> points;
  
  FittedCurve({
    required this.type,
    this.coefficients,
    this.fittedValues,
    required this.points,
  });
}
