/// 波点データモデル
class WavePoint {
  final int timestamp;
  final double price;
  final String type; // 'high', 'low', or 'interpolated'
  final int? index; // Optional: index in the original PriceData list

  const WavePoint({
    required this.timestamp,
    required this.price,
    required this.type,
    this.index,
  });

  @override
  String toString() {
    return 'WavePoint(timestamp: $timestamp, price: $price, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WavePoint &&
        other.timestamp == timestamp &&
        other.price == price &&
        other.type == type &&
        other.index == index;
  }

  @override
  int get hashCode {
    return timestamp.hashCode ^ price.hashCode ^ type.hashCode ^ index.hashCode;
  }
}
