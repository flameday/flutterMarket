import '../models/wave_points.dart';
import '../models/price_data.dart';
import 'log_service.dart';

/// 60均线过滤服务
class MA60FilteringService {
  static final MA60FilteringService _instance = MA60FilteringService._internal();
  factory MA60FilteringService() => _instance;
  MA60FilteringService._internal();

  static MA60FilteringService get instance => _instance;

  /// 基于60均线过滤波浪点并生成连接曲线
  MA60FilteredCurveResult generateMA60FilteredCurve({
    required WavePoints wavePoints,
    required List<PriceData> priceDataList,
    required List<double?> ma60Series,
  }) {
    LogService.instance.info('MA60FilteringService', '开始生成60均线过滤曲线');
    
    if (wavePoints.mergedPoints.isEmpty) {
      LogService.instance.warning('MA60FilteringService', '波浪点数据为空，无法生成60均线过滤曲线');
      return MA60FilteredCurveResult(points: [], rSquared: 0.0);
    }

    // 过滤波浪点
    final filteredPoints = _filterWavePointsByMA60(
      wavePoints.mergedPoints, 
      priceDataList, 
      ma60Series
    );

    if (filteredPoints.isEmpty) {
      LogService.instance.warning('MA60FilteringService', '过滤后没有有效点，无法生成曲线');
      return MA60FilteredCurveResult(points: [], rSquared: 0.0);
    }

    // 直接连接有效高低点形成折线
    final curvePoints = _generateConnectedCurve(filteredPoints, priceDataList);
    
    LogService.instance.info('MA60FilteringService', '60均线过滤曲线生成完成: ${curvePoints.length}个点');
    
    return MA60FilteredCurveResult(
      points: curvePoints,
      rSquared: 1.0, // 直接连接，R²设为1.0
    );
  }

  /// 基于60均线过滤波浪点
  List<Map<String, dynamic>> _filterWavePointsByMA60(
    List<Map<String, dynamic>> mergedPoints,
    List<PriceData> priceDataList,
    List<double?> ma60Series,
  ) {
    LogService.instance.debug('MA60FilteringService', '开始60均线过滤: ${mergedPoints.length}个原始点');
    
    final List<Map<String, dynamic>> filteredPoints = [];
    int i = 0;
    
    while (i < mergedPoints.length) {
      final currentPoint = mergedPoints[i];
      final currentIndex = currentPoint['index'] as int;
      final currentValue = currentPoint['value'] as double;
      
      // 获取当前点的60均线值
      final ma60Value = ma60Series[currentIndex];
      if (ma60Value == null) {
        i++;
        continue;
      }
      
      // 判断当前点相对于60均线的位置
      final isAboveMA60 = currentValue > ma60Value;
      
      // 寻找连续的同侧点
      final List<Map<String, dynamic>> consecutivePoints = [currentPoint];
      int j = i + 1;
      
      while (j < mergedPoints.length) {
        final nextPoint = mergedPoints[j];
        final nextIndex = nextPoint['index'] as int;
        final nextValue = nextPoint['value'] as double;
        final nextMA60Value = ma60Series[nextIndex];
        
        if (nextMA60Value == null) {
          j++;
          continue;
        }
        
        final nextIsAboveMA60 = nextValue > nextMA60Value;
        
        // 如果下一个点也在同侧，加入连续点列表
        if (nextIsAboveMA60 == isAboveMA60) {
          consecutivePoints.add(nextPoint);
          j++;
        } else {
          break;
        }
      }
      
      // 从连续点中选择最有效的点
      Map<String, dynamic> selectedPoint;
      if (isAboveMA60) {
        // 在60均线之上，选择最高点
        selectedPoint = consecutivePoints.reduce((a, b) => 
          (a['value'] as double) > (b['value'] as double) ? a : b
        );
        LogService.instance.debug('MA60FilteringService', '60均线之上连续${consecutivePoints.length}个点，选择最高点: ${selectedPoint['value']}');
      } else {
        // 在60均线之下，选择最低点
        selectedPoint = consecutivePoints.reduce((a, b) => 
          (a['value'] as double) < (b['value'] as double) ? a : b
        );
        LogService.instance.debug('MA60FilteringService', '60均线之下连续${consecutivePoints.length}个点，选择最低点: ${selectedPoint['value']}');
      }
      
      filteredPoints.add(selectedPoint);
      
      // 跳过已处理的连续点
      i = j;
    }
    
    LogService.instance.info('MA60FilteringService', '60均线过滤完成: ${mergedPoints.length}个原始点 → ${filteredPoints.length}个有效点');
    return filteredPoints;
  }

  /// 生成连接曲线
  List<MA60FilteredCurvePoint> _generateConnectedCurve(
    List<Map<String, dynamic>> filteredPoints,
    List<PriceData> priceDataList,
  ) {
    LogService.instance.debug('MA60FilteringService', '开始生成连接曲线: ${filteredPoints.length}个过滤点');
    
    final List<MA60FilteredCurvePoint> curvePoints = [];
    
    for (final point in filteredPoints) {
      final index = point['index'] as int;
      final value = point['value'] as double;
      final type = point['type'] as String;
      
      curvePoints.add(MA60FilteredCurvePoint(
        index: index,
        value: value,
        type: type,
        timestamp: priceDataList[index].timestamp,
      ));
    }
    
    LogService.instance.debug('MA60FilteringService', '连接曲线生成完成: ${curvePoints.length}个点');
    return curvePoints;
  }

}

/// 60均线过滤曲线结果
class MA60FilteredCurveResult {
  final List<MA60FilteredCurvePoint> points;
  final double rSquared;

  const MA60FilteredCurveResult({
    required this.points,
    required this.rSquared,
  });
}

/// 60均线过滤曲线点
class MA60FilteredCurvePoint {
  final int index;
  final double value;
  final String type; // 'high' or 'low'
  final int timestamp;

  const MA60FilteredCurvePoint({
    required this.index,
    required this.value,
    required this.type,
    required this.timestamp,
  });
}
