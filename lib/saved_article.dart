import 'dart:convert';

enum ArticleMediaType {
  image('image'),
  video('video');

  const ArticleMediaType(this.value);

  final String value;

  static ArticleMediaType fromValue(Object? value) {
    return ArticleMediaType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ArticleMediaType.image,
    );
  }
}

class SavedArticle {
  const SavedArticle({
    required this.id,
    required this.title,
    required this.content,
    required this.htmlPath,
    required this.coverPath,
    required this.sourceUrl,
    String? originalUrl,
    required this.publishedAt,
    required this.savedAt,
    this.imagePaths = const [],
    this.remark = '',
    this.mediaType = ArticleMediaType.image,
    this.isStarred = false,
    this.categoryId,
  }) : originalUrl = originalUrl ?? sourceUrl;

  final String id;
  final String title;
  final String content;
  final String htmlPath;
  final String? coverPath;
  final String sourceUrl;
  final String originalUrl;
  final DateTime publishedAt;
  final DateTime savedAt;
  final List<String> imagePaths;
  final String remark;
  final ArticleMediaType mediaType;
  final bool isStarred;
  final String? categoryId;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'html_path': htmlPath,
      'cover_path': coverPath,
      'source_url': sourceUrl,
      'original_url': originalUrl,
      'published_at': publishedAt.millisecondsSinceEpoch,
      'saved_at': savedAt.millisecondsSinceEpoch,
      'media_type': mediaType.value,
      'is_starred': isStarred ? 1 : 0,
      'category_id': categoryId,
      'image_paths': jsonEncode(imagePaths),
      'remark': remark,
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
      originalUrl:
          map['original_url'] as String? ?? map['source_url'] as String? ?? '',
      publishedAt: DateTime.fromMillisecondsSinceEpoch(
        _intValue(map['published_at']),
      ),
      savedAt: DateTime.fromMillisecondsSinceEpoch(
        _intValue(map['saved_at'] ?? map['published_at']),
      ),
      mediaType: ArticleMediaType.fromValue(map['media_type']),
      isStarred: _intValue(map['is_starred']) == 1,
      categoryId: map['category_id'] as String?,
      imagePaths: _decodeStringList(map['image_paths']),
      remark: map['remark'] as String? ?? '',
    );
  }

  static const _unset = Object();

  SavedArticle copyWith({
    Object? categoryId = _unset,
    String? remark,
    bool? isStarred,
  }) {
    return SavedArticle(
      id: id,
      title: title,
      content: content,
      htmlPath: htmlPath,
      coverPath: coverPath,
      sourceUrl: sourceUrl,
      originalUrl: originalUrl,
      publishedAt: publishedAt,
      savedAt: savedAt,
      imagePaths: imagePaths,
      remark: remark ?? this.remark,
      mediaType: mediaType,
      isStarred: isStarred ?? this.isStarred,
      categoryId: identical(categoryId, _unset)
          ? this.categoryId
          : categoryId as String?,
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

  static List<String> _decodeStringList(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(value);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } catch (_) {
      return const [];
    }
    return const [];
  }
}
