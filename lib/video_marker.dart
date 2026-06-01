class VideoMarker {
  const VideoMarker({
    required this.id,
    required this.articleId,
    required this.position,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String articleId;
  final Duration position;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'article_id': articleId,
      'position_ms': position.inMilliseconds,
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  static VideoMarker fromMap(Map<String, Object?> map) {
    return VideoMarker(
      id: map['id'] as String,
      articleId: map['article_id'] as String,
      position: Duration(milliseconds: _intValue(map['position_ms'])),
      note: map['note'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        _intValue(map['created_at']),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        _intValue(map['updated_at']),
      ),
    );
  }

  VideoMarker copyWith({
    Duration? position,
    String? note,
    DateTime? updatedAt,
  }) {
    return VideoMarker(
      id: id,
      articleId: articleId,
      position: position ?? this.position,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
