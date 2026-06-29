enum SavedResourceType {
  image('image'),
  videoClip('video_clip');

  const SavedResourceType(this.value);

  final String value;

  static SavedResourceType fromValue(Object? value) {
    return SavedResourceType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => SavedResourceType.image,
    );
  }
}

enum SavedResourceStatus {
  ready('ready'),
  processing('processing'),
  failed('failed');

  const SavedResourceStatus(this.value);

  final String value;

  static SavedResourceStatus fromValue(Object? value) {
    return SavedResourceStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => SavedResourceStatus.ready,
    );
  }
}

class SavedResource {
  const SavedResource({
    required this.id,
    required this.type,
    required this.articleId,
    required this.sourcePath,
    required this.title,
    required this.note,
    required this.createdAt,
    this.previewPath,
    this.originalSourcePath,
    this.status = SavedResourceStatus.ready,
    this.error,
    this.start,
    this.end,
  });

  final String id;
  final SavedResourceType type;
  final String articleId;
  final String sourcePath;
  final String? previewPath;
  final String? originalSourcePath;
  final String title;
  final String note;
  final SavedResourceStatus status;
  final String? error;
  final Duration? start;
  final Duration? end;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'type': type.value,
      'article_id': articleId,
      'source_path': sourcePath,
      'preview_path': previewPath,
      'original_source_path': originalSourcePath,
      'title': title,
      'note': note,
      'status': status.value,
      'error': error,
      'start_ms': start?.inMilliseconds,
      'end_ms': end?.inMilliseconds,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory SavedResource.fromMap(Map<String, Object?> map) {
    return SavedResource(
      id: map['id'] as String,
      type: SavedResourceType.fromValue(map['type']),
      articleId: map['article_id'] as String? ?? '',
      sourcePath: map['source_path'] as String? ?? '',
      previewPath: map['preview_path'] as String?,
      originalSourcePath: map['original_source_path'] as String?,
      title: map['title'] as String? ?? '',
      note: map['note'] as String? ?? '',
      status: SavedResourceStatus.fromValue(map['status']),
      error: map['error'] as String?,
      start: _durationFromMs(map['start_ms']),
      end: _durationFromMs(map['end_ms']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        _intValue(map['created_at']),
      ),
    );
  }

  static Duration? _durationFromMs(Object? value) {
    if (value == null) {
      return null;
    }
    return Duration(milliseconds: _intValue(value));
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

bool savedResourceHasSourceArticle(SavedResource resource) {
  return resource.articleId.trim().isNotEmpty;
}
