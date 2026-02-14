import '../models/price_data.dart';
import 'log_service.dart';
import 'trend_filtering_service.dart';

class MA150PivotTrendStrategyService {
  static final MA150PivotTrendStrategyService _instance =
      MA150PivotTrendStrategyService._internal();

  factory MA150PivotTrendStrategyService() => _instance;

  MA150PivotTrendStrategyService._internal();

  static MA150PivotTrendStrategyService get instance => _instance;

  FilteredWavePoints analyze({
    required List<PriceData> priceDataList,
    required List<double?> ma150Series,
    double nearThreshold = 0.01,
    int pivotLookback = 4,
    int minGapBars = 3,
    int ma10Period = 10,
    int ma10ConfirmBars = 3,
  }) {
    if (priceDataList.isEmpty || ma150Series.isEmpty) {
      return FilteredWavePoints(
        filteredHighPoints: const [],
        filteredLowPoints: const [],
        trendLines: const [],
        originalPoints: const [],
      );
    }

    final List<double?> ma10Series = _calculateSimpleMovingAverage(
      priceDataList,
      ma10Period,
    );

    final List<Map<String, dynamic>> candidatePivots = _detectCandidatesByMa10Breakout(
      priceDataList: priceDataList,
      ma10Series: ma10Series,
      confirmBars: ma10ConfirmBars,
    );

    final List<Map<String, dynamic>> alternatedCandidates = _enforceAlternation(candidatePivots);

    final List<Map<String, dynamic>> rawPivots = _filterCandidatesWithMa150AndPivotDefinition(
      priceDataList: priceDataList,
      candidates: alternatedCandidates,
      ma150Series: ma150Series,
      nearThreshold: nearThreshold,
      pivotLookback: pivotLookback,
    );

    final List<Map<String, dynamic>> alternatedPivots = _enforceAlternation(rawPivots);
    final List<Map<String, dynamic>> validTrendPivots =
        _extractTrendContinuousPivots(alternatedPivots);

    final List<Map<String, dynamic>> filteredHighPoints = [];
    final List<Map<String, dynamic>> filteredLowPoints = [];

    for (final point in validTrendPivots) {
      if (point['type'] == 'high') {
        filteredHighPoints.add(point);
      } else {
        filteredLowPoints.add(point);
      }
    }

    final List<Map<String, dynamic>> cleanedHigh =
        _applyMinGap(filteredHighPoints, minGapBars, isHigh: true);
    final List<Map<String, dynamic>> cleanedLow =
        _applyMinGap(filteredLowPoints, minGapBars, isHigh: false);

    final List<TrendLine> trendLines = _buildTrendLines(cleanedHigh, cleanedLow);

    LogService.instance.info(
      'MA150PivotTrendStrategy',
      'analyze完成: candidates=${candidatePivots.length}, candidatesAlternated=${alternatedCandidates.length}, raw=${rawPivots.length}, alternated=${alternatedPivots.length}, trend=${validTrendPivots.length}, high=${cleanedHigh.length}, low=${cleanedLow.length}',
    );

    return FilteredWavePoints(
      filteredHighPoints: cleanedHigh,
      filteredLowPoints: cleanedLow,
      trendLines: trendLines,
      originalPoints: alternatedCandidates,
      smoothTrendLine: null,
    );
  }

  List<double?> _calculateSimpleMovingAverage(
    List<PriceData> priceDataList,
    int period,
  ) {
    if (priceDataList.isEmpty || period <= 0) return const [];

    final List<double?> series = List<double?>.filled(priceDataList.length, null);
    double rollingSum = 0;

    for (int i = 0; i < priceDataList.length; i++) {
      rollingSum += priceDataList[i].close;

      if (i >= period) {
        rollingSum -= priceDataList[i - period].close;
      }

      if (i >= period - 1) {
        series[i] = rollingSum / period;
      }
    }

    return series;
  }

  List<Map<String, dynamic>> _detectCandidatesByMa10Breakout({
    required List<PriceData> priceDataList,
    required List<double?> ma10Series,
    required int confirmBars,
  }) {
    final List<Map<String, dynamic>> points = [];
    final int n = priceDataList.length;
    if (n < 2) return points;

    int segmentStart = 0;

    for (int i = 1; i < n; i++) {
      if (_isConfirmedBreakAboveMa10(priceDataList, ma10Series, i, confirmBars)) {
        final Map<String, dynamic>? lowPoint = _findExtremePoint(
          priceDataList,
          segmentStart,
          i,
          isHigh: false,
        );
        if (lowPoint != null) {
          points.add(lowPoint);
        }
        segmentStart = i;
        continue;
      }

      if (_isConfirmedBreakBelowMa10(priceDataList, ma10Series, i, confirmBars)) {
        final Map<String, dynamic>? highPoint = _findExtremePoint(
          priceDataList,
          segmentStart,
          i,
          isHigh: true,
        );
        if (highPoint != null) {
          points.add(highPoint);
        }
        segmentStart = i;
      }
    }

    points.sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
    return points;
  }

