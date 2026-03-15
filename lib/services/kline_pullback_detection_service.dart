import 'dart:math';

import '../models/price_data.dart';
import '../models/pullback_signal.dart';

class KlinePullbackDetectionService {
  KlinePullbackDetectionService._();

  static final KlinePullbackDetectionService instance =
      KlinePullbackDetectionService._();

  List<PullbackSignal> detect(
    List<PriceData> data, {
    PullbackDetectionConfig config = const PullbackDetectionConfig(),
    String? timeframe,
  }) {
    final int minimumLength =
        config.breakoutLookbackCandles + config.maxRetestCandles + 2;
    if (data.length < minimumLength) {
      return const [];
    }

    final List<PullbackSignal> signals = [];
    int scanIndex = max(1, config.breakoutLookbackCandles);
    int lastSignalAnchor = -1000000;

    while (scanIndex < data.length - 1) {
      if (scanIndex - lastSignalAnchor < config.minSignalSpacingCandles) {
        scanIndex++;
        continue;
      }

      final _BreakoutCandidate? bullishCandidate = _buildBreakoutCandidate(
        data,
        breakoutIndex: scanIndex,
        direction: PullbackDirection.bullish,
        config: config,
      );

      final _BreakoutCandidate? bearishCandidate = _buildBreakoutCandidate(
        data,
        breakoutIndex: scanIndex,
        direction: PullbackDirection.bearish,
        config: config,
      );

      final _BreakoutCandidate? selectedCandidate =
          _pickCandidate(bullishCandidate, bearishCandidate);

      if (selectedCandidate == null) {
        scanIndex++;
        continue;
      }

      final PullbackSignal? signal = _resolveCandidate(
        selectedCandidate,
        data,
        config: config,
        timeframe: timeframe,
      );

      if (signal == null) {
        scanIndex++;
        continue;
      }

      signals.add(signal);
      lastSignalAnchor = signal.confirmationIndex ?? signal.retestIndex;
      scanIndex = lastSignalAnchor + 1;
    }

    return signals;
  }

  _BreakoutCandidate? _buildBreakoutCandidate(
    List<PriceData> data, {
    required int breakoutIndex,
    required PullbackDirection direction,
    required PullbackDetectionConfig config,
  }) {
    final int levelStart = breakoutIndex - config.breakoutLookbackCandles;
    final int levelEnd = breakoutIndex - 1;

    if (levelStart < 0 || levelEnd < levelStart || breakoutIndex <= 0) {
      return null;
    }

    final double atr = _averageRange(
      data,
      max(0, breakoutIndex - config.volatilityPeriod + 1),
      breakoutIndex,
    );

    if (atr <= 0) {
      return null;
    }

    final PriceData previous = data[breakoutIndex - 1];
    final PriceData candle = data[breakoutIndex];

    final double range = (candle.high - candle.low).abs();
    if (range <= 0) {
      return null;
    }

    final double bodyRatio = (candle.close - candle.open).abs() / range;
    if (bodyRatio < config.minBreakoutBodyRatio) {
      return null;
    }

    final double breakoutBuffer = atr * config.breakoutAtrMultiplier;
    final bool directionAligned;
    final bool breaksLevel;
    final double levelPrice;
    final double breakoutPrice;
    final double breakoutStrength;

    if (direction == PullbackDirection.bullish) {
      levelPrice = _highestHigh(data, levelStart, levelEnd);
      breaksLevel =
          previous.close <= levelPrice + breakoutBuffer &&
          candle.close > levelPrice + breakoutBuffer;
      directionAligned = candle.close > candle.open;
      breakoutPrice = candle.high;
      breakoutStrength = (candle.close - levelPrice) / atr;
    } else {
      levelPrice = _lowestLow(data, levelStart, levelEnd);
      breaksLevel =
          previous.close >= levelPrice - breakoutBuffer &&
          candle.close < levelPrice - breakoutBuffer;
      directionAligned = candle.close < candle.open;
      breakoutPrice = candle.low;
      breakoutStrength = (levelPrice - candle.close) / atr;
    }

    if (!breaksLevel || !directionAligned || breakoutStrength <= 0) {
      return null;
    }

    return _BreakoutCandidate(
      direction: direction,
      levelSourceStartIndex: levelStart,
      levelSourceEndIndex: levelEnd,
      breakoutIndex: breakoutIndex,
      levelPrice: levelPrice,
      breakoutPrice: breakoutPrice,
      atr: atr,
      breakoutStrength: breakoutStrength,
    );
  }

