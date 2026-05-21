class SavedArticle {
  const SavedArticle({
    required this.id,
    required this.title,
    required this.content,
    required this.htmlPath,
    required this.coverPath,
    required this.sourceUrl,
    required this.createdAt,
    this.categoryId,
  });

  final String id;
  final String title;
  final String content;
  final String htmlPath;
  final String? coverPath;
  final String sourceUrl;
  final DateTime createdAt;
  final String? categoryId;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'html_path': htmlPath,
      'cover_path': coverPath,
      'source_url': sourceUrl,
      'created_at': createdAt.millisecondsSinceEpoch,
      'category_id': categoryId,
    };
  }

  static SavedArticle fromMap(Map<String, Object?> map) {
    return SavedArticle(
      id: map['id'] as String,
      title: map['title'] as String? ?? '未命名网页',
      content: map['content'] as String? ?? '',
      htmlPath: map['html_path'] as String,
      coverPath: map['cover_path'] as String?,
      sourceUrl: map['source_url'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      categoryId: map['category_id'] as String?,
    );
  }

  SavedArticle copyWith({String? categoryId}) {
    return SavedArticle(
      id: id,
      title: title,
      content: content,
      htmlPath: htmlPath,
      coverPath: coverPath,
      sourceUrl: sourceUrl,
      createdAt: createdAt,
      categoryId: categoryId,
    );
  }
}