  bool _isConfirmedBreakAboveMa10(
    List<PriceData> priceDataList,
    List<double?> ma10Series,
    int index,
    int confirmBars,
  ) {
    if (confirmBars <= 0) return false;
    if (index <= 0 || index + confirmBars - 1 >= priceDataList.length) {
      return false;
    }

    final double? prevMa10 = ma10Series[index - 1];
    if (prevMa10 == null) return false;
    if (priceDataList[index - 1].close > prevMa10) return false;

    for (int i = index; i < index + confirmBars; i++) {
      final double? ma10 = ma10Series[i];
      if (ma10 == null) return false;
      if (priceDataList[i].close <= ma10) return false;
    }

    return true;
  }

  bool _isConfirmedBreakBelowMa10(
    List<PriceData> priceDataList,
    List<double?> ma10Series,
    int index,
    int confirmBars,
  ) {
    if (confirmBars <= 0) return false;
    if (index <= 0 || index + confirmBars - 1 >= priceDataList.length) {
      return false;
    }

    final double? prevMa10 = ma10Series[index - 1];
    if (prevMa10 == null) return false;
    if (priceDataList[index - 1].close < prevMa10) return false;

    for (int i = index; i < index + confirmBars; i++) {
      final double? ma10 = ma10Series[i];
      if (ma10 == null) return false;
      if (priceDataList[i].close >= ma10) return false;
    }

    return true;
  }

  Map<String, dynamic>? _findExtremePoint(
    List<PriceData> priceDataList,
    int start,
    int end, {
    required bool isHigh,
  }) {
    if (priceDataList.isEmpty) return null;

    final int safeStart = start.clamp(0, priceDataList.length - 1);
    final int safeEnd = end.clamp(0, priceDataList.length - 1);
    if (safeStart > safeEnd) return null;

    int bestIndex = safeStart;
    double bestValue = isHigh
        ? priceDataList[safeStart].high
        : priceDataList[safeStart].low;

    for (int i = safeStart + 1; i <= safeEnd; i++) {
      final double value = isHigh ? priceDataList[i].high : priceDataList[i].low;
      final bool better = isHigh ? value > bestValue : value < bestValue;
      if (better) {
        bestValue = value;
        bestIndex = i;
      }
    }

    return {
      'index': bestIndex,
      'value': bestValue,
      'type': isHigh ? 'high' : 'low',
      'timestamp': priceDataList[bestIndex].timestamp,
    };
  }

  List<Map<String, dynamic>> _filterCandidatesWithMa150AndPivotDefinition({
    required List<PriceData> priceDataList,
    required List<Map<String, dynamic>> candidates,
    required List<double?> ma150Series,
    required double nearThreshold,
    required int pivotLookback,
  }) {
    final List<Map<String, dynamic>> points = [];
    if (candidates.isEmpty) return points;

    for (final point in candidates) {
      final int index = point['index'] as int;
      if (index < 0 || index >= priceDataList.length) {
        continue;
      }

      final double? ma150 = index < ma150Series.length ? ma150Series[index] : null;
      if (ma150 == null || ma150.abs() < 0.0000001) {
        continue;
      }

      final String type = point['type'] as String;
      final double value = point['value'] as double;
      final double distance = (value - ma150).abs() / ma150.abs();
      if (distance > nearThreshold) {
        continue;
      }

      final bool isValidPivot = type == 'high'
          ? _isPivotHigh(priceDataList, index, pivotLookback)
          : _isPivotLow(priceDataList, index, pivotLookback);
      if (!isValidPivot) {
        continue;
      }

      points.add(point);
    }

    return points;
  }

  bool _isPivotHigh(List<PriceData> data, int i, int lookback) {
    if (i - lookback < 0 || i + lookback >= data.length) return false;
    final double candidate = data[i].high;
    for (int j = i - lookback; j <= i + lookback; j++) {
      if (j == i) continue;
      if (data[j].high >= candidate) return false;
    }
    return true;
  }

