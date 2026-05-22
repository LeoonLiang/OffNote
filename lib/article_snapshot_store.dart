import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'article_database.dart';
import 'article_file_paths.dart';
import 'article_snapshot.dart';
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
  }) async {
    final snapshot = parseArticleSnapshot(html: rawHtml, sourceUrl: sourceUrl);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final root = await getApplicationDocumentsDirectory();
    final articleDir = Directory(p.join(root.path, 'articles', id));
    final imageDir = Directory(p.join(articleDir.path, 'images'));
    final videoDir = Directory(p.join(articleDir.path, 'videos'));
    try {
      await imageDir.create(recursive: true);

      final localImageUrisByUrl = await _downloadImages(
        snapshot: snapshot,
        imageDir: imageDir,
      );
      final localVideoUri = await _downloadVideo(
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
      final failedImageCount =
          snapshot.imageUrls.length - localImageUrisByUrl.length;
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
      final article = SavedArticle(
        id: id,
        title: snapshot.title,
        content: snapshot.content,
        htmlPath: htmlFile.path,
        coverPath:
            _filePathFromFileUri(localPosterUri) ??
            (localImages.isEmpty ? null : localImages.first.path),
        sourceUrl: sourceUrl,
        createdAt: DateTime.now(),
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

  Future<List<SavedArticle>> listArticlesByCategory(String categoryId) {
    return _database.listArticlesByCategory(categoryId);
  }

  Future<List<SavedArticle>> searchArticles(String query) {
    return _database.searchArticles(query);
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

  Future<Map<String, String>> _downloadImages({
    required ArticleSnapshot snapshot,
    required Directory imageDir,
  }) async {
    final localImageUrisByUrl = <String, String>{};

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
      } catch (_) {
        if (file.existsSync()) {
          file.deleteSync();
        }
      }
    }

    return localImageUrisByUrl;
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

  Future<String?> _downloadVideo({
    required ArticleSnapshot snapshot,
    required Directory videoDir,
  }) async {
    final videoUrl = snapshot.videoUrl;
    if (videoUrl == null) {
      return null;
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
      return file.uri.toString();
    } catch (_) {
      if (file.existsSync()) {
        file.deleteSync();
      }
      return null;
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
}
