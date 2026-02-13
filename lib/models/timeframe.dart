import 'trading_pair.dart';

enum Timeframe {
  m5('5分', 'm5', 5),
  m15('15分', 'm15', 15),
  m30('30分', 'm30', 30),
  h1('1時間', 'h1', 60),
  h2('2時間', 'h2', 120),
  h4('4時間', 'h4', 240);

  const Timeframe(this.displayName, this.dukascopyCode, this.minutes);

  final String displayName;
  final String dukascopyCode;
  final int minutes; // 分単位の時間周期

  /// 時間周期の説明を取得
  String get description {
    switch (this) {
      case Timeframe.m5:
        return '5分K線';
      case Timeframe.m15:
        return '15分K線';
      case Timeframe.m30:
        return '30分K線';
      case Timeframe.h1:
        return '1時間K線';
      case Timeframe.h2:
        return '2時間K線';
      case Timeframe.h4:
        return '4時間K線';
    }
  }

  /// ディレクトリ名を取得（相対パス）
  String get directoryName {
    return 'data/EURUSD/$dukascopyCode';
  }

  /// 指定された取引ペアのディレクトリ名を取得
  String getDirectoryName(TradingPair pair) {
    return '${pair.directoryName}/$dukascopyCode';
  }

  /// CSVファイルプレフィックスを取得
  String get csvPrefix {
    return 'eurusd-$dukascopyCode-bid';
  }

  /// 指定された取引ペアのCSVファイルプレフィックスを取得
  String getCsvPrefix(TradingPair pair) {
    return '${pair.dukascopyCode}-$dukascopyCode-bid';
  }

  /// 指定された取引ペアのCSVファイル名を取得
  String getCsvFileName(TradingPair pair, DateTime date) {
    final String dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return '${getCsvPrefix(pair)}_$dateStr.csv';
  }
}
