import 'dart:io';

import 'saved_article.dart';

class ArticleStorageStats {
  const ArticleStorageStats({
    required this.articleCount,
    required this.imageArticleCount,
    required this.videoArticleCount,
    required this.categoryCount,
    required this.uncategorizedCount,
    required this.totalBytes,
    required this.htmlBytes,
    required this.imageBytes,
    required this.videoBytes,
    required this.otherBytes,
    required this.averageArticleBytes,
  });

  final int articleCount;
  final int imageArticleCount;
  final int videoArticleCount;
  final int categoryCount;
  final int uncategorizedCount;
  final int totalBytes;
  final int htmlBytes;
  final int imageBytes;
  final int videoBytes;
  final int otherBytes;
  final int averageArticleBytes;

  static ArticleStorageStats calculate({
    required Directory documentsDirectory,
    required List<SavedArticle> articles,
    required int categoryCount,
  }) {
    var totalBytes = 0;
    var htmlBytes = 0;
    var imageBytes = 0;
    var videoBytes = 0;
    var otherBytes = 0;

    final articlesDir = Directory('${documentsDirectory.path}/articles');
    if (articlesDir.existsSync()) {
      for (final entity in articlesDir.listSync(recursive: true)) {
        if (entity is! File) {
          continue;
        }
        final size = entity.lengthSync();
        totalBytes += size;
        final path = entity.path.toLowerCase();
        if (path.endsWith('.html') || path.endsWith('.htm')) {
          htmlBytes += size;
        } else if (_isImagePath(path)) {
          imageBytes += size;
        } else if (_isVideoPath(path)) {
          videoBytes += size;
        } else {
          otherBytes += size;
        }
      }
    }

    final articleCount = articles.length;
    return ArticleStorageStats(
      articleCount: articleCount,
      imageArticleCount: articles
          .where((article) => article.mediaType == ArticleMediaType.image)
          .length,
      videoArticleCount: articles
          .where((article) => article.mediaType == ArticleMediaType.video)
          .length,
      categoryCount: categoryCount,
      uncategorizedCount: articles
          .where((article) => article.categoryId == null)
          .length,
      totalBytes: totalBytes,
      htmlBytes: htmlBytes,
      imageBytes: imageBytes,
      videoBytes: videoBytes,
      otherBytes: otherBytes,
      averageArticleBytes: articleCount == 0 ? 0 : totalBytes ~/ articleCount,
    );
  }

  static bool _isImagePath(String path) {
    return path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.webp') ||
        path.endsWith('.gif');
  }

  static bool _isVideoPath(String path) {
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.m4v');
  }
}
