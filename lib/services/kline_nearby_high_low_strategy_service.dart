import '../models/manual_high_low_point.dart';
import '../models/price_data.dart';

class KlineNearbyHighLowStrategyService {
  KlineNearbyHighLowStrategyService._();

  static final KlineNearbyHighLowStrategyService instance =
      KlineNearbyHighLowStrategyService._();

  static const int _minFollowCandles = 1;

  List<ManualHighLowPoint> detect(
    List<PriceData> data, {
    String? timeframe,
    bool mergeConsecutive = true,
  }) {
    if (data.length < _minFollowCandles + 1) {
      return const [];
    }

    final List<ManualHighLowPoint> step1Points = [];

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
        final bool breaksUpward = _breaksAboveBodyHighByClose(
          data,
          start: sequenceStart,
          endExclusive: sequenceEnd,
          bodyHigh: currentBodyHigh,
        );

        if (!breaksUpward) {
          continue;
        }

        final PriceData pivot = data[sequenceStart];
        step1Points.add(
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
        final bool breaksDownward = _breaksBelowBodyLowByClose(
          data,
          start: sequenceStart,
          endExclusive: sequenceEnd,
          bodyLow: currentBodyLow,
        );

        if (!breaksDownward) {
          continue;
        }

        final PriceData pivot = data[sequenceStart];
        step1Points.add(
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

    final List<ManualHighLowPoint> enrichedStep1Points =
        _appendSupplementExtrema(step1Points, data, timeframe: timeframe);

    if (!mergeConsecutive) {
      return enrichedStep1Points;
    }

    return _mergeConsecutiveByType(enrichedStep1Points);
  }

  List<ManualHighLowPoint> _appendSupplementExtrema(
    List<ManualHighLowPoint> basePoints,
    List<PriceData> data, {
    required String? timeframe,
  }) {
    if (basePoints.length < 2 || data.isEmpty) {
      return basePoints;
    }

    final List<ManualHighLowPoint> sortedBase = List<ManualHighLowPoint>.from(basePoints)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final Map<int, int> indexByTimestamp = {
      for (int i = 0; i < data.length; i++) data[i].timestamp: i,
    };

    final List<ManualHighLowPoint> output = List<ManualHighLowPoint>.from(sortedBase);
    final Set<String> existingKeys = {
      for (final p in output) '${p.timestamp}-${p.isHigh ? 'H' : 'L'}',
    };

    for (int i = 0; i < sortedBase.length - 1; i++) {
      final ManualHighLowPoint current = sortedBase[i];
      final ManualHighLowPoint next = sortedBase[i + 1];

      if (current.isHigh == next.isHigh) {
        continue;
      }

      final int? startIndexRaw = indexByTimestamp[current.timestamp];
      final int? endIndexRaw = indexByTimestamp[next.timestamp];
      if (startIndexRaw == null || endIndexRaw == null) {
        continue;
      }

      final int start = startIndexRaw < endIndexRaw ? startIndexRaw : endIndexRaw;
      final int end = startIndexRaw < endIndexRaw ? endIndexRaw : startIndexRaw;
      if (end < start) {
        continue;
      }

      if (!current.isHigh && next.isHigh) {
        double maxBodyHigh = double.negativeInfinity;
        for (int k = start; k <= end; k++) {
          final double bodyHigh = _bodyHigh(data[k]);
          if (bodyHigh > maxBodyHigh) {
            maxBodyHigh = bodyHigh;
          }
        }

        for (int k = start; k <= end; k++) {
          final double bodyHigh = _bodyHigh(data[k]);
          if ((bodyHigh - maxBodyHigh).abs() < 0.0000000001) {
            final int ts = data[k].timestamp;
            final String key = '$ts-H';
            if (existingKeys.contains(key)) continue;
            output.add(
              ManualHighLowPoint(
                id: 'strategy-supp-high-$ts-$i-$k',
                timestamp: ts,
                price: bodyHigh,
                isHigh: true,
                createdAt: DateTime.now(),
                note: 'kline_nearby_strategy_supp',
                timeframe: timeframe,
              ),
            );
            existingKeys.add(key);
          }
        }
      }

      if (current.isHigh && !next.isHigh) {
        double minBodyLow = double.infinity;
        for (int k = start; k <= end; k++) {
          final double bodyLow = _bodyLow(data[k]);
          if (bodyLow < minBodyLow) {
            minBodyLow = bodyLow;
          }
        }

        for (int k = start; k <= end; k++) {
          final double bodyLow = _bodyLow(data[k]);
          if ((bodyLow - minBodyLow).abs() < 0.0000000001) {
            final int ts = data[k].timestamp;
            final String key = '$ts-L';
            if (existingKeys.contains(key)) continue;
            output.add(
              ManualHighLowPoint(
                id: 'strategy-supp-low-$ts-$i-$k',
                timestamp: ts,
                price: bodyLow,
                isHigh: false,
                createdAt: DateTime.now(),
                note: 'kline_nearby_strategy_supp',
                timeframe: timeframe,
              ),
            );
            existingKeys.add(key);
          }
        }
      }
    }

    output.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return output;
  }

  List<ManualHighLowPoint> _mergeConsecutiveByType(
    List<ManualHighLowPoint> points,
  ) {
    if (points.length < 2) return points;

    final List<ManualHighLowPoint> ordered = List<ManualHighLowPoint>.from(points)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final List<ManualHighLowPoint> merged = [];
    int i = 0;
    while (i < ordered.length) {
      ManualHighLowPoint best = ordered[i];
      int j = i + 1;

      while (j < ordered.length && ordered[j].isHigh == best.isHigh) {
        final ManualHighLowPoint current = ordered[j];
        if (best.isHigh) {
          if (current.price > best.price) {
            best = current;
          }
        } else {
          if (current.price < best.price) {
            best = current;
          }
        }
        j++;
      }

      merged.add(best);
      i = j;
    }

    return merged;
  }

  bool _breaksAboveBodyHighByClose(
    List<PriceData> data, {
    required int start,
    required int endExclusive,
    required double bodyHigh,
  }) {
    for (int i = start; i < endExclusive; i++) {
      if (data[i].close > bodyHigh) {
        return true;
      }
    }
    return false;
  }

  bool _breaksBelowBodyLowByClose(
    List<PriceData> data, {
    required int start,
    required int endExclusive,
    required double bodyLow,
  }) {
    for (int i = start; i < endExclusive; i++) {
      if (data[i].close < bodyLow) {
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
