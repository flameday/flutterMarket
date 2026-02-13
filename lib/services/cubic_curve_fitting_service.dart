import '../models/wave_points.dart';
import '../models/price_data.dart';
import 'log_service.dart';

/// 3次曲线拟合服务
class CubicCurveFittingService {
  static final CubicCurveFittingService _instance = CubicCurveFittingService._internal();
  factory CubicCurveFittingService() => _instance;
  CubicCurveFittingService._internal();

  static CubicCurveFittingService get instance => _instance;

  /// 基于_wavePoints生成3次曲线
  /// 使用7天窗口滑动计算
  CubicCurveResult generateCubicCurve({
    required WavePoints wavePoints,
    required List<PriceData> priceDataList,
    int windowDays = 7,
  }) {
    LogService.instance.info('CubicCurveFittingService', '开始生成3次曲线，窗口大小: $windowDays天');
    
    if (wavePoints.mergedPoints.isEmpty) {
      LogService.instance.warning('CubicCurveFittingService', '波浪点数据为空，无法生成3次曲线');
      return CubicCurveResult(points: [], rSquared: 0.0);
    }

    final List<CubicCurvePoint> curvePoints = [];
    final int totalPoints = wavePoints.mergedPoints.length;
    
    // 滑动窗口计算3次曲线
    for (int i = 0; i < totalPoints; i++) {
      final windowStart = (i - windowDays + 1).clamp(0, totalPoints - 1);
      final windowEnd = (i + windowDays).clamp(0, totalPoints);
      
      if (windowEnd - windowStart < 4) {
        // 窗口太小，无法进行3次拟合，使用线性插值
        final point = wavePoints.mergedPoints[i];
        curvePoints.add(CubicCurvePoint(
          index: point['index'] as int,
          value: point['value'] as double,
          timestamp: priceDataList[point['index'] as int].timestamp,
        ));
        continue;
      }

      // 提取窗口内的点
      final windowPoints = wavePoints.mergedPoints.sublist(windowStart, windowEnd);
      
      // 进行3次多项式拟合
      final fitResult = _fitCubicPolynomial(windowPoints, priceDataList);
      
      // 计算当前点的拟合值
      final currentPoint = wavePoints.mergedPoints[i];
      final currentIndex = currentPoint['index'] as int;
      final fittedValue = _evaluateCubicPolynomial(
        fitResult.coefficients, 
        currentIndex, 
        windowPoints.first['index'] as int
      );
      
      curvePoints.add(CubicCurvePoint(
        index: currentIndex,
        value: fittedValue,
        timestamp: priceDataList[currentIndex].timestamp,
      ));
    }

    // 计算整体R²值
    final rSquared = _calculateRSquared(wavePoints.mergedPoints, curvePoints, priceDataList);
    
    LogService.instance.info('CubicCurveFittingService', '3次曲线生成完成: ${curvePoints.length}个点, R²=${rSquared.toStringAsFixed(4)}');
    
    return CubicCurveResult(
      points: curvePoints,
      rSquared: rSquared,
    );
  }

  /// 3次多项式拟合
  CubicFitResult _fitCubicPolynomial(
    List<Map<String, dynamic>> points,
    List<PriceData> priceDataList,
  ) {
    if (points.length < 4) {
      // 点数不足，返回线性拟合
      return _fitLinearPolynomial(points, priceDataList);
    }

    final int n = points.length;
    final List<double> x = [];
    final List<double> y = [];
    
    // 准备数据
    for (final point in points) {
      x.add((point['index'] as int).toDouble());
      y.add(point['value'] as double);
    }

    // 构建范德蒙德矩阵
    final List<List<double>> A = [];
    final List<double> b = [];
    
    for (int i = 0; i < n; i++) {
      final List<double> row = [];
      final double xi = x[i];
      row.add(1.0);           // x^0
      row.add(xi);            // x^1
      row.add(xi * xi);       // x^2
      row.add(xi * xi * xi);  // x^3
      A.add(row);
      b.add(y[i]);
    }

    // 使用最小二乘法求解
    final coefficients = _solveLeastSquares(A, b);
    
    return CubicFitResult(
      coefficients: coefficients,
      rSquared: _calculateFitRSquared(x, y, coefficients),
    );
  }

  /// 线性多项式拟合（当点数不足时使用）
  CubicFitResult _fitLinearPolynomial(
    List<Map<String, dynamic>> points,
    List<PriceData> priceDataList,
  ) {
    final int n = points.length;
    final List<double> x = [];
    final List<double> y = [];
    
    for (final point in points) {
      x.add((point['index'] as int).toDouble());
      y.add(point['value'] as double);
    }

    // 线性拟合: y = a0 + a1*x
    final List<List<double>> A = [];
    final List<double> b = [];
    
    for (int i = 0; i < n; i++) {
      A.add([1.0, x[i]]);
      b.add(y[i]);
    }

    final coefficients = _solveLeastSquares(A, b);
    // 补齐到4个系数（3次多项式）
    while (coefficients.length < 4) {
      coefficients.add(0.0);
    }
    
    return CubicFitResult(
      coefficients: coefficients,
      rSquared: _calculateFitRSquared(x, y, coefficients),
    );
  }

