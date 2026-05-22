import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/article_storage_stats.dart';
import 'package:offnote/saved_article.dart';

void main() {
  test(
    'calculates storage and article counts by file type and media type',
    () async {
      final root = await Directory.systemTemp.createTemp('offnote-stats-');
      addTearDown(() async {
        if (root.existsSync()) {
          await root.delete(recursive: true);
        }
      });

      final articleDir = Directory('${root.path}/articles/a1');
      await Directory('${articleDir.path}/images').create(recursive: true);
      await Directory('${articleDir.path}/videos').create(recursive: true);
      await File('${articleDir.path}/index.html').writeAsString('html');
      await File('${articleDir.path}/images/a.jpg').writeAsString('image');
      await File('${articleDir.path}/videos/a.mp4').writeAsString('video');

      final stats = ArticleStorageStats.calculate(
        documentsDirectory: root,
        articles: [
          SavedArticle(
            id: 'a1',
            title: '图文',
            content: '',
            htmlPath: '${articleDir.path}/index.html',
            coverPath: '${articleDir.path}/images/a.jpg',
            sourceUrl: 'https://example.com/a1',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            savedAt: DateTime.fromMillisecondsSinceEpoch(2),
            mediaType: ArticleMediaType.image,
            imagePaths: ['${articleDir.path}/images/a.jpg'],
          ),
          SavedArticle(
            id: 'a2',
            title: '视频',
            content: '',
            htmlPath: '/missing/index.html',
            coverPath: null,
            sourceUrl: 'https://example.com/a2',
            publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
            savedAt: DateTime.fromMillisecondsSinceEpoch(2),
            mediaType: ArticleMediaType.video,
          ),
        ],
        categoryCount: 3,
      );

      expect(stats.articleCount, 2);
      expect(stats.imageArticleCount, 1);
      expect(stats.videoArticleCount, 1);
      expect(stats.categoryCount, 3);
      expect(stats.totalBytes, 14);
      expect(stats.htmlBytes, 4);
      expect(stats.imageBytes, 5);
      expect(stats.videoBytes, 5);
      expect(stats.averageArticleBytes, 7);
    },
  );
}
