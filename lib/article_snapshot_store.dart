import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'article_database.dart';
import 'article_file_paths.dart';
import 'article_snapshot.dart';
import 'article_storage_stats.dart';
import 'media_download_failure.dart';
import 'saved_article.dart';
import 'saved_category.dart';
import 'xhs_offline_html.dart';

class ArticleSnapshotStore {
  ArticleSnapshotStore({Dio? dio, ArticleDatabase? database})
    : _dio = dio ?? Dio(),
      _database = database ?? ArticleDatabase();

  final Dio _dio;
  final ArticleDatabase _database;

  Future<SavedArticle> save({
    required String rawHtml,
    required String sourceUrl,
    bool allowPartialMedia = false,
  }) async {
    final snapshot = parseArticleSnapshot(html: rawHtml, sourceUrl: sourceUrl);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final root = await getApplicationDocumentsDirectory();
    final articleDir = Directory(p.join(root.path, 'articles', id));
    final imageDir = Directory(p.join(articleDir.path, 'images'));
    final videoDir = Directory(p.join(articleDir.path, 'videos'));
    try {
      await imageDir.create(recursive: true);

      final imageDownloads = await _downloadImages(
        snapshot: snapshot,
        imageDir: imageDir,
      );
      final videoDownload = await _downloadVideo(
        snapshot: snapshot,
        videoDir: videoDir,
      );
      final localPosterUri = await _downloadPoster(
        snapshot: snapshot,
        imageDir: imageDir,
      );
      final localAuthorAvatarUri = await _downloadAuthorAvatar(
        snapshot: snapshot,
        imageDir: imageDir,
      );
      final localImageUrisByUrl = imageDownloads.localUrisByUrl;
      final localVideoUri = videoDownload.localUri;
      final failedImageCount =
          snapshot.imageUrls.length - localImageUrisByUrl.length;
      if (!allowPartialMedia) {
        if (snapshot.videoUrl != null && localVideoUri == null) {
          throw MediaDownloadIncompleteException.video(
            reason: videoDownload.failureReason ?? '视频文件没有下载完成',
          );
        }
        if (failedImageCount > 0) {
          throw MediaDownloadIncompleteException.images(
            failedCount: failedImageCount,
            totalCount: snapshot.imageUrls.length,
            reasons: imageDownloads.failureReasons,
          );
        }
      }
      final rewrittenHtml = buildXhsOfflineHtml(
        title: snapshot.title,
        content: snapshot.content,
        localImageUris: snapshot.imageUrls
            .map((url) => localImageUrisByUrl[url])
            .whereType<String>()
            .toList(growable: false),
        localVideoUri: localVideoUri,
        localPosterUri: localPosterUri,
        failedImageCount: failedImageCount,
        videoDownloadFailed: snapshot.videoUrl != null && localVideoUri == null,
        authorName: snapshot.authorName,
        authorAvatarUri: localAuthorAvatarUri,
      );
      final htmlFile = File(p.join(articleDir.path, 'index.html'));
      await htmlFile.writeAsString(rewrittenHtml);

      final localImages = imageDir.existsSync()
          ? imageDir.listSync().whereType<File>().toList(growable: false)
          : <File>[];
      final downloadedImagePaths = snapshot.imageUrls
          .map((url) => localImageUrisByUrl[url])
          .map(_filePathFromFileUri)
          .whereType<String>()
          .toList(growable: false);
      final now = DateTime.now();
      final article = SavedArticle(
        id: id,
        title: snapshot.title,
        content: snapshot.content,
        htmlPath: htmlFile.path,
        coverPath:
            _filePathFromFileUri(localPosterUri) ??
            (localImages.isEmpty ? null : localImages.first.path),
        sourceUrl: sourceUrl,
        publishedAt: snapshot.publishedAt ?? now,
        savedAt: now,
        imagePaths: downloadedImagePaths,
        mediaType: snapshot.videoUrl == null
            ? ArticleMediaType.image
            : ArticleMediaType.video,
      );
      await _database.upsertArticle(article);
      debugPrint(
        'Saved snapshot title="${snapshot.title}" images=${localImageUrisByUrl.length}/${snapshot.imageUrls.length} content=${snapshot.content.length} html=${htmlFile.path}',
      );
      return article;
    } catch (_) {
      if (articleDir.existsSync()) {
        await articleDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<List<SavedArticle>> listArticles() => _database.listArticles();

  Future<List<SavedArticle>> listArticlesPage({
    int limit = 20,
    int offset = 0,
  }) {
    return _database.listArticlesPage(limit: limit, offset: offset);
  }

  Future<List<SavedArticle>> listArticlesByCategory(String categoryId) {
    return _database.listArticlesByCategory(categoryId);
  }

  Future<List<SavedArticle>> listArticlesByCategoryPage(
    String categoryId, {
    int limit = 20,
    int offset = 0,
  }) {
    return _database.listArticlesByCategoryPage(
      categoryId,
      limit: limit,
      offset: offset,
    );
  }

  Future<List<SavedArticle>> searchArticles(String query) {
    return _database.searchArticles(query);
  }

  Future<List<SavedArticle>> searchArticlesPage(
    String query, {
    int limit = 20,
    int offset = 0,
  }) {
    return _database.searchArticlesPage(query, limit: limit, offset: offset);
  }

  Future<List<SavedCategory>> listCategories() => _database.listCategories();

  Future<SavedCategory> createCategory(String name, int color) {
    return _database.createCategory(name, color);
  }

  Future<void> renameCategory(String id, String name) {
    return _database.renameCategory(id, name);
  }

  Future<void> deleteCategory(String id) {
    return _database.deleteCategory(id);
  }

  Future<void> assignArticleCategory(String articleId, String? categoryId) {
    return _database.assignArticleCategory(articleId, categoryId);
  }

  Future<void> updateArticleRemark(String articleId, String remark) {
    return _database.updateArticleRemark(articleId, remark);
  }

  Future<ArticleStorageStats> loadStorageStats() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final articles = await _database.listArticles();
    final categories = await _database.listCategories();
    return ArticleStorageStats.calculate(
      documentsDirectory: documentsDirectory,
      articles: articles,
      categoryCount: categories.length,
    );
  }

  Future<void> deleteArticle(SavedArticle article) async {
    await _database.deleteArticle(article.id);
    final articleDir = Directory(
      articleDirectoryPathFromHtmlPath(article.htmlPath),
    );
    if (articleDir.existsSync()) {
      await articleDir.delete(recursive: true);
    }
    debugPrint('Deleted snapshot id=${article.id} html=${article.htmlPath}');
  }

  Future<void> deleteArticles(Iterable<SavedArticle> articles) async {
    final items = articles.toList(growable: false);
    await _database.deleteArticles(items.map((article) => article.id));
    for (final article in items) {
      final articleDir = Directory(
        articleDirectoryPathFromHtmlPath(article.htmlPath),
      );
      if (articleDir.existsSync()) {
        await articleDir.delete(recursive: true);
      }
    }
  }

  Future<_ImageDownloadResult> _downloadImages({
    required ArticleSnapshot snapshot,
    required Directory imageDir,
  }) async {
    final localImageUrisByUrl = <String, String>{};
    final failureReasons = <String>[];

    for (var index = 0; index < snapshot.imageUrls.length; index++) {
      final imageUrl = snapshot.imageUrls[index];
      final extension = _extensionForImageUrl(imageUrl);
      final file = File(p.join(imageDir.path, 'image_$index$extension'));
      try {
        await _dio.download(
          imageUrl,
          file.path,
          options: Options(
            followRedirects: true,
            receiveTimeout: const Duration(seconds: 20),
            headers: _downloadHeaders(snapshot.sourceUrl),
          ),
        );
        localImageUrisByUrl[imageUrl] = file.uri.toString();
      } catch (error) {
        if (file.existsSync()) {
          file.deleteSync();
        }
        failureReasons.add('第 ${index + 1} 张图片下载失败：${_briefError(error)}');
      }
    }

    return _ImageDownloadResult(
      localUrisByUrl: localImageUrisByUrl,
      failureReasons: failureReasons,
    );
  }

  Future<String?> _downloadAuthorAvatar({
    required ArticleSnapshot snapshot,
    required Directory imageDir,
  }) async {
    final avatarUrl = snapshot.authorAvatarUrl;
    if (avatarUrl == null) {
      return null;
    }

    final file = File(p.join(imageDir.path, 'author_avatar.jpg'));
    try {
      await _dio.download(
        avatarUrl,
        file.path,
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 20),
          headers: _downloadHeaders(snapshot.sourceUrl),
        ),
      );
      return file.uri.toString();
    } catch (_) {
      if (file.existsSync()) {
        file.deleteSync();
      }
      return null;
    }
  }

