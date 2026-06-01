import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/article_database.dart';
import 'package:offnote/saved_article.dart';
import 'package:offnote/saved_tag.dart';
import 'package:offnote/video_marker.dart';
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
    String? categoryId,
    bool isStarred = false,
  }) {
    return SavedArticle(
      id: id,
      title: title,
      content: content,
      htmlPath: '/tmp/$id/index.html',
      coverPath: null,
      sourceUrl: 'https://example.com/$id',
      originalUrl: 'https://xhslink.com/$id',
      publishedAt: DateTime.fromMillisecondsSinceEpoch(publishedAt),
      savedAt: DateTime.fromMillisecondsSinceEpoch(savedAt),
      mediaType: mediaType,
      imagePaths: imagePaths,
      remark: remark,
      categoryId: categoryId,
      isStarred: isStarred,
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

  test('creates and lists video markers sorted by position', () async {
    final db = await openTestDatabase(inMemoryDatabasePath);

    await db.upsertArticle(
      article(
        id: 'video',
        title: '视频笔记',
        content: '本地视频',
        mediaType: ArticleMediaType.video,
      ),
    );
    await db.upsertVideoMarker(
      VideoMarker(
        id: 'late',
        articleId: 'video',
        position: const Duration(seconds: 40),
        note: '后面的重点',
        createdAt: DateTime.fromMillisecondsSinceEpoch(3000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(3000),
      ),
    );
    await db.upsertVideoMarker(
      VideoMarker(
        id: 'early',
        articleId: 'video',
        position: const Duration(seconds: 12),
        note: '开头的重点',
        createdAt: DateTime.fromMillisecondsSinceEpoch(2000),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      ),
    );

    final markers = await db.listVideoMarkers('video');

    expect(markers.map((marker) => marker.id), ['early', 'late']);
    expect(markers.first.note, '开头的重点');
  });

  test('updates and deletes video markers', () async {
    final db = await openTestDatabase(inMemoryDatabasePath);
    final marker = VideoMarker(
      id: 'm1',
      articleId: 'video',
      position: const Duration(seconds: 12),
      note: '旧记录',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    await db.upsertVideoMarker(marker);

    await db.updateVideoMarker(
      marker.copyWith(
        position: const Duration(seconds: 18),
        note: '新记录',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      ),
    );

    final updated = (await db.listVideoMarkers('video')).single;
    expect(updated.position, const Duration(seconds: 18));
    expect(updated.note, '新记录');
    expect(updated.updatedAt, DateTime.fromMillisecondsSinceEpoch(2000));

    await db.deleteVideoMarker('m1');

    expect(await db.listVideoMarkers('video'), isEmpty);
  });

  test('deletes video markers for one article only', () async {
    final db = await openTestDatabase(inMemoryDatabasePath);
    final now = DateTime.fromMillisecondsSinceEpoch(1000);

    await db.upsertVideoMarker(
      VideoMarker(
        id: 'a1-m1',
        articleId: 'a1',
        position: const Duration(seconds: 1),
        note: 'A1',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await db.upsertVideoMarker(
      VideoMarker(
        id: 'a2-m1',
        articleId: 'a2',
        position: const Duration(seconds: 2),
        note: 'A2',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await db.deleteVideoMarkersForArticle('a1');

    expect(await db.listVideoMarkers('a1'), isEmpty);
    expect((await db.listVideoMarkers('a2')).map((marker) => marker.id), [
      'a2-m1',
    ]);
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

  test('persists the original copied url separately from source url', () async {
    final db = await openTestDatabase(inMemoryDatabasePath);

    await db.upsertArticle(article(id: 'a1', title: '图文笔记', content: '正文'));

    final saved = (await db.listArticles()).single;
    expect(saved.sourceUrl, 'https://example.com/a1');
    expect(saved.originalUrl, 'https://xhslink.com/a1');
  });

  test('persists and filters starred articles', () async {
    final db = await openTestDatabase(inMemoryDatabasePath);

    await db.upsertArticle(
      article(id: 'starred', title: '星标', content: '', isStarred: true),
    );
    await db.upsertArticle(article(id: 'normal', title: '普通', content: ''));

    expect((await db.listStarredArticlesPage()).map((article) => article.id), [
      'starred',
    ]);

    await db.updateArticleStarred('normal', true);
    await db.updateArticleStarred('starred', false);

    expect((await db.listStarredArticlesPage()).map((article) => article.id), [
      'normal',
    ]);
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

  test('lists articles by saved time when requested', () async {
    final db = await openTestDatabase(inMemoryDatabasePath);

    await db.upsertArticle(
      article(id: 'old-save', title: '早保存', content: '', savedAt: 1),
    );
    await db.upsertArticle(
      article(id: 'new-save', title: '晚保存', content: '', savedAt: 3),
    );
    await db.upsertArticle(
      article(id: 'middle-save', title: '中间保存', content: '', savedAt: 2),
    );

    final newest = await db.listArticlesPage(sort: ArticleSort.savedNewest);
    final oldest = await db.listArticlesPage(sort: ArticleSort.savedOldest);

    expect(newest.map((article) => article.id), [
      'new-save',
      'middle-save',
      'old-save',
    ]);
    expect(oldest.map((article) => article.id), [
      'old-save',
      'middle-save',
      'new-save',
    ]);
  });

  test('filters articles by multiple media types and other filters', () async {
    final db = await openTestDatabase(inMemoryDatabasePath);

    await db.upsertArticle(
      article(
        id: 'starred-video',
        title: '视频',
        content: '咖啡',
        publishedAt: 3000,
        mediaType: ArticleMediaType.video,
        isStarred: true,
      ),
    );
    await db.upsertArticle(
      article(
        id: 'starred-image',
        title: '图文',
        content: '咖啡',
        publishedAt: 2000,
        mediaType: ArticleMediaType.image,
        isStarred: true,
      ),
    );
    await db.upsertArticle(
      article(
        id: 'normal-video',
        title: '普通视频',
        content: '咖啡',
        publishedAt: 1000,
        mediaType: ArticleMediaType.video,
      ),
    );

    final videos = await db.listArticlesPage(
      mediaTypes: {ArticleMediaType.video},
    );
    final starredVideos = await db.searchArticlesPage(
      '咖啡',
      starredOnly: true,
      mediaTypes: {ArticleMediaType.video},
    );

    expect(videos.map((article) => article.id), [
      'starred-video',
      'normal-video',
    ]);
    expect(starredVideos.map((article) => article.id), ['starred-video']);
  });

  test(
    'lists uncategorized articles by page ordered by publish time',
    () async {
      final db = await openTestDatabase(inMemoryDatabasePath);

      await db.upsertArticle(
        article(id: 'categorized', title: '分类', content: '', categoryId: 'c1'),
      );
      await db.upsertArticle(
        article(id: 'old', title: '旧', content: '', publishedAt: 1000),
      );
      await db.upsertArticle(
        article(id: 'new', title: '新', content: '', publishedAt: 3000),
      );

      final results = await db.listUncategorizedArticlesPage(limit: 10);

      expect(results.map((article) => article.id), ['new', 'old']);
    },
  );

  test('searches within a category', () async {
    final db = await openTestDatabase(inMemoryDatabasePath);

    await db.upsertArticle(
      article(id: 'match', title: '咖啡', content: '', categoryId: 'food'),
    );
    await db.upsertArticle(
      article(id: 'other', title: '咖啡', content: '', categoryId: 'travel'),
    );

    final results = await db.searchArticlesPage('咖啡', categoryId: 'food');

    expect(results.map((article) => article.id), ['match']);
  });

  test('searches within starred articles', () async {
    final db = await openTestDatabase(inMemoryDatabasePath);

    await db.upsertArticle(
      article(id: 'match', title: '咖啡', content: '', isStarred: true),
    );
    await db.upsertArticle(article(id: 'other', title: '咖啡', content: ''));

    final results = await db.searchArticlesPage('咖啡', starredOnly: true);

    expect(results.map((article) => article.id), ['match']);
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
    'creates tags, assigns multiple tags, and filters by all selected tags',
    () async {
      final db = await openTestDatabase(inMemoryDatabasePath);

      await db.upsertArticle(article(id: 'a1', title: '海边咖啡', content: '日落'));
      await db.upsertArticle(article(id: 'a2', title: '城市咖啡', content: '书店'));
      await db.upsertArticle(article(id: 'a3', title: '海边散步', content: '风景'));
      final travel = await db.createTag('旅行', 0xff51b96b);
      final coffee = await db.createTag('咖啡', 0xffd83f5f);

      await db.setArticleTags('a1', {travel.id, coffee.id});
      await db.setArticleTags('a2', {coffee.id});
      await db.setArticleTags('a3', {travel.id});

      final tagsByArticle = await db.listTagsByArticleIds(['a1', 'a2']);
      final filtered = await db.searchArticlesPage(
        '',
        tagIds: {travel.id, coffee.id},
      );

      expect((await db.listTags()).map((tag) => tag.name), ['咖啡', '旅行']);
      expect(tagsByArticle['a1']!.map((tag) => tag.name), ['咖啡', '旅行']);
      expect(tagsByArticle['a2']!.map((tag) => tag.name), ['咖啡']);
      expect(filtered.map((article) => article.id), ['a1']);
    },
  );

  test(
    'adds and removes batch tags and cleans relations when deleted',
    () async {
      final db = await openTestDatabase(inMemoryDatabasePath);

      await db.upsertArticle(article(id: 'a1', title: '笔记 1', content: ''));
      await db.upsertArticle(article(id: 'a2', title: '笔记 2', content: ''));
      final tag = await db.createTag('待看', 0xff4f8df7);

      await db.addTagsToArticles(['a1', 'a2'], {tag.id});
      expect((await db.listArticleTags('a1')).single.name, '待看');
      expect((await db.listArticleTags('a2')).single.name, '待看');

      await db.removeTagsFromArticles(['a2'], {tag.id});
      expect(await db.listArticleTags('a2'), isEmpty);

      await db.deleteArticle('a1');
      expect(await db.listTagsByArticleIds(['a1']), isEmpty);

      await db.deleteTag(tag.id);
      expect(await db.listTags(), isEmpty);
      expect(await db.listArticleTags('a1'), isEmpty);
    },
  );

  test('renames tags without changing article assignments', () async {
    final db = await openTestDatabase(inMemoryDatabasePath);

    await db.upsertArticle(article(id: 'a1', title: '笔记', content: ''));
    final tag = await db.createTag('待整理', 0xff4f8df7);
    await db.setArticleTags('a1', {tag.id});

    await db.renameTag(tag.id, '已整理');

    expect((await db.listTags()).single.name, '已整理');
    expect((await db.listArticleTags('a1')).single.name, '已整理');
  });

  test('restores tags from an older database migration', () async {
    final path = await databaseFactory.getDatabasesPath();
    final dbPath = '$path/offnote-v8-to-v9-migration-test.db';
    await databaseFactory.deleteDatabase(dbPath);

    final legacyDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE articles (
              id TEXT PRIMARY KEY,
              title TEXT,
              content TEXT,
              html_path TEXT,
              cover_path TEXT,
              source_url TEXT,
              original_url TEXT,
              published_at INTEGER,
              saved_at INTEGER,
              media_type TEXT NOT NULL DEFAULT 'image',
              is_starred INTEGER NOT NULL DEFAULT 0,
              category_id TEXT,
              image_paths TEXT,
              remark TEXT NOT NULL DEFAULT ''
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
        },
      ),
    );
    await legacyDb.close();

    final migratedDb = await openTestDatabase(dbPath);
    final tag = await migratedDb.createTag('迁移后标签', 0xffd83f5f);

    expect(tag, isA<SavedTag>());
    expect((await migratedDb.listTags()).single.name, '迁移后标签');
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

  test('migrates a v6 database to v7 and backfills original url', () async {
    final path = await databaseFactory.getDatabasesPath();
    final dbPath = '$path/offnote-v6-to-v7-migration-test.db';
    await databaseFactory.deleteDatabase(dbPath);

    final legacyDb = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 6,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE articles (
              id TEXT PRIMARY KEY,
              title TEXT,
              content TEXT,
              html_path TEXT,
              cover_path TEXT,
              source_url TEXT,
              published_at INTEGER,
              saved_at INTEGER,
              media_type TEXT NOT NULL DEFAULT 'image',
              category_id TEXT,
              image_paths TEXT,
              remark TEXT NOT NULL DEFAULT ''
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
            'title': 'V6旧文章',
            'content': '迁移测试内容',
            'html_path': '/tmp/old/index.html',
            'cover_path': null,
            'source_url': 'https://www.xiaohongshu.com/discovery/item/old',
            'published_at': 1640000000000,
            'saved_at': 1640000001000,
            'media_type': 'image',
            'category_id': null,
            'image_paths': '[]',
            'remark': '',
          });
        },
      ),
    );
    await legacyDb.close();

    final migratedDb = await openTestDatabase(dbPath);
    final article = (await migratedDb.listArticles()).single;

    expect(article.originalUrl, article.sourceUrl);
  });

  test(
    'migrates a v7 database to v8 and defaults articles to unstarred',
    () async {
      final path = await databaseFactory.getDatabasesPath();
      final dbPath = '$path/offnote-v7-to-v8-migration-test.db';
      await databaseFactory.deleteDatabase(dbPath);

      final legacyDb = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 7,
          onCreate: (db, version) async {
            await db.execute('''
            CREATE TABLE articles (
              id TEXT PRIMARY KEY,
              title TEXT,
              content TEXT,
              html_path TEXT,
              cover_path TEXT,
              source_url TEXT,
              original_url TEXT,
              published_at INTEGER,
              saved_at INTEGER,
              media_type TEXT NOT NULL DEFAULT 'image',
              category_id TEXT,
              image_paths TEXT,
              remark TEXT NOT NULL DEFAULT ''
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
              'title': 'V7旧文章',
              'content': '迁移测试内容',
              'html_path': '/tmp/old/index.html',
              'cover_path': null,
              'source_url': 'https://example.com/old',
              'original_url': 'https://xhslink.com/old',
              'published_at': 1640000000000,
              'saved_at': 1640000001000,
              'media_type': 'image',
              'category_id': null,
              'image_paths': '[]',
              'remark': '',
            });
          },
        ),
      );
      await legacyDb.close();

      final migratedDb = await openTestDatabase(dbPath);
      final article = (await migratedDb.listArticles()).single;

      expect(article.isStarred, isFalse);
    },
  );
}
