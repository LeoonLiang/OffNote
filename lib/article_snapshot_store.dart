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
import 'offnote_backup_service.dart';
import 'saved_article.dart';
import 'saved_category.dart';
import 'saved_tag.dart';
import 'video_marker.dart';
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
    String? originalUrl,
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
      final localComments = await _downloadCommentImages(
        comments: snapshot.comments,
        imageDir: imageDir,
        sourceUrl: snapshot.sourceUrl,
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
        comments: localComments,
        commentCount: snapshot.commentCount,
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
        originalUrl: originalUrl ?? sourceUrl,
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
    ArticleSort sort = ArticleSort.publishedNewest,
    Set<ArticleMediaType> mediaTypes = const {},
    Set<String> tagIds = const {},
  }) {
    return _database.listArticlesPage(
      limit: limit,
      offset: offset,
      sort: sort,
      mediaTypes: mediaTypes,
      tagIds: tagIds,
    );
  }

  Future<List<SavedArticle>> listArticlesByCategory(String categoryId) {
    return _database.listArticlesByCategory(categoryId);
  }

  Future<List<SavedArticle>> listArticlesByCategoryPage(
    String categoryId, {
    int limit = 20,
    int offset = 0,
    ArticleSort sort = ArticleSort.publishedNewest,
    Set<ArticleMediaType> mediaTypes = const {},
    Set<String> tagIds = const {},
  }) {
    return _database.listArticlesByCategoryPage(
      categoryId,
      limit: limit,
      offset: offset,
      sort: sort,
      mediaTypes: mediaTypes,
      tagIds: tagIds,
    );
  }

  Future<List<SavedArticle>> listUncategorizedArticlesPage({
    int limit = 20,
    int offset = 0,
    ArticleSort sort = ArticleSort.publishedNewest,
    Set<ArticleMediaType> mediaTypes = const {},
    Set<String> tagIds = const {},
  }) {
    return _database.listUncategorizedArticlesPage(
      limit: limit,
      offset: offset,
      sort: sort,
      mediaTypes: mediaTypes,
      tagIds: tagIds,
    );
  }

  Future<List<SavedArticle>> listStarredArticlesPage({
    int limit = 20,
    int offset = 0,
    ArticleSort sort = ArticleSort.publishedNewest,
    Set<ArticleMediaType> mediaTypes = const {},
    Set<String> tagIds = const {},
  }) {
    return _database.listStarredArticlesPage(
      limit: limit,
      offset: offset,
      sort: sort,
      mediaTypes: mediaTypes,
      tagIds: tagIds,
    );
  }

  Future<List<SavedArticle>> searchArticles(String query) {
    return _database.searchArticles(query);
  }

  Future<List<SavedArticle>> searchArticlesPage(
    String query, {
    int limit = 20,
    int offset = 0,
    String? categoryId,
    bool uncategorizedOnly = false,
    bool starredOnly = false,
    ArticleSort sort = ArticleSort.publishedNewest,
    Set<ArticleMediaType> mediaTypes = const {},
    Set<String> tagIds = const {},
  }) {
    return _database.searchArticlesPage(
      query,
      limit: limit,
      offset: offset,
      categoryId: categoryId,
      uncategorizedOnly: uncategorizedOnly,
      starredOnly: starredOnly,
      sort: sort,
      mediaTypes: mediaTypes,
      tagIds: tagIds,
    );
  }

  Future<List<SavedCategory>> listCategories() => _database.listCategories();

  Future<List<SavedTag>> listTags() => _database.listTags();

  Future<SavedTag> createTag(String name, int color) {
    return _database.createTag(name, color);
  }

  Future<void> renameTag(String id, String name) {
    return _database.renameTag(id, name);
  }

  Future<void> deleteTag(String id) {
    return _database.deleteTag(id);
  }

  Future<List<SavedTag>> listArticleTags(String articleId) {
    return _database.listArticleTags(articleId);
  }

  Future<Map<String, List<SavedTag>>> listTagsByArticleIds(
    Iterable<String> articleIds,
  ) {
    return _database.listTagsByArticleIds(articleIds);
  }

  Future<void> setArticleTags(String articleId, Set<String> tagIds) {
    return _database.setArticleTags(articleId, tagIds);
  }

  Future<void> addTagsToArticles(
    Iterable<String> articleIds,
    Set<String> tagIds,
  ) {
    return _database.addTagsToArticles(articleIds, tagIds);
  }

  Future<void> removeTagsFromArticles(
    Iterable<String> articleIds,
    Set<String> tagIds,
  ) {
    return _database.removeTagsFromArticles(articleIds, tagIds);
  }

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

  Future<void> updateArticleStarred(String articleId, bool isStarred) {
    return _database.updateArticleStarred(articleId, isStarred);
  }

  Future<VideoMarker> createVideoMarker({
    required String articleId,
    required Duration position,
    required String note,
  }) {
    return _database.createVideoMarker(
      articleId: articleId,
      position: position,
      note: note,
    );
  }

  Future<List<VideoMarker>> listVideoMarkers(String articleId) {
    return _database.listVideoMarkers(articleId);
  }

  Future<void> updateVideoMarker(VideoMarker marker) {
    return _database.updateVideoMarker(marker);
  }

  Future<void> deleteVideoMarker(String id) {
    return _database.deleteVideoMarker(id);
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

  Future<File> createBackup() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return OffNoteBackupService(
      database: _database,
      documentsDirectory: documentsDirectory,
    ).createManagedBackup();
  }

  Future<List<OffNoteBackupEntry>> listBackups() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return OffNoteBackupService(
      database: _database,
      documentsDirectory: documentsDirectory,
    ).listBackups();
  }

  Future<OffNoteBackupImportResult> restoreBackup(File backupFile) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return OffNoteBackupService(
      database: _database,
      documentsDirectory: documentsDirectory,
    ).importFromFile(backupFile);
  }

  Future<void> deleteBackup(File backupFile) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return OffNoteBackupService(
      database: _database,
      documentsDirectory: documentsDirectory,
    ).deleteBackup(backupFile);
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

  Future<List<ArticleComment>> _downloadCommentImages({
    required List<ArticleComment> comments,
    required Directory imageDir,
    required String sourceUrl,
  }) async {
    final localized = <ArticleComment>[];
    for (var commentIndex = 0; commentIndex < comments.length; commentIndex++) {
      final comment = comments[commentIndex];
      final localAvatarUri = await _downloadCommentAvatar(
        comment: comment,
        imageDir: imageDir,
        sourceUrl: sourceUrl,
        commentIndex: commentIndex,
      );
      final localUris = <String>[];
      for (
        var imageIndex = 0;
        imageIndex < comment.imageUrls.length;
        imageIndex++
      ) {
        final imageUrl = comment.imageUrls[imageIndex];
        final extension = _extensionForImageUrl(imageUrl);
        final file = File(
          p.join(
            imageDir.path,
            'comment_${commentIndex}_$imageIndex$extension',
          ),
        );
        try {
          await _dio.download(
            imageUrl,
            file.path,
            options: Options(
              followRedirects: true,
              receiveTimeout: const Duration(seconds: 20),
              headers: _downloadHeaders(sourceUrl),
            ),
          );
          localUris.add(file.uri.toString());
        } catch (_) {
          if (file.existsSync()) {
            file.deleteSync();
          }
        }
      }
      localized.add(
        comment.copyWith(
          localAuthorAvatarUri: localAvatarUri,
          localImageUris: localUris,
        ),
      );
    }
    return localized.toList(growable: false);
  }

  Future<String?> _downloadCommentAvatar({
    required ArticleComment comment,
    required Directory imageDir,
    required String sourceUrl,
    required int commentIndex,
  }) async {
    final avatarUrl = comment.authorAvatarUrl;
    if (avatarUrl == null) {
      return null;
    }

    final extension = _extensionForImageUrl(avatarUrl);
    final file = File(
      p.join(imageDir.path, 'comment_avatar_$commentIndex$extension'),
    );
    try {
      await _dio.download(
        avatarUrl,
        file.path,
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(seconds: 20),
          headers: _downloadHeaders(sourceUrl),
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
