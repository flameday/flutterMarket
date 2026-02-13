import 'dart:math';
import '../models/price_data.dart';
import '../models/wave_point.dart';
import '../services/log_service.dart';

/// 曲线拟合服务
class CurveFittingService {
  static final CurveFittingService _instance = CurveFittingService._internal();
  factory CurveFittingService() => _instance;
  CurveFittingService._internal();

  static CurveFittingService get instance => _instance;

  /// 基于高低点的动态曲线拟合
  /// [wavePoints] 高低点数据
  /// [priceDataList] 价格数据
  /// [windowSize] 移动窗口大小（默认50个点）
  /// [polynomialDegree] 多项式次数（默认2次）
  /// [smoothingFactor] 平滑因子（0.0-1.0，默认0.3）
  List<Map<String, dynamic>> generateFittedCurve({
    required List<WavePoint> wavePoints,
    required List<PriceData> priceDataList,
    int windowSize = 50,
    int polynomialDegree = 2,
    double smoothingFactor = 0.3,
  }) {
    LogService.instance.info('CurveFittingService', '曲线拟合开始: ${wavePoints.length}个高低点, 窗口大小: $windowSize, 多项式次数: $polynomialDegree');

    if (wavePoints.length < 3) {
      LogService.instance.warning('CurveFittingService', '高低点数量不足，无法进行曲线拟合');
      return [];
    }

    final List<Map<String, dynamic>> fittedPoints = [];
    
    // 按时间排序
    final sortedPoints = List<WavePoint>.from(wavePoints)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 使用移动窗口进行局部拟合
    for (int i = 0; i < sortedPoints.length; i++) {
      final centerIndex = i;
      final startIndex = (centerIndex - windowSize ~/ 2).clamp(0, sortedPoints.length - 1);
      final endIndex = (centerIndex + windowSize ~/ 2).clamp(0, sortedPoints.length - 1);
      
      // 获取窗口内的点
      final windowPoints = sortedPoints.sublist(startIndex, endIndex + 1);
      
      if (windowPoints.length < polynomialDegree + 1) {
        // 如果窗口内点数不足，使用线性插值
        final point = sortedPoints[centerIndex];
        fittedPoints.add({
          'index': point.index ?? 0,
          'timestamp': point.timestamp,
          'value': point.price,
          'type': 'fitted',
          'method': 'linear',
        });
        continue;
      }

      // 进行多项式拟合
      final fittedValue = _polynomialFitting(
        windowPoints, 
        sortedPoints[centerIndex].index ?? 0,
        polynomialDegree,
        smoothingFactor,
      );

      if (fittedValue != null) {
        fittedPoints.add({
          'index': sortedPoints[centerIndex].index ?? 0,
          'timestamp': sortedPoints[centerIndex].timestamp,
          'value': fittedValue,
          'type': 'fitted',
          'method': 'polynomial',
        });
      }
    }

    LogService.instance.info('CurveFittingService', '曲线拟合完成: ${fittedPoints.length}个拟合点');
    return fittedPoints;
  }

  /// 多项式拟合
  double? _polynomialFitting(
    List<WavePoint> points,
    int targetIndex,
    int degree,
    double smoothingFactor,
  ) {
    if (points.length < degree + 1) return null;

    try {
      // 将索引转换为相对坐标（以目标点为中心）
      final List<List<double>> matrix = [];
      final List<double> values = [];
      
      for (final point in points) {
        final x = ((point.index ?? 0) - targetIndex).toDouble();
        final y = point.price;
        
        // 构建范德蒙德矩阵
        final List<double> row = [];
        for (int i = 0; i <= degree; i++) {
          row.add(pow(x, i).toDouble());
        }
        matrix.add(row);
        values.add(y);
      }

      // 使用最小二乘法求解
      final coefficients = _leastSquares(matrix, values);
      
      // 计算目标点的拟合值（x=0）
      double fittedValue = 0.0;
      for (int i = 0; i < coefficients.length; i++) {
        fittedValue += coefficients[i] * pow(0, i);
      }

      // 应用平滑因子
      final originalValue = points.firstWhere(
        (p) => (p.index ?? 0) == targetIndex,
        orElse: () => points[points.length ~/ 2],
      ).price;
      
      return fittedValue * (1 - smoothingFactor) + originalValue * smoothingFactor;
      
    } catch (e) {
      LogService.instance.error('CurveFittingService', '多项式拟合失败: $e');
      return null;
    }
  }

