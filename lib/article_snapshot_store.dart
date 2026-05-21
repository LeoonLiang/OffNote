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
    await imageDir.create(recursive: true);

    final localImageUrisByUrl = await _downloadImages(
      snapshot: snapshot,
      imageDir: imageDir,
    );
    final localAuthorAvatarUri = await _downloadAuthorAvatar(
      snapshot: snapshot,
      imageDir: imageDir,
    );
    final rewrittenHtml = buildXhsOfflineHtml(
      title: snapshot.title,
      content: snapshot.content,
      localImageUris: snapshot.imageUrls
          .map((url) => localImageUrisByUrl[url])
          .whereType<String>()
          .toList(growable: false),
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
      coverPath: localImages.isEmpty ? null : localImages.first.path,
      sourceUrl: sourceUrl,
      createdAt: DateTime.now(),
    );
    await _database.upsertArticle(article);
    debugPrint(
      'Saved snapshot title="${snapshot.title}" images=${localImageUrisByUrl.length} content=${snapshot.content.length} html=${htmlFile.path}',
    );
    return article;
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
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
            },
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
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15',
          },
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
}