  PullbackSignal? _resolveCandidate(
    _BreakoutCandidate candidate,
    List<PriceData> data, {
    required PullbackDetectionConfig config,
    required String? timeframe,
  }) {
    final int retestSearchEnd =
        min(data.length - 1, candidate.breakoutIndex + config.maxRetestCandles);

    final double touchTolerance =
        candidate.atr * config.levelToleranceAtrMultiplier;
    final double invalidationTolerance =
        candidate.atr * config.invalidationAtrMultiplier;

    int? retestIndex;

    for (int i = candidate.breakoutIndex + 1; i <= retestSearchEnd; i++) {
      final PriceData candle = data[i];

      if (_isInvalidated(
        candle,
        direction: candidate.direction,
        levelPrice: candidate.levelPrice,
        invalidationTolerance: invalidationTolerance,
      )) {
        return null;
      }

      if (_touchesLevel(
        candle,
        direction: candidate.direction,
        levelPrice: candidate.levelPrice,
        touchTolerance: touchTolerance,
      )) {
        retestIndex = i;
        break;
      }
    }

    if (retestIndex == null) {
      return null;
    }

    final double confirmationTrigger = _confirmationTriggerPrice(
      data,
      direction: candidate.direction,
      breakoutIndex: candidate.breakoutIndex,
      retestIndex: retestIndex,
    );

    final int confirmationSearchEnd =
        min(data.length - 1, retestIndex + config.confirmationCandles);
    int? confirmationIndex;

    for (int i = retestIndex + 1; i <= confirmationSearchEnd; i++) {
      final PriceData candle = data[i];

      if (_isInvalidated(
        candle,
        direction: candidate.direction,
        levelPrice: candidate.levelPrice,
        invalidationTolerance: invalidationTolerance,
      )) {
        return null;
      }

      final bool isConfirmed = candidate.direction == PullbackDirection.bullish
          ? candle.close > confirmationTrigger
          : candle.close < confirmationTrigger;

      if (isConfirmed) {
        confirmationIndex = i;
        break;
      }
    }

    if (confirmationIndex == null && !config.includePendingSignals) {
      return null;
    }

    final PriceData breakoutCandle = data[candidate.breakoutIndex];
    final PriceData retestCandle = data[retestIndex];
    final PriceData? confirmationCandle =
        confirmationIndex == null ? null : data[confirmationIndex];

    final double retestPrice = candidate.direction == PullbackDirection.bullish
        ? retestCandle.low
        : retestCandle.high;

    final double confidence = _computeConfidence(
      candidate: candidate,
      retestPrice: retestPrice,
      confirmationTrigger: confirmationTrigger,
      confirmationPrice: confirmationCandle?.close,
      config: config,
    );

    return PullbackSignal(
      id:
          'pullback-${candidate.direction.name}-${breakoutCandle.timestamp}-${retestCandle.timestamp}-${confirmationCandle?.timestamp ?? 'pending'}',
      direction: candidate.direction,
      status: confirmationIndex == null
          ? PullbackStatus.pending
          : PullbackStatus.confirmed,
      timeframe: timeframe,
      levelSourceStartIndex: candidate.levelSourceStartIndex,
      levelSourceEndIndex: candidate.levelSourceEndIndex,
      breakoutIndex: candidate.breakoutIndex,
      retestIndex: retestIndex,
      confirmationIndex: confirmationIndex,
      breakoutTimestamp: breakoutCandle.timestamp,
      retestTimestamp: retestCandle.timestamp,
      confirmationTimestamp: confirmationCandle?.timestamp,
      levelPrice: candidate.levelPrice,
      breakoutPrice: candidate.breakoutPrice,
      retestPrice: retestPrice,
      confirmationPrice: confirmationCandle?.close,
      confidence: confidence,
    );
  }

  _BreakoutCandidate? _pickCandidate(
    _BreakoutCandidate? bullish,
    _BreakoutCandidate? bearish,
  ) {
    if (bullish == null) return bearish;
    if (bearish == null) return bullish;

    return bullish.breakoutStrength >= bearish.breakoutStrength
        ? bullish
        : bearish;
  }

