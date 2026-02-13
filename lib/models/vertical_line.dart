/// 縦線データモデル
class VerticalLine {
  final String id;
  final int timestamp; // K線タイムスタンプ（主要識別子）
  final String color; // 縦線色（16進数文字列）
  final double width; // 縦線幅
  final DateTime createdAt; // 作成時間

  VerticalLine({
    required this.id,
    required this.timestamp,
    this.color = '#FF0000', // デフォルト赤色
    this.width = 2.0,
    required this.createdAt,
  });

  /// JSONからVerticalLineを作成
  factory VerticalLine.fromJson(Map<String, dynamic> json) {
    return VerticalLine(
      id: json['id'] as String,
      timestamp: json['timestamp'] as int,
      color: json['color'] as String? ?? '#FF0000',
      width: (json['width'] as num?)?.toDouble() ?? 2.0,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp,
      'color': color,
      'width': width,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// コピーして属性を変更
  VerticalLine copyWith({
    String? id,
    int? timestamp,
    String? color,
    double? width,
    DateTime? createdAt,
  }) {
    return VerticalLine(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      color: color ?? this.color,
      width: width ?? this.width,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VerticalLine && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'VerticalLine(id: $id, timestamp: $timestamp, color: $color, width: $width)';
  }
}
