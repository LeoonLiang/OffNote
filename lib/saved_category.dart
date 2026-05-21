class SavedCategory {
  const SavedCategory({
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

  static SavedCategory fromMap(Map<String, Object?> map) {
    return SavedCategory(
      id: map['id'] as String,
      name: map['name'] as String? ?? '未命名分类',
      color: map['color'] as int? ?? 0xff51b96b,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