  bool _touchesLevel(
    PriceData candle, {
    required PullbackDirection direction,
    required double levelPrice,
    required double touchTolerance,
  }) {
    if (direction == PullbackDirection.bullish) {
      return candle.low <= levelPrice + touchTolerance &&
          candle.close >= levelPrice - touchTolerance;
    }

    return candle.high >= levelPrice - touchTolerance &&
        candle.close <= levelPrice + touchTolerance;
  }

  bool _isInvalidated(
    PriceData candle, {
    required PullbackDirection direction,
    required double levelPrice,
    required double invalidationTolerance,
  }) {
    if (direction == PullbackDirection.bullish) {
      return candle.low < levelPrice - invalidationTolerance;
    }

    return candle.high > levelPrice + invalidationTolerance;
  }

  double _confirmationTriggerPrice(
    List<PriceData> data, {
    required PullbackDirection direction,
    required int breakoutIndex,
    required int retestIndex,
  }) {
    if (direction == PullbackDirection.bullish) {
      double highest = double.negativeInfinity;
      for (int i = breakoutIndex; i <= retestIndex; i++) {
        if (data[i].high > highest) {
          highest = data[i].high;
        }
      }
      return highest;
    }

    double lowest = double.infinity;
    for (int i = breakoutIndex; i <= retestIndex; i++) {
      if (data[i].low < lowest) {
        lowest = data[i].low;
      }
    }
    return lowest;
  }

  double _averageRange(List<PriceData> data, int start, int end) {
    if (end < start || start < 0 || end >= data.length) {
      return 0;
    }

    double sum = 0;
    int count = 0;

    for (int i = start; i <= end; i++) {
      sum += (data[i].high - data[i].low).abs();
      count++;
    }

    return count == 0 ? 0 : sum / count;
  }

  double _highestHigh(List<PriceData> data, int start, int end) {
    double highest = double.negativeInfinity;
    for (int i = start; i <= end; i++) {
      if (data[i].high > highest) {
        highest = data[i].high;
      }
    }
    return highest;
  }

  double _lowestLow(List<PriceData> data, int start, int end) {
    double lowest = double.infinity;
    for (int i = start; i <= end; i++) {
      if (data[i].low < lowest) {
        lowest = data[i].low;
      }
    }
    return lowest;
  }

  double _computeConfidence({
    required _BreakoutCandidate candidate,
    required double retestPrice,
    required double confirmationTrigger,
    required double? confirmationPrice,
    required PullbackDetectionConfig config,
  }) {
    final double breakoutScore = _clamp01(candidate.breakoutStrength / 2.0);

    final double retestDistanceAtr =
        (retestPrice - candidate.levelPrice).abs() / candidate.atr;
    final double retestAllowanceAtr = config.levelToleranceAtrMultiplier + 0.15;
    final double retestScore =
        _clamp01(1 - (retestDistanceAtr / retestAllowanceAtr));

    double confirmationScore = 0;
    if (confirmationPrice != null) {
      final double followThroughAtr =
          candidate.direction == PullbackDirection.bullish
              ? (confirmationPrice - confirmationTrigger) / candidate.atr
              : (confirmationTrigger - confirmationPrice) / candidate.atr;
      confirmationScore = _clamp01(followThroughAtr);
    }

    final double weighted =
        (breakoutScore * 0.5) + (retestScore * 0.25) + (confirmationScore * 0.25);
    return (weighted * 100).clamp(0.0, 100.0).toDouble();
  }

  double _clamp01(double value) {
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }
}

class _BreakoutCandidate {
  final PullbackDirection direction;
  final int levelSourceStartIndex;
  final int levelSourceEndIndex;
  final int breakoutIndex;
  final double levelPrice;
  final double breakoutPrice;
  final double atr;
  final double breakoutStrength;

  const _BreakoutCandidate({
    required this.direction,
    required this.levelSourceStartIndex,
    required this.levelSourceEndIndex,
    required this.breakoutIndex,
    required this.levelPrice,
    required this.breakoutPrice,
    required this.atr,
    required this.breakoutStrength,
  });
}
