import 'package:intl/intl.dart';

/// EUR/USDの価格データを表現するモデルクラス
class PriceData {
  final int timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const PriceData({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  /// CSVの行からPriceDataオブジェクトを作成するファクトリコンストラクタ
  factory PriceData.fromCsvRow(List<String> row) {
    return PriceData(
      timestamp: int.parse(row[0]),
      open: double.parse(row[1]),
      high: double.parse(row[2]),
      low: double.parse(row[3]),
      close: double.parse(row[4]),
      volume: double.parse(row[5]),
    );
  }

  /// タイムスタンプを日時文字列に変換
  String get formattedDateTime {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    return DateFormat('yyyy-MM-dd HH:mm', 'ja_JP').format(dateTime);
  }

  /// 価格の変化率を計算（前の価格との比較）
  double? calculateChangeRate(PriceData? previousData) {
    if (previousData == null) return null;
    return ((close - previousData.close) / previousData.close) * 100;
  }

  /// 価格の変化を計算
  double? calculateChange(PriceData? previousData) {
    if (previousData == null) return null;
    return close - previousData.close;
  }

  @override
  String toString() {
    return 'PriceData(timestamp: $timestamp, open: $open, high: $high, low: $low, close: $close, volume: $volume)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PriceData &&
        other.timestamp == timestamp &&
        other.open == open &&
        other.high == high &&
        other.low == low &&
        other.close == close &&
        other.volume == volume;
  }

  @override
  int get hashCode {
    return timestamp.hashCode ^
        open.hashCode ^
        high.hashCode ^
        low.hashCode ^
        close.hashCode ^
        volume.hashCode;
  }
}
