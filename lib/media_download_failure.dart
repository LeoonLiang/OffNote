enum MediaDownloadFailureKind { images, video }

class MediaDownloadIncompleteException implements Exception {
  const MediaDownloadIncompleteException.images({
    required int failedCount,
    required int totalCount,
    this.reasons = const [],
  }) : kind = MediaDownloadFailureKind.images,
       failedImageCount = failedCount,
       totalImageCount = totalCount,
       videoReason = null;

  const MediaDownloadIncompleteException.video({String? reason})
    : kind = MediaDownloadFailureKind.video,
      failedImageCount = 0,
      totalImageCount = 0,
      reasons = const [],
      videoReason = reason;

  final MediaDownloadFailureKind kind;
  final int failedImageCount;
  final int totalImageCount;
  final List<String> reasons;
  final String? videoReason;

  bool get canConfirmPartial => kind == MediaDownloadFailureKind.images;

  String get summary {
    switch (kind) {
      case MediaDownloadFailureKind.images:
        return '$failedImageCount/$totalImageCount 张图片保存失败';
      case MediaDownloadFailureKind.video:
        return '视频保存失败';
    }
  }

  String get detail {
    if (kind == MediaDownloadFailureKind.video && videoReason != null) {
      return videoReason!;
    }
    return reasons.isEmpty ? summary : reasons.join('\n');
  }

  @override
  String toString() => detail == summary ? summary : '$summary：$detail';
}
