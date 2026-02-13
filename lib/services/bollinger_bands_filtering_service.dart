import '../models/price_data.dart';
import '../services/log_service.dart';

/// 布林线过滤曲线结果
class BollingerBandsFilteredCurveResult {
  final List<Map<String, dynamic>> points;
  final int originalPointsCount;
  final int filteredPointsCount;
  final double filteringRate;

  BollingerBandsFilteredCurveResult({
    required this.points,
    required this.originalPointsCount,
    required this.filteredPointsCount,
  }) : filteringRate = originalPointsCount > 0 
      ? (originalPointsCount - filteredPointsCount) / originalPointsCount 
      : 0.0;
}

/// 布林线过滤服务
class BollingerBandsFilteringService {
  static final BollingerBandsFilteringService _instance = BollingerBandsFilteringService._internal();
  factory BollingerBandsFilteringService() => _instance;
  BollingerBandsFilteringService._internal();

  static BollingerBandsFilteringService get instance => _instance;

  /// 基于布林通道过滤高低点
  BollingerBandsFilteredCurveResult filterWavePointsByBollingerBands({
    required List<Map<String, dynamic>> wavePoints,
    required List<PriceData> priceDataList,
    required Map<String, List<double>> bollingerBands,
    int bbPeriod = 20,
    double bbStdDev = 1.3,
  }) {
    LogService.instance.info('BollingerBandsFilteringService', 
      '布林线过滤开始: ${wavePoints.length}个高低点, 期间: $bbPeriod, 标准偏差: $bbStdDev');

    if (wavePoints.isEmpty || bollingerBands.isEmpty) {
      LogService.instance.warning('BollingerBandsFilteringService', '输入数据为空');
      return BollingerBandsFilteredCurveResult(
        points: [],
        originalPointsCount: wavePoints.length,
        filteredPointsCount: 0,
      );
    }

    final upperBand = bollingerBands['upper'];
    final lowerBand = bollingerBands['lower'];
    
    if (upperBand == null || lowerBand == null) {
      LogService.instance.warning('BollingerBandsFilteringService', '布林通道数据不完整');
      return BollingerBandsFilteredCurveResult(
        points: [],
        originalPointsCount: wavePoints.length,
        filteredPointsCount: 0,
      );
    }

    final List<Map<String, dynamic>> filteredPoints = [];
    int filteredCount = 0;

    for (final wavePoint in wavePoints) {
      final int index = wavePoint['index'] as int;
      final double value = wavePoint['value'] as double;
      final int timestamp = priceDataList[index].timestamp;
      
      // 找到对应时间戳的布林通道数据
      final bbIndex = _findBollingerBandsIndex(timestamp, priceDataList);
      
      if (bbIndex == -1 || bbIndex >= upperBand.length || bbIndex >= lowerBand.length) {
        // 找不到对应的布林通道数据，保留该点
        filteredPoints.add({
          'index': index,
          'timestamp': timestamp,
          'value': value,
          'type': 'filtered',
          'method': 'bollinger_bands',
          'reason': 'no_bb_data',
          'originalType': wavePoint['type'], // 保存原始类型信息
        });
        continue;
      }

      final double upperValue = upperBand[bbIndex];
      final double lowerValue = lowerBand[bbIndex];

      // 检查布林通道数据是否有效
      if (upperValue.isNaN || lowerValue.isNaN) {
        // 布林通道数据无效，保留该点
        filteredPoints.add({
          'index': index,
          'timestamp': timestamp,
          'value': value,
          'type': 'filtered',
          'method': 'bollinger_bands',
          'reason': 'invalid_bb_data',
          'originalType': wavePoint['type'], // 保存原始类型信息
        });
        continue;
      }

      // 判断高低点是否在布林通道内
      final bool isInsideBands = value >= lowerValue && value <= upperValue;
      
      if (isInsideBands) {
        // 在布林通道内，过滤掉
        filteredCount++;
        LogService.instance.debug('BollingerBandsFilteringService', 
          '过滤点: 时间=${DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true)}, '
          '价格=$value, 上轨=$upperValue, 下轨=$lowerValue');
      } else {
        // 在布林通道外，保留
        filteredPoints.add({
          'index': index,
          'timestamp': timestamp,
          'value': value,
          'type': 'filtered',
          'method': 'bollinger_bands',
          'reason': 'outside_bands',
          'upperBand': upperValue,
          'lowerBand': lowerValue,
          'originalType': wavePoint['type'], // 保存原始类型信息
        });
      }
    }

    // 按时间戳排序
    filteredPoints.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

    // 合并相邻的同类型点：相邻低点取最低，相邻高点取最高
    final mergedPoints = _mergeAdjacentPoints(filteredPoints);

    final result = BollingerBandsFilteredCurveResult(
      points: mergedPoints,
      originalPointsCount: wavePoints.length,
      filteredPointsCount: filteredCount,
    );

    LogService.instance.info('BollingerBandsFilteringService', 
      '布林线过滤完成: 原始${wavePoints.length}个 → 过滤后${filteredPoints.length}个 '
      '(过滤率${(result.filteringRate * 100).toStringAsFixed(1)}%)');

    return result;
  }