  bool _isPivotLow(List<PriceData> data, int i, int lookback) {
    if (i - lookback < 0 || i + lookback >= data.length) return false;
    final double candidate = data[i].low;
    for (int j = i - lookback; j <= i + lookback; j++) {
      if (j == i) continue;
      if (data[j].low <= candidate) return false;
    }
    return true;
  }

  List<Map<String, dynamic>> _enforceAlternation(List<Map<String, dynamic>> points) {
    if (points.isEmpty) return const [];

    final List<Map<String, dynamic>> alternated = [points.first];

    for (int i = 1; i < points.length; i++) {
      final current = points[i];
      final last = alternated.last;

      if (current['type'] != last['type']) {
        alternated.add(current);
        continue;
      }

      if (current['type'] == 'high') {
        if ((current['value'] as double) > (last['value'] as double)) {
          alternated[alternated.length - 1] = current;
        }
      } else {
        if ((current['value'] as double) < (last['value'] as double)) {
          alternated[alternated.length - 1] = current;
        }
      }
    }

    return alternated;
  }

  List<Map<String, dynamic>> _extractTrendContinuousPivots(
    List<Map<String, dynamic>> alternated,
  ) {
    if (alternated.length < 4) return const [];

    final Set<int> keepIndexes = {};

    for (int i = 3; i < alternated.length; i++) {
      final p0 = alternated[i - 3];
      final p1 = alternated[i - 2];
      final p2 = alternated[i - 1];
      final p3 = alternated[i];

      if (p0['type'] != p2['type'] || p1['type'] != p3['type']) {
        continue;
      }

      final double p0v = p0['value'] as double;
      final double p1v = p1['value'] as double;
      final double p2v = p2['value'] as double;
      final double p3v = p3['value'] as double;

      final bool upTrend = p2v > p0v && p3v > p1v;
      final bool downTrend = p2v < p0v && p3v < p1v;

      if (upTrend || downTrend) {
        keepIndexes.add(i - 3);
        keepIndexes.add(i - 2);
        keepIndexes.add(i - 1);
        keepIndexes.add(i);
      }
    }

    if (keepIndexes.isEmpty) return const [];

    final List<int> sorted = keepIndexes.toList()..sort();
    return sorted.map((idx) => alternated[idx]).toList();
  }

  List<Map<String, dynamic>> _applyMinGap(
    List<Map<String, dynamic>> points,
    int minGapBars, {
    required bool isHigh,
  }) {
    if (points.length < 2 || minGapBars <= 1) {
      return List<Map<String, dynamic>>.from(points)
        ..sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
    }

    final List<Map<String, dynamic>> sorted = List<Map<String, dynamic>>.from(points)
      ..sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));

    final List<Map<String, dynamic>> result = [sorted.first];

    for (int i = 1; i < sorted.length; i++) {
      final current = sorted[i];
      final last = result.last;
      final int gap = (current['index'] as int) - (last['index'] as int);

      if (gap >= minGapBars) {
        result.add(current);
        continue;
      }

      final double currentValue = current['value'] as double;
      final double lastValue = last['value'] as double;
      final bool replace = isHigh ? currentValue > lastValue : currentValue < lastValue;
      if (replace) {
        result[result.length - 1] = current;
      }
    }

    return result;
  }

  List<TrendLine> _buildTrendLines(
    List<Map<String, dynamic>> highs,
    List<Map<String, dynamic>> lows,
  ) {
    final List<TrendLine> lines = [];

    lines.addAll(_buildTypeTrendLines(highs, 'high'));
    lines.addAll(_buildTypeTrendLines(lows, 'low'));

    return lines;
  }

  List<TrendLine> _buildTypeTrendLines(
    List<Map<String, dynamic>> points,
    String type,
  ) {
    if (points.length < 2) return const [];

    final List<Map<String, dynamic>> sorted = List<Map<String, dynamic>>.from(points)
      ..sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));

    final List<TrendLine> lines = [];
    for (int i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];
      final int startIndex = prev['index'] as int;
      final int endIndex = curr['index'] as int;
      if (endIndex <= startIndex) continue;

      final double startValue = prev['value'] as double;
      final double endValue = curr['value'] as double;
      final double slope = (endValue - startValue) / (endIndex - startIndex);

      lines.add(
        TrendLine(
          startIndex: startIndex,
          endIndex: endIndex,
          startValue: startValue,
          endValue: endValue,
          slope: slope,
          strength: 0.8,
          type: type,
          points: [prev, curr],
        ),
      );
    }

    return lines;
  }
}
