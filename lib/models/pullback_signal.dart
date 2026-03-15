enum PullbackDirection {
  bullish,
  bearish,
}

enum PullbackStatus {
  confirmed,
  pending,
}

class PullbackSignal {
  final String id;
  final PullbackDirection direction;
  final PullbackStatus status;
  final String? timeframe;

  /// Lookback window used to define support or resistance before breakout.
  final int levelSourceStartIndex;
  final int levelSourceEndIndex;

  final int breakoutIndex;
  final int retestIndex;
  final int? confirmationIndex;

  final int breakoutTimestamp;
  final int retestTimestamp;
  final int? confirmationTimestamp;

  final double levelPrice;
  final double breakoutPrice;
  final double retestPrice;
  final double? confirmationPrice;

  /// 0..100, higher is stronger.
  final double confidence;

  const PullbackSignal({
    required this.id,
    required this.direction,
    required this.status,
    required this.timeframe,
    required this.levelSourceStartIndex,
    required this.levelSourceEndIndex,
    required this.breakoutIndex,
    required this.retestIndex,
    required this.confirmationIndex,
    required this.breakoutTimestamp,
    required this.retestTimestamp,
    required this.confirmationTimestamp,
    required this.levelPrice,
    required this.breakoutPrice,
    required this.retestPrice,
    required this.confirmationPrice,
    required this.confidence,
  });

  bool get isBullish => direction == PullbackDirection.bullish;

  factory PullbackSignal.fromJson(Map<String, dynamic> json) {
    return PullbackSignal(
      id: json['id'] as String,
      direction: PullbackDirection.values.byName(json['direction'] as String),
      status: PullbackStatus.values.byName(json['status'] as String),
      timeframe: json['timeframe'] as String?,
      levelSourceStartIndex: json['levelSourceStartIndex'] as int,
      levelSourceEndIndex: json['levelSourceEndIndex'] as int,
      breakoutIndex: json['breakoutIndex'] as int,
      retestIndex: json['retestIndex'] as int,
      confirmationIndex: json['confirmationIndex'] as int?,
      breakoutTimestamp: json['breakoutTimestamp'] as int,
      retestTimestamp: json['retestTimestamp'] as int,
      confirmationTimestamp: json['confirmationTimestamp'] as int?,
      levelPrice: (json['levelPrice'] as num).toDouble(),
      breakoutPrice: (json['breakoutPrice'] as num).toDouble(),
      retestPrice: (json['retestPrice'] as num).toDouble(),
      confirmationPrice: (json['confirmationPrice'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'direction': direction.name,
      'status': status.name,
      'timeframe': timeframe,
      'levelSourceStartIndex': levelSourceStartIndex,
      'levelSourceEndIndex': levelSourceEndIndex,
      'breakoutIndex': breakoutIndex,
      'retestIndex': retestIndex,
      'confirmationIndex': confirmationIndex,
      'breakoutTimestamp': breakoutTimestamp,
      'retestTimestamp': retestTimestamp,
      'confirmationTimestamp': confirmationTimestamp,
      'levelPrice': levelPrice,
      'breakoutPrice': breakoutPrice,
      'retestPrice': retestPrice,
      'confirmationPrice': confirmationPrice,
      'confidence': confidence,
    };
  }
}

class PullbackDetectionConfig {
  final int breakoutLookbackCandles;
  final int maxRetestCandles;
  final int confirmationCandles;
  final int volatilityPeriod;
  final int minSignalSpacingCandles;
  final double levelToleranceAtrMultiplier;
  final double breakoutAtrMultiplier;
  final double invalidationAtrMultiplier;
  final double minBreakoutBodyRatio;
  final bool includePendingSignals;

  const PullbackDetectionConfig({
    this.breakoutLookbackCandles = 20,
    this.maxRetestCandles = 12,
    this.confirmationCandles = 6,
    this.volatilityPeriod = 14,
    this.minSignalSpacingCandles = 5,
    this.levelToleranceAtrMultiplier = 0.25,
    this.breakoutAtrMultiplier = 0.10,
    this.invalidationAtrMultiplier = 0.40,
    this.minBreakoutBodyRatio = 0.25,
    this.includePendingSignals = false,
  });

  PullbackDetectionConfig copyWith({
    int? breakoutLookbackCandles,
    int? maxRetestCandles,
    int? confirmationCandles,
    int? volatilityPeriod,
    int? minSignalSpacingCandles,
    double? levelToleranceAtrMultiplier,
    double? breakoutAtrMultiplier,
    double? invalidationAtrMultiplier,
    double? minBreakoutBodyRatio,
    bool? includePendingSignals,
  }) {
    return PullbackDetectionConfig(
      breakoutLookbackCandles:
          breakoutLookbackCandles ?? this.breakoutLookbackCandles,
      maxRetestCandles: maxRetestCandles ?? this.maxRetestCandles,
      confirmationCandles: confirmationCandles ?? this.confirmationCandles,
      volatilityPeriod: volatilityPeriod ?? this.volatilityPeriod,
      minSignalSpacingCandles:
          minSignalSpacingCandles ?? this.minSignalSpacingCandles,
      levelToleranceAtrMultiplier:
          levelToleranceAtrMultiplier ?? this.levelToleranceAtrMultiplier,
      breakoutAtrMultiplier: breakoutAtrMultiplier ?? this.breakoutAtrMultiplier,
      invalidationAtrMultiplier:
          invalidationAtrMultiplier ?? this.invalidationAtrMultiplier,
      minBreakoutBodyRatio: minBreakoutBodyRatio ?? this.minBreakoutBodyRatio,
      includePendingSignals: includePendingSignals ?? this.includePendingSignals,
    );
  }
}
