/// K線選択区域データモデル
class KlineSelection {
  final String id;
  final int startTimestamp; // 開始K線のタイムスタンプ
  final int endTimestamp; // 終了K線のタイムスタンプ
  final int klineCount;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime createdAt;
  final String color;
  final double opacity;

  KlineSelection({
    required this.id,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.klineCount,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    this.color = '#2196F3',
    this.opacity = 0.2,
  });

  /// JSONからオブジェクトを作成
  factory KlineSelection.fromJson(Map<String, dynamic> json) {
    return KlineSelection(
      id: json['id'] as String,
      startTimestamp: json['startTimestamp'] as int,
      endTimestamp: json['endTimestamp'] as int,
      klineCount: json['klineCount'] as int,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      color: json['color'] as String? ?? '#2196F3',
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.2,
    );
  }

  /// JSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTimestamp': startTimestamp,
      'endTimestamp': endTimestamp,
      'klineCount': klineCount,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'color': color,
      'opacity': opacity,
    };
  }

  /// オブジェクトをコピーし特定の属性を変更
  KlineSelection copyWith({
    String? id,
    int? startTimestamp,
    int? endTimestamp,
    int? klineCount,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? createdAt,
    String? color,
    double? opacity,
  }) {
    return KlineSelection(
      id: id ?? this.id,
      startTimestamp: startTimestamp ?? this.startTimestamp,
      endTimestamp: endTimestamp ?? this.endTimestamp,
      klineCount: klineCount ?? this.klineCount,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  String toString() {
    return 'KlineSelection(id: $id, startTimestamp: $startTimestamp, endTimestamp: $endTimestamp, count: $klineCount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KlineSelection && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
