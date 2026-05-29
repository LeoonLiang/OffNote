class SavedTag {
  const SavedTag({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int color;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory SavedTag.fromMap(Map<String, Object?> map) {
    return SavedTag(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      color: map['color'] as int? ?? 0xffd83f5f,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        map['created_at'] as int? ?? 0,
      ),
    );
  }
}
