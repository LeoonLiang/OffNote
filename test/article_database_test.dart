import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/article_database.dart';
import 'package:offnote/saved_article.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late DatabaseFactory databaseFactory;

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
    int createdAt = 1000,
  }) {
    return SavedArticle(
      id: id,
      title: title,
      content: content,
      htmlPath: '/tmp/$id/index.html',
      coverPath: null,
      sourceUrl: 'https://example.com/$id',
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    );
  }

  Future<ArticleDatabase> openTestDatabase(String path) async {
    return ArticleDatabase(
      databaseFactory: databaseFactory,
      databasePath: path,
    );
  }

  Future<ArticleDatabase> openTestDatabaseWithoutFts(String path) async {
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
}
