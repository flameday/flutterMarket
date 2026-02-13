/// 手動で追加された高低点データモデル
class ManualHighLowPoint {
  /// 一意のID
  final String id;
  
  /// K線のタイムスタンプ
  final int timestamp;
  
  /// 価格（高値または安値）
  final double price;
  
  /// 高低点のタイプ（true: 高値, false: 安値）
  final bool isHigh;
  
  /// 作成日時
  final DateTime createdAt;
  
  /// 備考
  final String? note;
  
  /// 時間周期（5分、30分、4時間など）
  final String? timeframe;

  const ManualHighLowPoint({
    required this.id,
    required this.timestamp,
    required this.price,
    required this.isHigh,
    required this.createdAt,
    this.note,
    this.timeframe,
  });

  /// JSONからオブジェクトを作成
  factory ManualHighLowPoint.fromJson(Map<String, dynamic> json) {
    return ManualHighLowPoint(
      id: json['id'] as String,
      timestamp: json['timestamp'] as int,
      price: (json['price'] as num).toDouble(),
      isHigh: json['isHigh'] as bool,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      note: json['note'] as String?,
      timeframe: json['timeframe'] as String?,
    );
  }

  /// オブジェクトをJSONに変換
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp,
      'price': price,
      'isHigh': isHigh,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'note': note,
      'timeframe': timeframe,
    };
  }

  /// オブジェクトをコピーして新しいオブジェクトを作成
  ManualHighLowPoint copyWith({
    String? id,
    int? timestamp,
    double? price,
    bool? isHigh,
    DateTime? createdAt,
    String? note,
    String? timeframe,
  }) {
    return ManualHighLowPoint(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      price: price ?? this.price,
      isHigh: isHigh ?? this.isHigh,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
      timeframe: timeframe ?? this.timeframe,
    );
  }

  @override
  String toString() {
    return 'ManualHighLowPoint(id: $id, timestamp: $timestamp, price: $price, isHigh: $isHigh, createdAt: $createdAt, note: $note, timeframe: $timeframe)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ManualHighLowPoint &&
        other.id == id &&
        other.timestamp == timestamp &&
        other.price == price &&
        other.isHigh == isHigh &&
        other.createdAt == createdAt &&
        other.note == note &&
        other.timeframe == timeframe;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        timestamp.hashCode ^
        price.hashCode ^
        isHigh.hashCode ^
        createdAt.hashCode ^
        note.hashCode ^
        timeframe.hashCode;
  }
}