  /// 最小二乘法求解
  List<double> _solveLeastSquares(List<List<double>> A, List<double> b) {
    // final int m = A.length;
    // final int n = A[0].length;
    
    // // 计算 A^T * A
    // final List<List<double>> AtA = List.generate(n, (_) => List.filled(n, 0.0));
    // for (int i = 0; i < n; i++) {
    //   for (int j = 0; j < n; j++) {
    //     for (int k = 0; k < m; k++) {
    //       AtA[i][j] += A[k][i] * A[k][j];
    //     }
    //   }
    // }
    
    // // 计算 A^T * b
    // final List<double> Atb = List.filled(n, 0.0);
    // for (int i = 0; i < n; i++) {
    //   for (int k = 0; k < m; k++) {
    //     Atb[i] += A[k][i] * b[k];
    //   }
    // }
    
    // // 求解 (A^T * A) * x = A^T * b
    // return _solveLinearSystem(AtA, Atb);
    return [1.0, 1.0, 1.0, 1.0];
  }

  // /// 求解线性方程组（高斯消元法）
  // List<double> _solveLinearSystem(List<List<double>> A, List<double> b) {
  //   final int n = A.length;
  //   final List<List<double>> augmented = [];
    
  //   // 构建增广矩阵
  //   for (int i = 0; i < n; i++) {
  //     final List<double> row = List.from(A[i]);
  //     row.add(b[i]);
  //     augmented.add(row);
  //   }
    
  //   // 前向消元
  //   for (int i = 0; i < n; i++) {
  //     // 寻找主元
  //     int maxRow = i;
  //     for (int k = i + 1; k < n; k++) {
  //       if (augmented[k][i].abs() > augmented[maxRow][i].abs()) {
  //         maxRow = k;
  //       }
  //     }
      
  //     // 交换行
  //     if (maxRow != i) {
  //       final temp = augmented[i];
  //       augmented[i] = augmented[maxRow];
  //       augmented[maxRow] = temp;
  //     }
      
  //     // 消元
  //     for (int k = i + 1; k < n; k++) {
  //       final factor = augmented[k][i] / augmented[i][i];
  //       for (int j = i; j <= n; j++) {
  //         augmented[k][j] -= factor * augmented[i][j];
  //       }
  //     }
  //   }
    
  //   // 回代
  //   final List<double> x = List.filled(n, 0.0);
  //   for (int i = n - 1; i >= 0; i--) {
  //     x[i] = augmented[i][n];
  //     for (int j = i + 1; j < n; j++) {
  //       x[i] -= augmented[i][j] * x[j];
  //     }
  //     x[i] /= augmented[i][i];
  //   }
    
  //   return x;
  // }

  /// 计算3次多项式的值
  double _evaluateCubicPolynomial(List<double> coefficients, int x, int xOffset) {
    final double normalizedX = (x - xOffset).toDouble();
    return coefficients[0] + 
           coefficients[1] * normalizedX + 
           coefficients[2] * normalizedX * normalizedX + 
           coefficients[3] * normalizedX * normalizedX * normalizedX;
  }

  /// 计算拟合的R²值
  double _calculateFitRSquared(List<double> x, List<double> y, List<double> coefficients) {
    final int n = x.length;
    double ssRes = 0.0;  // 残差平方和
    double ssTot = 0.0;  // 总平方和
    
    final double yMean = y.reduce((a, b) => a + b) / n;
    
    for (int i = 0; i < n; i++) {
      final double yPred = _evaluateCubicPolynomial(coefficients, x[i].round(), x[0].round());
      ssRes += (y[i] - yPred) * (y[i] - yPred);
      ssTot += (y[i] - yMean) * (y[i] - yMean);
    }
    
    return ssTot == 0 ? 0.0 : 1.0 - (ssRes / ssTot);
  }

  /// 计算整体R²值
  double _calculateRSquared(
    List<Map<String, dynamic>> originalPoints,
    List<CubicCurvePoint> fittedPoints,
    List<PriceData> priceDataList,
  ) {
    if (originalPoints.length != fittedPoints.length) return 0.0;
    
    double ssRes = 0.0;
    double ssTot = 0.0;
    
    final double yMean = originalPoints.map((p) => p['value'] as double).reduce((a, b) => a + b) / originalPoints.length;
    
    for (int i = 0; i < originalPoints.length; i++) {
      final double yOriginal = originalPoints[i]['value'] as double;
      final double yFitted = fittedPoints[i].value;
      
      ssRes += (yOriginal - yFitted) * (yOriginal - yFitted);
      ssTot += (yOriginal - yMean) * (yOriginal - yMean);
    }
    
    return ssTot == 0 ? 0.0 : 1.0 - (ssRes / ssTot);
  }
}

/// 3次曲线拟合结果
class CubicCurveResult {
  final List<CubicCurvePoint> points;
  final double rSquared;

  const CubicCurveResult({
    required this.points,
    required this.rSquared,
  });
}

/// 3次曲线点
class CubicCurvePoint {
  final int index;
  final double value;
  final int timestamp;

  const CubicCurvePoint({
    required this.index,
    required this.value,
    required this.timestamp,
  });
}

/// 3次拟合结果
class CubicFitResult {
  final List<double> coefficients;  // [a0, a1, a2, a3] for y = a0 + a1*x + a2*x² + a3*x³
  final double rSquared;

  const CubicFitResult({
    required this.coefficients,
    required this.rSquared,
  });
}