  /// 最小二乘法求解
  List<double> _leastSquares(List<List<double>> matrix, List<double> values) {
    final int m = matrix.length;
    final int n = matrix[0].length;
    
    // 构建正规方程 A^T * A * x = A^T * b
    final List<List<double>> ata = List.generate(n, (_) => List.filled(n, 0.0));
    final List<double> atb = List.filled(n, 0.0);
    
    // 计算 A^T * A
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        for (int k = 0; k < m; k++) {
          ata[i][j] += matrix[k][i] * matrix[k][j];
        }
      }
    }
    
    // 计算 A^T * b
    for (int i = 0; i < n; i++) {
      for (int k = 0; k < m; k++) {
        atb[i] += matrix[k][i] * values[k];
      }
    }
    
    // 使用高斯消元法求解
    return _gaussianElimination(ata, atb);
  }

  /// 高斯消元法
  List<double> _gaussianElimination(List<List<double>> matrix, List<double> values) {
    final int n = matrix.length;
    final List<List<double>> augmented = List.generate(n, (i) => 
      List.from(matrix[i])..add(values[i])
    );
    
    // 前向消元
    for (int i = 0; i < n; i++) {
      // 寻找主元
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
    final List<double> solution = List.filled(n, 0.0);
    for (int i = n - 1; i >= 0; i--) {
      solution[i] = augmented[i][n];
      for (int j = i + 1; j < n; j++) {
        solution[i] -= augmented[i][j] * solution[j];
      }
      solution[i] /= augmented[i][i];
    }
    
    return solution;
  }

  /// 生成基于移动平均的拟合曲线（更简单的方法）
  List<Map<String, dynamic>> generateMovingAverageFittedCurve({
    required List<WavePoint> wavePoints,
    required List<PriceData> priceDataList,
    int windowSize = 20,
    double smoothingFactor = 0.3,
  }) {
    LogService.instance.info('CurveFittingService', '移动平均拟合开始: ${wavePoints.length}个高低点, 窗口大小: $windowSize');

    if (wavePoints.length < windowSize) {
      LogService.instance.warning('CurveFittingService', '高低点数量不足，无法进行移动平均拟合');
      return [];
    }

    final List<Map<String, dynamic>> fittedPoints = [];
    
    // 按时间排序
    final sortedPoints = List<WavePoint>.from(wavePoints)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (int i = 0; i < sortedPoints.length; i++) {
      final startIndex = (i - windowSize ~/ 2).clamp(0, sortedPoints.length - windowSize);
      final endIndex = (startIndex + windowSize).clamp(0, sortedPoints.length);
      
      // 计算窗口内的平均值
      double sum = 0.0;
      int count = 0;
      
      for (int j = startIndex; j < endIndex; j++) {
        sum += sortedPoints[j].price;
        count++;
      }
      
      if (count > 0) {
        final averageValue = sum / count;
        final originalValue = sortedPoints[i].price;
        
        // 应用平滑因子
        final fittedValue = averageValue * (1 - smoothingFactor) + originalValue * smoothingFactor;
        
        fittedPoints.add({
          'index': sortedPoints[i].index ?? 0,
          'timestamp': sortedPoints[i].timestamp,
          'value': fittedValue,
          'type': 'fitted',
          'method': 'moving_average',
        });
      }
    }

    LogService.instance.info('CurveFittingService', '移动平均拟合完成: ${fittedPoints.length}个拟合点');
    return fittedPoints;
  }

  /// 生成基于样条插值的拟合曲线
  List<Map<String, dynamic>> generateSplineFittedCurve({
    required List<WavePoint> wavePoints,
    required List<PriceData> priceDataList,
    double smoothingFactor = 0.3,
  }) {
    LogService.instance.info('CurveFittingService', '样条插值拟合开始: ${wavePoints.length}个高低点');

    if (wavePoints.length < 3) {
      LogService.instance.warning('CurveFittingService', '高低点数量不足，无法进行样条插值拟合');
      return [];
    }

    final List<Map<String, dynamic>> fittedPoints = [];
    
    // 按时间排序
    final sortedPoints = List<WavePoint>.from(wavePoints)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 使用三次样条插值
    for (int i = 0; i < sortedPoints.length; i++) {
      final fittedValue = _cubicSplineInterpolation(sortedPoints, i, smoothingFactor);
      
      if (fittedValue != null) {
        fittedPoints.add({
          'index': sortedPoints[i].index ?? 0,
          'timestamp': sortedPoints[i].timestamp,
          'value': fittedValue,
          'type': 'fitted',
          'method': 'spline',
        });
      }
    }

    LogService.instance.info('CurveFittingService', '样条插值拟合完成: ${fittedPoints.length}个拟合点');
    return fittedPoints;
  }

  /// 三次样条插值
  double? _cubicSplineInterpolation(List<WavePoint> points, int targetIndex, double smoothingFactor) {
    if (targetIndex < 1 || targetIndex >= points.length - 1) {
      return points[targetIndex].price;
    }

    try {
      final p0 = points[targetIndex - 1];
      final p1 = points[targetIndex];
      final p2 = points[targetIndex + 1];
      
      // 简单的三次样条插值
      final x0 = (p0.index ?? 0).toDouble();
      final x1 = (p1.index ?? 0).toDouble();
      final x2 = (p2.index ?? 0).toDouble();
      final y0 = p0.price;
      final y1 = p1.price;
      final y2 = p2.price;
      
      // 计算插值系数
      final h1 = x1 - x0;
      final h2 = x2 - x1;
      
      if (h1 == 0 || h2 == 0) return y1;
      
      final d1 = (y1 - y0) / h1;
      final d2 = (y2 - y1) / h2;
      
      // 计算样条值
      final fittedValue = y1 + (d1 + d2) / 2 * h1 / 2;
      
      // 应用平滑因子
      return fittedValue * (1 - smoothingFactor) + y1 * smoothingFactor;
      
    } catch (e) {
      LogService.instance.error('CurveFittingService', '样条插值失败: $e');
      return points[targetIndex].price;
    }
  }
}
