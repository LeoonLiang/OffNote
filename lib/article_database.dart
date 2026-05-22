import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'saved_article.dart';
import 'saved_category.dart';

class ArticleDatabase {
  ArticleDatabase({
    DatabaseFactory? databaseFactory,
    String? databasePath,
    bool enableFullTextSearch = true,
  }) : _databaseFactory = databaseFactory,
       _databasePath = databasePath,
       _enableFullTextSearch = enableFullTextSearch;

  final DatabaseFactory? _databaseFactory;
  final String? _databasePath;
  final bool _enableFullTextSearch;
  Database? _database;
  bool _articleFtsAvailable = false;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final databasePath = _databasePath ?? await _defaultDatabasePath();
    final database = await (_databaseFactory ?? databaseFactory).openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 4,
        onCreate: (db, version) async {
          await _createSchema(db);
          await _tryCreateArticleFtsSchema(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
            CREATE TABLE IF NOT EXISTS categories (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              color INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
            await db.execute(
              'CREATE INDEX IF NOT EXISTS categories_created_at_idx ON categories(created_at)',
            );
            await db.execute(
              'ALTER TABLE articles ADD COLUMN category_id TEXT',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS articles_category_id_idx ON articles(category_id)',
            );
          }
          if (oldVersion < 3) {
            final ftsCreated = await _tryCreateArticleFtsSchema(db);
            if (ftsCreated) {
              await _rebuildArticleFts(db);
            }
          }
          if (oldVersion < 4) {
            await _addMediaTypeColumn(db);
            await _backfillArticleMediaTypes(db);
          }
        },
      ),
    );
    _articleFtsAvailable = await _hasArticleFtsTable(database);
    _database = database;
    return database;
  }

  Future<String> _defaultDatabasePath() async {
    final supportDir = await getApplicationSupportDirectory();
    return p.join(supportDir.path, 'offnote.db');
  }

  Future<void> _createSchema(Database db) async {
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
    await db.execute(
      'CREATE INDEX articles_created_at_idx ON articles(created_at)',
    );
    await db.execute('CREATE INDEX articles_title_idx ON articles(title)');
    await db.execute(
      'CREATE INDEX articles_category_id_idx ON articles(category_id)',
    );
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX categories_created_at_idx ON categories(created_at)',
    );
  }

  Future<bool> _tryCreateArticleFtsSchema(DatabaseExecutor db) async {
    if (!_enableFullTextSearch) {
      return false;
    }

    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS articles_fts USING fts5(
          id UNINDEXED,
          title,
          content
        )
      ''');
      return true;
    } on DatabaseException catch (error) {
      if (_isMissingFtsModule(error)) {
        return false;
      }
      rethrow;
    }
  }

  bool _isMissingFtsModule(DatabaseException error) {
    final message = error.toString().toLowerCase();
    return message.contains('no such module') && message.contains('fts5');
  }

  Future<bool> _hasArticleFtsTable(Database db) async {
    if (!_enableFullTextSearch) {
      return false;
    }
    final rows = await db.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ? AND name = ?',
      whereArgs: ['table', 'articles_fts'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> _rebuildArticleFts(DatabaseExecutor db) async {
    await db.delete('articles_fts');
    await db.execute('''
      INSERT INTO articles_fts(id, title, content)
      SELECT id, COALESCE(title, ''), COALESCE(content, '') FROM articles
    ''');
  }

  Future<void> _addMediaTypeColumn(DatabaseExecutor db) async {
    await db.execute(
      "ALTER TABLE articles ADD COLUMN media_type TEXT NOT NULL DEFAULT 'image'",
    );
  }

  Future<void> _backfillArticleMediaTypes(DatabaseExecutor db) async {
    final rows = await db.query('articles', columns: ['id', 'html_path']);
    for (final row in rows) {
      final id = row['id'] as String?;
      final htmlPath = row['html_path'] as String?;
      if (id == null || htmlPath == null) {
        continue;
      }
      final mediaType = _inferMediaTypeFromHtmlPath(htmlPath);
      await db.update(
        'articles',
        {'media_type': mediaType.value},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  ArticleMediaType _inferMediaTypeFromHtmlPath(String htmlPath) {
    try {
      final file = File(htmlPath);
      if (!file.existsSync()) {
        return ArticleMediaType.image;
      }
      final html = file.readAsStringSync().toLowerCase();
      if (html.contains('<video') || html.contains('video-player')) {
        return ArticleMediaType.video;
      }
    } catch (_) {
      return ArticleMediaType.image;
    }
    return ArticleMediaType.image;
  }

  Future<void> upsertArticle(SavedArticle article) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(
        'articles',
        article.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (!_articleFtsAvailable) {
        return;
      }
      await txn.delete(
        'articles_fts',
        where: 'id = ?',
        whereArgs: [article.id],
      );
      await txn.insert('articles_fts', {
        'id': article.id,
        'title': article.title,
        'content': article.content,
      });
    });
  }

  Future<List<SavedArticle>> listArticles() async {
    final db = await _db;
    final rows = await db.query('articles', orderBy: 'created_at DESC');
    return rows.map(SavedArticle.fromMap).toList(growable: false);
  }

  Future<List<SavedArticle>> listArticlesByCategory(String categoryId) async {
    final db = await _db;
    final rows = await db.query(
      'articles',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'created_at DESC',
    );
    return rows.map(SavedArticle.fromMap).toList(growable: false);
  }

  Future<List<SavedArticle>> searchArticles(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return listArticles();
    }

    final db = await _db;
    if (!_articleFtsAvailable) {
      return _searchArticlesLike(db, normalized);
    }

    final List<Map<String, Object?>> rows;
    try {
      rows = await db.rawQuery(
        '''
        SELECT articles.*
        FROM articles
        JOIN articles_fts ON articles_fts.id = articles.id
        WHERE articles_fts MATCH ?
        ORDER BY articles.created_at DESC
        ''',
        [_ftsQuery(normalized)],
      );
    } on DatabaseException {
      return _searchArticlesLike(db, normalized);
    }
    if (rows.isEmpty || normalized.runes.length < 3) {
      return _searchArticlesLike(db, normalized);
    }
    return rows.map(SavedArticle.fromMap).toList(growable: false);
  }

  Future<List<SavedArticle>> _searchArticlesLike(
    Database db,
    String query,
  ) async {
    final rows = await db.query(
      'articles',
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'created_at DESC',
    );
    return rows.map(SavedArticle.fromMap).toList(growable: false);
  }

  String _ftsQuery(String query) {
    return query.replaceAll('"', ' ').trim();
  }

  Future<void> deleteArticle(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('articles', where: 'id = ?', whereArgs: [id]);
      if (!_articleFtsAvailable) {
        return;
      }
      await txn.delete('articles_fts', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<SavedCategory>> listCategories() async {
    final db = await _db;
    final rows = await db.query('categories', orderBy: 'created_at DESC');
    return rows.map(SavedCategory.fromMap).toList(growable: false);
  }

  Future<SavedCategory> createCategory(String name, int color) async {
    final category = SavedCategory(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      color: color,
      createdAt: DateTime.now(),
    );
    final db = await _db;
    await db.insert('categories', category.toMap());
    return category;
  }

  Future<void> renameCategory(String id, String name) async {
    final db = await _db;
    await db.update(
      'categories',
      {'name': name.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCategory(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'articles',
        {'category_id': null},
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> assignArticleCategory(
    String articleId,
    String? categoryId,
  ) async {
    final db = await _db;
    await db.update(
      'articles',
      {'category_id': categoryId},
      where: 'id = ?',
      whereArgs: [articleId],
    );
  }
}