  Future<String?> _downloadPoster({
    required ArticleSnapshot snapshot,
    required Directory imageDir,
  }) async {
    final posterUrl = snapshot.posterUrl;
    if (posterUrl == null) {
      return null;
    }

    final file = File(p.join(imageDir.path, 'poster.jpg'));
    try {
      await _dio.download(
        posterUrl,
        file.path,
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 20),
          headers: _downloadHeaders(snapshot.sourceUrl),
        ),
      );
      return file.uri.toString();
    } catch (_) {
      if (file.existsSync()) {
        file.deleteSync();
      }
      return null;
    }
  }

  Future<_MediaDownloadResult> _downloadVideo({
    required ArticleSnapshot snapshot,
    required Directory videoDir,
  }) async {
    final videoUrl = snapshot.videoUrl;
    if (videoUrl == null) {
      return const _MediaDownloadResult();
    }

    await videoDir.create(recursive: true);
    final file = File(
      p.join(videoDir.path, 'video_0${_extensionForVideoUrl(videoUrl)}'),
    );
    try {
      await _dio.download(
        videoUrl,
        file.path,
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 2),
          headers: _downloadHeaders(snapshot.sourceUrl),
        ),
      );
      return _MediaDownloadResult(localUri: file.uri.toString());
    } catch (error) {
      if (file.existsSync()) {
        file.deleteSync();
      }
      return _MediaDownloadResult(
        failureReason: '视频下载失败：${_briefError(error)}',
      );
    }
  }

  String _extensionForImageUrl(String imageUrl) {
    final path = Uri.parse(imageUrl).path.toLowerCase();
    for (final extension in ['.jpg', '.jpeg', '.png', '.webp', '.gif']) {
      if (path.endsWith(extension)) {
        return extension;
      }
    }
    return '.jpg';
  }

  String _extensionForVideoUrl(String videoUrl) {
    final path = Uri.parse(videoUrl).path.toLowerCase();
    for (final extension in ['.mp4', '.mov', '.m4v']) {
      if (path.endsWith(extension)) {
        return extension;
      }
    }
    return '.mp4';
  }

  Map<String, String> _downloadHeaders(String sourceUrl) {
    return {
      'User-Agent':
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
      'Referer': sourceUrl,
    };
  }

  String? _filePathFromFileUri(String? uri) {
    if (uri == null) {
      return null;
    }
    final parsed = Uri.tryParse(uri);
    if (parsed == null || parsed.scheme != 'file') {
      return null;
    }
    return parsed.toFilePath();
  }

  String _briefError(Object error) {
    if (error is DioException) {
      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!.trim();
      }
      return error.type.name;
    }
    return error.toString();
  }
}

class _ImageDownloadResult {
  const _ImageDownloadResult({
    required this.localUrisByUrl,
    required this.failureReasons,
  });

  final Map<String, String> localUrisByUrl;
  final List<String> failureReasons;
}

class _MediaDownloadResult {
  const _MediaDownloadResult({this.localUri, this.failureReason});

  final String? localUri;
  final String? failureReason;
}
