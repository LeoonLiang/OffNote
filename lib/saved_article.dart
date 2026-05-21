class SavedArticle {
  const SavedArticle({
    required this.id,
    required this.title,
    required this.content,
    required this.htmlPath,
    required this.coverPath,
    required this.sourceUrl,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String content;
  final String htmlPath;
  final String? coverPath;
  final String sourceUrl;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'html_path': htmlPath,
      'cover_path': coverPath,
      'source_url': sourceUrl,
      'created_at': createdAt.millisecondsSinceEpoch,
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
    );
  }
}
