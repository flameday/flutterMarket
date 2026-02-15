import '../models/manual_high_low_point.dart';
import '../models/price_data.dart';

class KlineNearbyHighLowStrategyService {
  KlineNearbyHighLowStrategyService._();

  static final KlineNearbyHighLowStrategyService instance =
      KlineNearbyHighLowStrategyService._();

  static const int _minFollowCandles = 2;

  List<ManualHighLowPoint> detect(
    List<PriceData> data, {
    String? timeframe,
  }) {
    if (data.length < _minFollowCandles + 1) {
      return const [];
    }

    final List<ManualHighLowPoint> result = [];

    for (int n = 0; n < data.length - _minFollowCandles; n++) {
      final PriceData current = data[n];
      final _Direction currentDirection = _directionOf(current);

      if (currentDirection == _Direction.neutral) {
        continue;
      }

      final _Direction followDirection =
          currentDirection == _Direction.down ? _Direction.up : _Direction.down;

      final int sequenceStart = n + 1;
      int sequenceEnd = sequenceStart;
      while (sequenceEnd < data.length &&
          _directionOf(data[sequenceEnd]) == followDirection) {
        sequenceEnd++;
      }

      final int followCount = sequenceEnd - sequenceStart;
      if (followCount < _minFollowCandles) {
        continue;
      }

      final double currentBodyHigh = _bodyHigh(current);
      final double currentBodyLow = _bodyLow(current);

      if (currentDirection == _Direction.down) {
        final bool breaksUpward = _breaksAboveBodyHigh(
          data,
          start: sequenceStart,
          endExclusive: sequenceEnd,
          bodyHigh: currentBodyHigh,
        );

        if (!breaksUpward) {
          continue;
        }

        final PriceData pivot = data[sequenceStart];
        result.add(
          ManualHighLowPoint(
            id: 'strategy-low-${pivot.timestamp}-$n',
            timestamp: pivot.timestamp,
            price: _bodyLow(pivot),
            isHigh: false,
            createdAt: DateTime.now(),
            note: 'kline_nearby_strategy',
            timeframe: timeframe,
          ),
        );
      } else {
        final bool breaksDownward = _breaksBelowBodyLow(
          data,
          start: sequenceStart,
          endExclusive: sequenceEnd,
          bodyLow: currentBodyLow,
        );

        if (!breaksDownward) {
          continue;
        }

        final PriceData pivot = data[sequenceStart];
        result.add(
          ManualHighLowPoint(
            id: 'strategy-high-${pivot.timestamp}-$n',
            timestamp: pivot.timestamp,
            price: _bodyHigh(pivot),
            isHigh: true,
            createdAt: DateTime.now(),
            note: 'kline_nearby_strategy',
            timeframe: timeframe,
          ),
        );
      }
    }

    return result;
  }

  bool _breaksAboveBodyHigh(
    List<PriceData> data, {
    required int start,
    required int endExclusive,
    required double bodyHigh,
  }) {
    for (int i = start; i < endExclusive; i++) {
      if (_bodyHigh(data[i]) > bodyHigh) {
        return true;
      }
    }
    return false;
  }

  bool _breaksBelowBodyLow(
    List<PriceData> data, {
    required int start,
    required int endExclusive,
    required double bodyLow,
  }) {
    for (int i = start; i < endExclusive; i++) {
      if (_bodyLow(data[i]) < bodyLow) {
        return true;
      }
    }
    return false;
  }

  _Direction _directionOf(PriceData candle) {
    if (candle.close > candle.open) return _Direction.up;
    if (candle.close < candle.open) return _Direction.down;
    return _Direction.neutral;
  }

  double _bodyHigh(PriceData candle) {
    return candle.open > candle.close ? candle.open : candle.close;
  }

  double _bodyLow(PriceData candle) {
    return candle.open < candle.close ? candle.open : candle.close;
  }
}

enum _Direction {
  up,
  down,
  neutral,
}
