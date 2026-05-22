import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/article_database.dart';
import 'package:offnote/saved_article.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseFactory databaseFactory;
  var databaseCounter = 0;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    databaseFactory = databaseFactoryFfi;
  });

  SavedArticle article({
    required String id,
    required String title,
    required String content,
    ArticleMediaType mediaType = ArticleMediaType.image,
    int publishedAt = 1000,
    int savedAt = 2000,
    List<String> imagePaths = const [],
    String remark = '',
  }) {
    return SavedArticle(
      id: id,
      title: title,
      content: content,
      htmlPath: '/tmp/$id/index.html',
      coverPath: null,
      sourceUrl: 'https://example.com/$id',
      publishedAt: DateTime.fromMillisecondsSinceEpoch(publishedAt),
      savedAt: DateTime.fromMillisecondsSinceEpoch(savedAt),
      mediaType: mediaType,
      imagePaths: imagePaths,
      remark: remark,
    );
  }

  Future<ArticleDatabase> openTestDatabase(String path) async {
    if (path == inMemoryDatabasePath) {
      final root = await databaseFactory.getDatabasesPath();
      path = '$root/offnote-test-${databaseCounter++}.db';
      await databaseFactory.deleteDatabase(path);
    }
    return ArticleDatabase(
      databaseFactory: databaseFactory,
      databasePath: path,
    );
  }

  Future<ArticleDatabase> openTestDatabaseWithoutFts(String path) async {
    if (path == inMemoryDatabasePath) {
      final root = await databaseFactory.getDatabasesPath();
      path = '$root/offnote-test-no-fts-${databaseCounter++}.db';
      await databaseFactory.deleteDatabase(path);
    }
    return ArticleDatabase(
      databaseFactory: databaseFactory,
      databasePath: path,
      enableFullTextSearch: false,
    );
  }

  test('creates the FTS table for a new database', () async {
    final db = await openTestDatabase(inMemoryDatabasePath);

    await db.upsertArticle(
      article(id: 'a1', title: '格木村徒步', content: '扎营格聂雪山'),
    );

    final results = await db.searchArticles('雪山');
    expect(results.map((article) => article.id), ['a1']);
  });

  test('persists article media type', () async {
    final db = await openTestDatabase(inMemoryDatabasePath);

    await db.upsertArticle(
      article(
        id: 'video',
        title: '视频笔记',
        content: '本地视频',
        mediaType: ArticleMediaType.video,
      ),
    );

    final saved = (await db.listArticles()).firstWhere(
      (article) => article.id == 'video',
    );
    expect(saved.mediaType, ArticleMediaType.video);
  });

  test('persists image paths and remark', () async {
    final db = await openTestDatabase(inMemoryDatabasePath);

    await db.upsertArticle(
      article(
        id: 'a1',
        title: '图文笔记',
        content: '正文',
        imagePaths: ['/tmp/a.jpg', '/tmp/b.jpg'],
        remark: '下次复盘用',
      ),
    );

    final saved = (await db.listArticles()).single;
    expect(saved.imagePaths, ['/tmp/a.jpg', '/tmp/b.jpg']);
    expect(saved.remark, '下次复盘用');
  });

  test('lists articles by page ordered by publish time', () async {
    final db = await openTestDatabase(inMemoryDatabasePath);

    await db.upsertArticle(
      article(id: 'old', title: '旧', content: '', publishedAt: 1),
    );
    await db.upsertArticle(
      article(id: 'middle', title: '中', content: '', publishedAt: 2),
    );
    await db.upsertArticle(
      article(id: 'new', title: '新', content: '', publishedAt: 3),
    );

    final firstPage = await db.listArticlesPage(limit: 2, offset: 0);
    final secondPage = await db.listArticlesPage(limit: 2, offset: 2);

    expect(firstPage.map((article) => article.id), ['new', 'middle']);
    expect(secondPage.map((article) => article.id), ['old']);
  });

  test('updates and searches article remarks', () async {
    final db = await openTestDatabase(inMemoryDatabasePath);

    await db.upsertArticle(article(id: 'a1', title: '普通标题', content: '普通正文'));
    await db.updateArticleRemark('a1', '这里有雪山行程');

    final results = await db.searchArticles('雪山行程');

    expect(results.map((article) => article.id), ['a1']);
    expect(results.single.remark, '这里有雪山行程');
  });

  test(
    'keeps FTS search in sync when articles are updated and deleted',
    () async {
      final db = await openTestDatabase(inMemoryDatabasePath);

      await db.upsertArticle(
        article(id: 'a1', title: '格木村徒步', content: '扎营格聂雪山'),
      );
      await db.upsertArticle(
        article(id: 'a1', title: '城市散步', content: '咖啡和书店'),
      );

      expect(await db.searchArticles('雪山'), isEmpty);
      expect((await db.searchArticles('咖啡')).single.id, 'a1');

      await db.deleteArticle('a1');

      expect(await db.searchArticles('咖啡'), isEmpty);
    },
  );

  test('falls back safely when the search query contains FTS syntax', () async {
    final db = await openTestDatabase(inMemoryDatabasePath);

    await db.upsertArticle(
      article(id: 'a1', title: '离线保存', content: '特殊符号 a-b 也能搜索'),
    );

    expect((await db.searchArticles('a-b')).single.id, 'a1');
  });

  test('saves and searches with LIKE when FTS is unavailable', () async {
    final db = await openTestDatabaseWithoutFts(inMemoryDatabasePath);

    await db.upsertArticle(
      article(id: 'a1', title: '离线保存', content: '没有 FTS 也不能影响保存'),
    );

    expect((await db.searchArticles('FTS')).single.id, 'a1');
    await db.deleteArticle('a1');
    expect(await db.searchArticles('FTS'), isEmpty);
  });

  test(
    'migrates a v2 database and backfills existing articles into FTS',
    () async {
      final path = await databaseFactory.getDatabasesPath();
      final dbPath = '$path/offnote-migration-test.db';
      await databaseFactory.deleteDatabase(dbPath);
      final legacyDb = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute('''
          CREATE TABLE articles (
            id TEXT PRIMARY KEY,
            title TEXT,
            content TEXT,
            html_path TEXT,
            cover_path TEXT,
            source_url TEXT,
            created_at INTEGER,
            category_id TEXT
          )
        ''');
            await db.execute('''
          CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            color INTEGER NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
            await db.insert('articles', {
              'id': 'legacy',
              'title': '旧文章',
              'content': '迁移后应该能搜到格聂',
              'html_path': '/tmp/legacy/index.html',
              'cover_path': null,
              'source_url': 'https://example.com/legacy',
              'created_at': 1000,
              'category_id': null,
            });
          },
        ),
      );
      await legacyDb.close();

      final migratedDb = await openTestDatabase(dbPath);

      expect((await migratedDb.searchArticles('格聂')).single.id, 'legacy');
    },
  );

  test(
    'migrates a v3 database and infers media type from saved html',
    () async {
      final path = await databaseFactory.getDatabasesPath();
      final dbPath = '$path/offnote-media-type-migration-test.db';
      await databaseFactory.deleteDatabase(dbPath);

      final imageHtml = File('$path/legacy-image.html');
      final videoHtml = File('$path/legacy-video.html');
      await imageHtml.writeAsString(
        '<html><body><img src="a.jpg"></body></html>',
      );
      await videoHtml.writeAsString(
        '<html><body><video class="video-player"></video></body></html>',
      );

      final legacyDb = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE articles (
              id TEXT PRIMARY KEY,
              title TEXT,
              content TEXT,
              html_path TEXT,
              cover_path TEXT,
              source_url TEXT,
              created_at INTEGER,
              category_id TEXT
            )
          ''');
            await db.execute('''
            CREATE TABLE categories (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              color INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
            await db.insert('articles', {
              'id': 'image',
              'title': '旧图文',
              'content': '图片内容',
              'html_path': imageHtml.path,
              'cover_path': null,
              'source_url': 'https://example.com/image',
              'created_at': 1000,
              'category_id': null,
            });
            await db.insert('articles', {
              'id': 'video',
              'title': '旧视频',
              'content': '视频内容',
              'html_path': videoHtml.path,
              'cover_path': null,
              'source_url': 'https://example.com/video',
              'created_at': 2000,
              'category_id': null,
            });
          },
        ),
      );
      await legacyDb.close();

      final migratedDb = await openTestDatabase(dbPath);
      final articles = await migratedDb.listArticles();

      final mediaTypesById = {
        for (final article in articles) article.id: article.mediaType,
      };
      expect(mediaTypesById['image'], ArticleMediaType.image);
      expect(mediaTypesById['video'], ArticleMediaType.video);
    },
  );

  test(
    'migrates a v4 database to v5 with published_at and image_paths',
    () async {
      final path = await databaseFactory.getDatabasesPath();
      final dbPath = '$path/offnote-v4-to-v5-migration-test.db';
      await databaseFactory.deleteDatabase(dbPath);

      final legacyDb = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE articles (
              id TEXT PRIMARY KEY,
              title TEXT,
              content TEXT,
              html_path TEXT,
              cover_path TEXT,
              source_url TEXT,
              created_at INTEGER,
              media_type TEXT NOT NULL DEFAULT 'image',
              category_id TEXT
            )
          ''');
            await db.execute('''
            CREATE TABLE categories (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              color INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
            await db.insert('articles', {
              'id': 'old-article',
              'title': 'V4旧文章',
              'content': '迁移测试内容',
              'html_path': '/tmp/old/index.html',
              'cover_path': null,
              'source_url': 'https://example.com/old',
              'created_at': 1640000000000,
              'media_type': 'image',
              'category_id': null,
            });
          },
        ),
      );
      await legacyDb.close();

      final migratedDb = await openTestDatabase(dbPath);

      // After migration, we should be able to get articles
      final articles = await migratedDb.listArticles();
      expect(articles.length, 1);

      // The article should have been migrated with the correct timestamp
      final article = articles.first;
      expect(article.id, 'old-article');
      // This tests that created_at was migrated to publishedAt
      expect(article.publishedAt.millisecondsSinceEpoch, 1640000000000);
    },
  );
}