  /// 根据时间戳找到对应的布林通道数据索引
  int _findBollingerBandsIndex(int timestamp, List<PriceData> priceDataList) {
    for (int i = 0; i < priceDataList.length; i++) {
      if (priceDataList[i].timestamp == timestamp) {
        return i;
      }
    }
    return -1;
  }

  /// 合并相邻的同类型点：相邻低点取最低，相邻高点取最高
  List<Map<String, dynamic>> _mergeAdjacentPoints(List<Map<String, dynamic>> points) {
    if (points.length < 2) return points;

    final List<Map<String, dynamic>> mergedPoints = [];
    mergedPoints.add(points.first);

    for (int i = 1; i < points.length; i++) {
      final currentPoint = points[i];
      final lastMergedPoint = mergedPoints.last;

      // 获取点的类型（从原始数据中推断）
      final currentType = _getPointType(currentPoint);
      final lastType = _getPointType(lastMergedPoint);

      if (currentType == lastType) {
        // 相同类型的点，需要合并
        if (currentType == 'high') {
          // 高点：取更高的值
          if (currentPoint['value'] > lastMergedPoint['value']) {
            mergedPoints.last = currentPoint;
          }
        } else {
          // 低点：取更低的值
          if (currentPoint['value'] < lastMergedPoint['value']) {
            mergedPoints.last = currentPoint;
          }
        }
      } else {
        // 不同类型的点，直接添加
        mergedPoints.add(currentPoint);
      }
    }

    LogService.instance.info('BollingerBandsFilteringService', 
      '相邻点合并完成: ${points.length}个 → ${mergedPoints.length}个');

    return mergedPoints;
  }

  /// 根据价格值推断点的类型（高点或低点）
  /// 这里使用简单的启发式方法：如果价格高于前一个点，可能是高点；否则可能是低点
  String _getPointType(Map<String, dynamic> point) {
    // 从原始数据中获取类型信息，如果没有则使用启发式方法
    if (point.containsKey('originalType')) {
      return point['originalType'] as String;
    }
    
    // 启发式方法：根据价格值推断
    // 这里可以根据实际需求调整逻辑
    return 'high'; // 默认返回高点，实际应用中需要更精确的判断
  }

  /// 生成平滑的过滤曲线
  List<Map<String, dynamic>> generateSmoothFilteredCurve({
    required BollingerBandsFilteredCurveResult filteredResult,
    double smoothingFactor = 0.3,
  }) {
    LogService.instance.info('BollingerBandsFilteringService', 
      '生成平滑过滤曲线: ${filteredResult.points.length}个点');

    if (filteredResult.points.length < 2) {
      return filteredResult.points;
    }

    final List<Map<String, dynamic>> smoothPoints = [];
    final points = filteredResult.points;

    for (int i = 0; i < points.length; i++) {
      final currentPoint = points[i];
      double smoothedValue = currentPoint['value'];

      // 应用简单的移动平均平滑
      if (i > 0 && i < points.length - 1) {
        final prevValue = points[i - 1]['value'];
        final nextValue = points[i + 1]['value'];
        final averageValue = (prevValue + currentPoint['value'] + nextValue) / 3;
        
        // 应用平滑因子
        smoothedValue = averageValue * (1 - smoothingFactor) + currentPoint['value'] * smoothingFactor;
      }

      smoothPoints.add({
        'index': currentPoint['index'],
        'timestamp': currentPoint['timestamp'],
        'value': smoothedValue,
        'type': 'smooth_filtered',
        'method': 'bollinger_bands_smooth',
        'originalValue': currentPoint['value'],
        'smoothingFactor': smoothingFactor,
      });
    }

    LogService.instance.info('BollingerBandsFilteringService', 
      '平滑过滤曲线生成完成: ${smoothPoints.length}个点');

    return smoothPoints;
  }
}
