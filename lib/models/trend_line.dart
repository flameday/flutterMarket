/// 斜线（趋势线）数据模型
class TrendLine {
  final String id;
  final int startIndex;
  final double startPrice;
  final int endIndex;
  final double endPrice;
  final String color;
  final double width;

  const TrendLine({
    required this.id,
    required this.startIndex,
    required this.startPrice,
    required this.endIndex,
    required this.endPrice,
    this.color = '#FFD700',
    this.width = 2.0,
  });

  TrendLine copyWith({
    String? id,
    int? startIndex,
    double? startPrice,
    int? endIndex,
    double? endPrice,
    String? color,
    double? width,
  }) {
    return TrendLine(
      id: id ?? this.id,
      startIndex: startIndex ?? this.startIndex,
      startPrice: startPrice ?? this.startPrice,
      endIndex: endIndex ?? this.endIndex,
      endPrice: endPrice ?? this.endPrice,
      color: color ?? this.color,
      width: width ?? this.width,
    );
  }
}
