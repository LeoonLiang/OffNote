import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'saved_article.dart';
import 'saved_category.dart';
import 'saved_resource.dart';
import 'saved_tag.dart';
import 'video_marker.dart';

enum ArticleSort {
  publishedNewest('published_at DESC'),
  savedNewest('saved_at DESC'),
  savedOldest('saved_at ASC');

  const ArticleSort(this.orderBy);

  final String orderBy;
}

class _ArticleFilter {
  const _ArticleFilter({required this.where, required this.args});

  final String? where;
  final List<Object?>? args;
}

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
        version: 12,
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
            await _tryCreateArticleFtsSchema(db);
          }
          if (oldVersion < 4) {
            await _addMediaTypeColumn(db);
            await _backfillArticleMediaTypes(db);
          }
          if (oldVersion < 5) {
            await _migrateToPublishedAt(db);
          }
          if (oldVersion < 6) {
            await _migrateToSavedAtAndRemark(db);
          }
          if (oldVersion < 7) {
            await _migrateToOriginalUrl(db);
          }
          if (oldVersion < 8) {
            await _migrateToStarred(db);
          }
          if (oldVersion < 9) {
            await _createTagSchema(db);
          }
          if (oldVersion < 10) {
            await _createVideoMarkerSchema(db);
          }
          if (oldVersion < 11) {
            await _createResourceSchema(db);
          }
          if (oldVersion < 12) {
            await _migrateResourceProcessingFields(db);
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
    await db.execute(
      'CREATE INDEX articles_published_at_idx ON articles(published_at)',
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
    await _createTagSchema(db);
    await _createVideoMarkerSchema(db);
    await _createResourceSchema(db);
  }

  Future<void> _createTagSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color INTEGER NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS tags_created_at_idx ON tags(created_at)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS article_tags (
        article_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY(article_id, tag_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS article_tags_article_id_idx ON article_tags(article_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS article_tags_tag_id_idx ON article_tags(tag_id)',
    );
  }

  Future<void> _createVideoMarkerSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS video_markers (
        id TEXT PRIMARY KEY,
        article_id TEXT NOT NULL,
        position_ms INTEGER NOT NULL,
        note TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS video_markers_article_position_idx ON video_markers(article_id, position_ms, created_at)',
    );
  }

  Future<void> _createResourceSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_resources (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        article_id TEXT NOT NULL,
        source_path TEXT NOT NULL,
        preview_path TEXT,
        original_source_path TEXT,
        title TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'ready',
        error TEXT,
        start_ms INTEGER,
        end_ms INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS saved_resources_created_at_idx ON saved_resources(created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS saved_resources_type_idx ON saved_resources(type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS saved_resources_article_id_idx ON saved_resources(article_id)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS resource_tags (
        resource_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        PRIMARY KEY(resource_id, tag_id)
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS resource_tags_resource_id_idx ON resource_tags(resource_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS resource_tags_tag_id_idx ON resource_tags(tag_id)',
    );
  }

  Future<void> _migrateResourceProcessingFields(DatabaseExecutor db) async {
    await _addColumnIfMissing(
      db,
      'saved_resources',
      'original_source_path',
      'TEXT',
    );
    await _addColumnIfMissing(
      db,
      'saved_resources',
      'status',
      "TEXT NOT NULL DEFAULT 'ready'",
    );
    await _addColumnIfMissing(db, 'saved_resources', 'error', 'TEXT');
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
          content,
          remark
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
      INSERT INTO articles_fts(id, title, content, remark)
      SELECT id, COALESCE(title, ''), COALESCE(content, ''), COALESCE(remark, '') FROM articles
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

  Future<void> _migrateToPublishedAt(DatabaseExecutor db) async {
    // Add new columns
    await db.execute('ALTER TABLE articles ADD COLUMN published_at INTEGER');
    await db.execute('ALTER TABLE articles ADD COLUMN image_paths TEXT');

    // Copy created_at to published_at
    await db.execute('UPDATE articles SET published_at = created_at');

    // Create temporary table with new schema
    await db.execute('''
      CREATE TABLE articles_new (
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

    // Copy data to new table
    await db.execute('''
      INSERT INTO articles_new (
        id, title, content, html_path, cover_path, source_url, original_url,
        published_at, saved_at, media_type, is_starred, category_id, image_paths, remark
      )
      SELECT
        id, title, content, html_path, cover_path, source_url, source_url,
        published_at, created_at, media_type, 0, category_id, image_paths, ''
      FROM articles
    ''');

    // Drop old table and rename new table
    await db.execute('DROP TABLE articles');
    await db.execute('ALTER TABLE articles_new RENAME TO articles');

    // Recreate indexes
    await db.execute(
      'CREATE INDEX articles_published_at_idx ON articles(published_at)',
    );
    await db.execute('CREATE INDEX articles_title_idx ON articles(title)');
    await db.execute(
      'CREATE INDEX articles_category_id_idx ON articles(category_id)',
    );
  }

  Future<void> _migrateToSavedAtAndRemark(DatabaseExecutor db) async {
    await _addColumnIfMissing(db, 'articles', 'saved_at', 'INTEGER');
    await _addColumnIfMissing(
      db,
      'articles',
      'remark',
      "TEXT NOT NULL DEFAULT ''",
    );
    await db.execute(
      'UPDATE articles SET saved_at = COALESCE(saved_at, published_at)',
    );
    if (await _hasArticleFtsTableInExecutor(db)) {
      await db.execute('DROP TABLE articles_fts');
    }
    final ftsCreated = await _tryCreateArticleFtsSchema(db);
    if (ftsCreated) {
      await _rebuildArticleFts(db);
    }
  }

  Future<void> _migrateToOriginalUrl(DatabaseExecutor db) async {
    await _addColumnIfMissing(db, 'articles', 'original_url', 'TEXT');
    await db.execute(
      'UPDATE articles SET original_url = COALESCE(NULLIF(original_url, \'\'), source_url)',
    );
  }

  Future<void> _migrateToStarred(DatabaseExecutor db) async {
    await _addColumnIfMissing(
      db,
      'articles',
      'is_starred',
      'INTEGER NOT NULL DEFAULT 0',
    );
  }

  Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<bool> _hasArticleFtsTableInExecutor(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'articles_fts' LIMIT 1",
    );
    return rows.isNotEmpty;
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
        'remark': article.remark,
      });
    });
  }

  Future<List<SavedArticle>> listArticles() async {
    final db = await _db;
    final rows = await db.query('articles', orderBy: 'published_at DESC');
    return rows.map(SavedArticle.fromMap).toList(growable: false);
  }

  Future<List<SavedResource>> listResources() async {
    final db = await _db;
    final rows = await db.query('saved_resources', orderBy: 'created_at DESC');
    return rows.map(SavedResource.fromMap).toList(growable: false);
  }

  Future<SavedArticle?> getArticle(String id) async {
    final db = await _db;
    final rows = await db.query(
      'articles',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return SavedArticle.fromMap(rows.single);
  }

  Future<List<SavedArticle>> listArticlesPage({
    int limit = 20,
    int offset = 0,
    ArticleSort sort = ArticleSort.publishedNewest,
    Set<ArticleMediaType> mediaTypes = const {},
    Set<String> tagIds = const {},
  }) async {
    final db = await _db;
    final filter = _articleFilter(mediaTypes: mediaTypes, tagIds: tagIds);
    final rows = await db.query(
      'articles',
      where: filter.where,
      whereArgs: filter.args,
      orderBy: sort.orderBy,
      limit: limit,
      offset: offset,
    );
    return rows.map(SavedArticle.fromMap).toList(growable: false);
  }

  Future<List<SavedArticle>> listArticlesByCategory(String categoryId) async {
    final db = await _db;
    final rows = await db.query(
      'articles',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'published_at DESC',
    );
    return rows.map(SavedArticle.fromMap).toList(growable: false);
  }

  Future<List<SavedArticle>> listArticlesByCategoryPage(
    String categoryId, {
    int limit = 20,
    int offset = 0,
    ArticleSort sort = ArticleSort.publishedNewest,
    Set<ArticleMediaType> mediaTypes = const {},
    Set<String> tagIds = const {},
  }) async {
    final db = await _db;
    final filter = _articleFilter(
      clauses: ['category_id = ?'],
      args: [categoryId],
      mediaTypes: mediaTypes,
      tagIds: tagIds,
    );
    final rows = await db.query(
      'articles',
      where: filter.where,
      whereArgs: filter.args,
      orderBy: sort.orderBy,
      limit: limit,
      offset: offset,
    );
    return rows.map(SavedArticle.fromMap).toList(growable: false);
  }

  Future<List<SavedArticle>> listUncategorizedArticlesPage({
    int limit = 20,
    int offset = 0,
    ArticleSort sort = ArticleSort.publishedNewest,
    Set<ArticleMediaType> mediaTypes = const {},
    Set<String> tagIds = const {},
  }) async {
    final db = await _db;
    final filter = _articleFilter(
      clauses: ['category_id IS NULL'],
      mediaTypes: mediaTypes,
      tagIds: tagIds,
    );
    final rows = await db.query(
      'articles',
      where: filter.where,
      whereArgs: filter.args,
      orderBy: sort.orderBy,
      limit: limit,
      offset: offset,
    );
    return rows.map(SavedArticle.fromMap).toList(growable: false);
  }

  Future<List<SavedArticle>> listStarredArticlesPage({
    int limit = 20,
    int offset = 0,
    ArticleSort sort = ArticleSort.publishedNewest,
    Set<ArticleMediaType> mediaTypes = const {},
    Set<String> tagIds = const {},
  }) async {
    final db = await _db;
    final filter = _articleFilter(
      clauses: ['is_starred = 1'],
      mediaTypes: mediaTypes,
      tagIds: tagIds,
    );
    final rows = await db.query(
      'articles',
      where: filter.where,
      whereArgs: filter.args,
      orderBy: sort.orderBy,
      limit: limit,
      offset: offset,
    );
    return rows.map(SavedArticle.fromMap).toList(growable: false);
  }

  Future<List<SavedArticle>> searchArticles(String query) async {
    return searchArticlesPage(query, limit: 100000);
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
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      final hasCompoundFilters =
          mediaTypes.isNotEmpty ||
          tagIds.isNotEmpty ||
          (starredOnly && (categoryId != null || uncategorizedOnly));
      if (hasCompoundFilters) {
        final db = await _db;
        return _searchArticlesLike(
          db,
          normalized,
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
      if (starredOnly) {
        return listStarredArticlesPage(
          limit: limit,
          offset: offset,
          sort: sort,
          mediaTypes: mediaTypes,
          tagIds: tagIds,
        );
      }
      if (categoryId != null) {
        return listArticlesByCategoryPage(
          categoryId,
          limit: limit,
          offset: offset,
          sort: sort,
          mediaTypes: mediaTypes,
          tagIds: tagIds,
        );
      }
      if (uncategorizedOnly) {
        return listUncategorizedArticlesPage(
          limit: limit,
          offset: offset,
          sort: sort,
          mediaTypes: mediaTypes,
          tagIds: tagIds,
        );
      }
      return listArticlesPage(
        limit: limit,
        offset: offset,
        sort: sort,
        mediaTypes: mediaTypes,
        tagIds: tagIds,
      );
    }

    final db = await _db;
    if (!_articleFtsAvailable ||
        categoryId != null ||
        uncategorizedOnly ||
        starredOnly ||
        mediaTypes.isNotEmpty ||
        tagIds.isNotEmpty ||
        sort != ArticleSort.publishedNewest) {
      return _searchArticlesLike(
        db,
        normalized,
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

    final List<Map<String, Object?>> rows;
    try {
      rows = await db.rawQuery(
        '''
        SELECT articles.*
        FROM articles
        JOIN articles_fts ON articles_fts.id = articles.id
        WHERE articles_fts MATCH ?
        ORDER BY articles.published_at DESC
        LIMIT ? OFFSET ?
        ''',
        [_ftsQuery(normalized), limit, offset],
      );
    } on DatabaseException {
      return _searchArticlesLike(db, normalized, limit: limit, offset: offset);
    }
    if (rows.isEmpty || normalized.runes.length < 3) {
      return _searchArticlesLike(db, normalized, limit: limit, offset: offset);
    }
    return rows.map(SavedArticle.fromMap).toList(growable: false);
  }

  Future<List<SavedArticle>> _searchArticlesLike(
    Database db,
    String query, {
    int limit = 20,
    int offset = 0,
    String? categoryId,
    bool uncategorizedOnly = false,
    bool starredOnly = false,
    ArticleSort sort = ArticleSort.publishedNewest,
    Set<ArticleMediaType> mediaTypes = const {},
    Set<String> tagIds = const {},
  }) async {
    final clauses = ['(title LIKE ? OR content LIKE ? OR remark LIKE ?)'];
    final args = <Object?>['%$query%', '%$query%', '%$query%'];
    if (categoryId != null) {
      clauses.add('category_id = ?');
      args.add(categoryId);
    } else if (uncategorizedOnly) {
      clauses.add('category_id IS NULL');
    }
    if (starredOnly) {
      clauses.add('is_starred = 1');
    }
    final filter = _articleFilter(
      clauses: clauses,
      args: args,
      mediaTypes: mediaTypes,
      tagIds: tagIds,
    );
    final rows = await db.query(
      'articles',
      where: filter.where,
      whereArgs: filter.args,
      orderBy: sort.orderBy,
      limit: limit,
      offset: offset,
    );
    return rows.map(SavedArticle.fromMap).toList(growable: false);
  }

  _ArticleFilter _articleFilter({
    List<String> clauses = const [],
    List<Object?> args = const [],
    Set<ArticleMediaType> mediaTypes = const {},
    Set<String> tagIds = const {},
  }) {
    final nextClauses = [...clauses];
    final nextArgs = <Object?>[...args];
    if (mediaTypes.isNotEmpty &&
        mediaTypes.length < ArticleMediaType.values.length) {
      nextClauses.add(
        'media_type IN (${List.filled(mediaTypes.length, '?').join(', ')})',
      );
      nextArgs.addAll(mediaTypes.map((type) => type.value));
    }
    for (final tagId in tagIds) {
      nextClauses.add(
        'id IN (SELECT article_id FROM article_tags WHERE tag_id = ?)',
      );
      nextArgs.add(tagId);
    }
    return _ArticleFilter(
      where: nextClauses.isEmpty ? null : nextClauses.join(' AND '),
      args: nextArgs.isEmpty ? null : nextArgs,
    );
  }

  String _ftsQuery(String query) {
    return query.replaceAll('"', ' ').trim();
  }

  Future<void> deleteArticle(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      final resources = await txn.query(
        'saved_resources',
        columns: ['id'],
        where: 'article_id = ?',
        whereArgs: [id],
      );
      for (final resource in resources) {
        await txn.delete(
          'resource_tags',
          where: 'resource_id = ?',
          whereArgs: [resource['id']],
        );
      }
      await txn.delete(
        'saved_resources',
        where: 'article_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'article_tags',
        where: 'article_id = ?',
        whereArgs: [id],
      );
      await txn.delete('articles', where: 'id = ?', whereArgs: [id]);
      if (!_articleFtsAvailable) {
        return;
      }
      await txn.delete('articles_fts', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteArticles(Iterable<String> ids) async {
    final uniqueIds = ids.toSet();
    if (uniqueIds.isEmpty) {
      return;
    }
    final db = await _db;
    await db.transaction((txn) async {
      for (final id in uniqueIds) {
        final resources = await txn.query(
          'saved_resources',
          columns: ['id'],
          where: 'article_id = ?',
          whereArgs: [id],
        );
        for (final resource in resources) {
          await txn.delete(
            'resource_tags',
            where: 'resource_id = ?',
            whereArgs: [resource['id']],
          );
        }
        await txn.delete(
          'saved_resources',
          where: 'article_id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'article_tags',
          where: 'article_id = ?',
          whereArgs: [id],
        );
        await txn.delete('articles', where: 'id = ?', whereArgs: [id]);
        if (_articleFtsAvailable) {
          await txn.delete('articles_fts', where: 'id = ?', whereArgs: [id]);
        }
      }
    });
  }

  Future<void> updateArticleStarred(String articleId, bool isStarred) async {
    final db = await _db;
    await db.update(
      'articles',
      {'is_starred': isStarred ? 1 : 0},
      where: 'id = ?',
      whereArgs: [articleId],
    );
  }

  Future<void> updateArticleRemark(String articleId, String remark) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'articles',
        {'remark': remark.trim()},
        where: 'id = ?',
        whereArgs: [articleId],
      );
      if (!_articleFtsAvailable) {
        return;
      }
      final rows = await txn.query(
        'articles',
        columns: ['id', 'title', 'content', 'remark'],
        where: 'id = ?',
        whereArgs: [articleId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return;
      }
      await txn.delete('articles_fts', where: 'id = ?', whereArgs: [articleId]);
      await txn.insert('articles_fts', {
        'id': rows.single['id'],
        'title': rows.single['title'] ?? '',
        'content': rows.single['content'] ?? '',
        'remark': rows.single['remark'] ?? '',
      });
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

  Future<void> upsertCategory(SavedCategory category) async {
    final db = await _db;
    await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  Future<List<SavedTag>> listTags() async {
    final db = await _db;
    final rows = await db.query('tags', orderBy: 'created_at DESC');
    return rows.map(SavedTag.fromMap).toList(growable: false);
  }

  Future<SavedTag> createTag(String name, int color) async {
    final tag = SavedTag(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim(),
      color: color,
      createdAt: DateTime.now(),
    );
    final db = await _db;
    await db.insert('tags', tag.toMap());
    return tag;
  }

  Future<void> upsertTag(SavedTag tag) async {
    final db = await _db;
    await db.insert(
      'tags',
      tag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> renameTag(String id, String name) async {
    final db = await _db;
    await db.update(
      'tags',
      {'name': name.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTag(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('article_tags', where: 'tag_id = ?', whereArgs: [id]);
      await txn.delete('resource_tags', where: 'tag_id = ?', whereArgs: [id]);
      await txn.delete('tags', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<SavedTag>> listArticleTags(String articleId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT tags.*
      FROM tags
      JOIN article_tags ON article_tags.tag_id = tags.id
      WHERE article_tags.article_id = ?
      ORDER BY tags.created_at DESC
      ''',
      [articleId],
    );
    return rows.map(SavedTag.fromMap).toList(growable: false);
  }

  Future<Map<String, List<SavedTag>>> listTagsByArticleIds(
    Iterable<String> articleIds,
  ) async {
    final uniqueIds = articleIds.toSet();
    if (uniqueIds.isEmpty) {
      return const {};
    }
    final db = await _db;
    final placeholders = List.filled(uniqueIds.length, '?').join(', ');
    final rows = await db.rawQuery('''
      SELECT article_tags.article_id, tags.*
      FROM article_tags
      JOIN tags ON tags.id = article_tags.tag_id
      WHERE article_tags.article_id IN ($placeholders)
      ORDER BY tags.created_at DESC
      ''', uniqueIds.toList(growable: false));
    final result = <String, List<SavedTag>>{};
    for (final row in rows) {
      final articleId = row['article_id'] as String;
      final tag = SavedTag.fromMap(row);
      result.putIfAbsent(articleId, () => <SavedTag>[]).add(tag);
    }
    return result;
  }

  Future<List<Map<String, Object?>>> listArticleTagAssignments() async {
    final db = await _db;
    return db.query('article_tags', orderBy: 'created_at ASC');
  }

  Future<List<Map<String, Object?>>> listResourceTagAssignments() async {
    final db = await _db;
    return db.query('resource_tags', orderBy: 'created_at ASC');
  }

  Future<List<VideoMarker>> listAllVideoMarkers() async {
    final db = await _db;
    final rows = await db.query(
      'video_markers',
      orderBy: 'article_id ASC, position_ms ASC, created_at ASC',
    );
    return rows.map(VideoMarker.fromMap).toList(growable: false);
  }

  Future<void> setArticleTags(String articleId, Set<String> tagIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'article_tags',
        where: 'article_id = ?',
        whereArgs: [articleId],
      );
      await _insertArticleTags(txn, [articleId], tagIds);
    });
  }

  Future<void> addTagsToArticles(
    Iterable<String> articleIds,
    Set<String> tagIds,
  ) async {
    final ids = articleIds.toSet();
    if (ids.isEmpty || tagIds.isEmpty) {
      return;
    }
    final db = await _db;
    await db.transaction((txn) => _insertArticleTags(txn, ids, tagIds));
  }

  Future<void> removeTagsFromArticles(
    Iterable<String> articleIds,
    Set<String> tagIds,
  ) async {
    final ids = articleIds.toSet();
    if (ids.isEmpty || tagIds.isEmpty) {
      return;
    }
    final db = await _db;
    await db.transaction((txn) async {
      for (final articleId in ids) {
        for (final tagId in tagIds) {
          await txn.delete(
            'article_tags',
            where: 'article_id = ? AND tag_id = ?',
            whereArgs: [articleId, tagId],
          );
        }
      }
    });
  }

  Future<VideoMarker> createVideoMarker({
    required String articleId,
    required Duration position,
    required String note,
  }) async {
    final now = DateTime.now();
    final marker = VideoMarker(
      id: now.microsecondsSinceEpoch.toString(),
      articleId: articleId,
      position: position,
      note: note.trim(),
      createdAt: now,
      updatedAt: now,
    );
    await upsertVideoMarker(marker);
    return marker;
  }

  Future<void> upsertVideoMarker(VideoMarker marker) async {
    final db = await _db;
    await db.insert(
      'video_markers',
      marker.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<VideoMarker>> listVideoMarkers(String articleId) async {
    final db = await _db;
    final rows = await db.query(
      'video_markers',
      where: 'article_id = ?',
      whereArgs: [articleId],
      orderBy: 'position_ms ASC, created_at ASC',
    );
    return rows.map(VideoMarker.fromMap).toList(growable: false);
  }

  Future<void> updateVideoMarker(VideoMarker marker) async {
    final db = await _db;
    await db.update(
      'video_markers',
      marker.toMap(),
      where: 'id = ?',
      whereArgs: [marker.id],
    );
  }

  Future<void> deleteVideoMarker(String id) async {
    final db = await _db;
    await db.delete('video_markers', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteVideoMarkersForArticle(String articleId) async {
    final db = await _db;
    await db.delete(
      'video_markers',
      where: 'article_id = ?',
      whereArgs: [articleId],
    );
  }

  Future<SavedResource> createImageResource({
    required String articleId,
    required String imagePath,
    required String title,
    String note = '',
    Set<String> tagIds = const {},
  }) async {
    final now = DateTime.now();
    final resource = SavedResource(
      id: now.microsecondsSinceEpoch.toString(),
      type: SavedResourceType.image,
      articleId: articleId,
      sourcePath: imagePath,
      previewPath: imagePath,
      title: title.trim(),
      note: note.trim(),
      createdAt: now,
    );
    await upsertResource(resource, tagIds: tagIds);
    return resource;
  }

  Future<SavedResource> createVideoClipResource({
    String? id,
    required String articleId,
    required String videoPath,
    required String originalVideoPath,
    required String? previewPath,
    required String title,
    String note = '',
    required Duration start,
    required Duration end,
    SavedResourceStatus status = SavedResourceStatus.processing,
    String? error,
    Set<String> tagIds = const {},
  }) async {
    final now = DateTime.now();
    final resource = SavedResource(
      id: id ?? now.microsecondsSinceEpoch.toString(),
      type: SavedResourceType.videoClip,
      articleId: articleId,
      sourcePath: videoPath,
      previewPath: previewPath,
      originalSourcePath: originalVideoPath,
      title: title.trim(),
      note: note.trim(),
      status: status,
      error: error,
      start: start,
      end: end,
      createdAt: now,
    );
    await upsertResource(resource, tagIds: tagIds);
    return resource;
  }

  Future<void> upsertResource(
    SavedResource resource, {
    Set<String>? tagIds,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(
        'saved_resources',
        resource.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (tagIds != null) {
        await txn.delete(
          'resource_tags',
          where: 'resource_id = ?',
          whereArgs: [resource.id],
        );
        await _insertResourceTags(txn, [resource.id], tagIds);
      }
    });
  }

  Future<void> updateResourceProcessingState(
    String resourceId, {
    required SavedResourceStatus status,
    String? error,
  }) async {
    final db = await _db;
    await db.update(
      'saved_resources',
      {'status': status.value, 'error': error},
      where: 'id = ?',
      whereArgs: [resourceId],
    );
  }

  Future<List<SavedResource>> searchResourcesPage(
    String query, {
    int limit = 20,
    int offset = 0,
    Set<SavedResourceType> types = const {},
    Set<String> tagIds = const {},
  }) async {
    final db = await _db;
    final clauses = <String>[];
    final args = <Object?>[];
    final normalized = query.trim();
    if (normalized.isNotEmpty) {
      clauses.add('(title LIKE ? OR note LIKE ?)');
      args.addAll(['%$normalized%', '%$normalized%']);
    }
    if (types.isNotEmpty && types.length < SavedResourceType.values.length) {
      clauses.add('type IN (${List.filled(types.length, '?').join(', ')})');
      args.addAll(types.map((type) => type.value));
    }
    for (final tagId in tagIds) {
      clauses.add(
        'id IN (SELECT resource_id FROM resource_tags WHERE tag_id = ?)',
      );
      args.add(tagId);
    }
    final rows = await db.query(
      'saved_resources',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(SavedResource.fromMap).toList(growable: false);
  }

  Future<List<SavedTag>> listResourceTags(String resourceId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT tags.*
      FROM tags
      JOIN resource_tags ON resource_tags.tag_id = tags.id
      WHERE resource_tags.resource_id = ?
      ORDER BY tags.created_at DESC
      ''',
      [resourceId],
    );
    return rows.map(SavedTag.fromMap).toList(growable: false);
  }

  Future<Map<String, List<SavedTag>>> listTagsByResourceIds(
    Iterable<String> resourceIds,
  ) async {
    final uniqueIds = resourceIds.toSet();
    if (uniqueIds.isEmpty) {
      return const {};
    }
    final db = await _db;
    final placeholders = List.filled(uniqueIds.length, '?').join(', ');
    final rows = await db.rawQuery('''
      SELECT resource_tags.resource_id, tags.*
      FROM resource_tags
      JOIN tags ON tags.id = resource_tags.tag_id
      WHERE resource_tags.resource_id IN ($placeholders)
      ORDER BY tags.created_at DESC
      ''', uniqueIds.toList(growable: false));
    final result = <String, List<SavedTag>>{};
    for (final row in rows) {
      final resourceId = row['resource_id'] as String;
      final tag = SavedTag.fromMap(row);
      result.putIfAbsent(resourceId, () => <SavedTag>[]).add(tag);
    }
    return result;
  }

  Future<void> setResourceTags(String resourceId, Set<String> tagIds) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'resource_tags',
        where: 'resource_id = ?',
        whereArgs: [resourceId],
      );
      await _insertResourceTags(txn, [resourceId], tagIds);
    });
  }

  Future<void> deleteResource(String id) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'resource_tags',
        where: 'resource_id = ?',
        whereArgs: [id],
      );
      await txn.delete('saved_resources', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> upsertArticleTagAssignment(
    String articleId,
    String tagId, {
    int? createdAt,
  }) async {
    final db = await _db;
    await db.insert('article_tags', {
      'article_id': articleId,
      'tag_id': tagId,
      'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> upsertResourceTagAssignment(
    String resourceId,
    String tagId, {
    int? createdAt,
  }) async {
    final db = await _db;
    await db.insert('resource_tags', {
      'resource_id': resourceId,
      'tag_id': tagId,
      'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> replaceBackupData({
    required Iterable<SavedCategory> categories,
    required Iterable<SavedTag> tags,
    required Iterable<SavedArticle> articles,
    required Iterable<VideoMarker> videoMarkers,
    required Iterable<SavedResource> resources,
    required Iterable<Map<String, Object?>> articleTags,
    required Iterable<Map<String, Object?>> resourceTags,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      if (_articleFtsAvailable) {
        await txn.delete('articles_fts');
      }
      await txn.delete('resource_tags');
      await txn.delete('article_tags');
      await txn.delete('video_markers');
      await txn.delete('saved_resources');
      await txn.delete('articles');
      await txn.delete('categories');
      await txn.delete('tags');

      for (final category in categories) {
        await txn.insert(
          'categories',
          category.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final tag in tags) {
        await txn.insert(
          'tags',
          tag.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final article in articles) {
        await txn.insert(
          'articles',
          article.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        if (_articleFtsAvailable) {
          await txn.insert('articles_fts', {
            'id': article.id,
            'title': article.title,
            'content': article.content,
            'remark': article.remark,
          });
        }
      }
      for (final resource in resources) {
        await txn.insert(
          'saved_resources',
          resource.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final marker in videoMarkers) {
        await txn.insert(
          'video_markers',
          marker.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final assignment in articleTags) {
        final articleId = assignment['article_id'] as String?;
        final tagId = assignment['tag_id'] as String?;
        if (articleId == null || tagId == null) {
          continue;
        }
        await txn.insert('article_tags', {
          'article_id': articleId,
          'tag_id': tagId,
          'created_at':
              assignment['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      for (final assignment in resourceTags) {
        final resourceId = assignment['resource_id'] as String?;
        final tagId = assignment['tag_id'] as String?;
        if (resourceId == null || tagId == null) {
          continue;
        }
        await txn.insert('resource_tags', {
          'resource_id': resourceId,
          'tag_id': tagId,
          'created_at':
              assignment['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> _insertArticleTags(
    DatabaseExecutor db,
    Iterable<String> articleIds,
    Set<String> tagIds,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final articleId in articleIds) {
      for (final tagId in tagIds) {
        await db.insert('article_tags', {
          'article_id': articleId,
          'tag_id': tagId,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  Future<void> _insertResourceTags(
    DatabaseExecutor db,
    Iterable<String> resourceIds,
    Set<String> tagIds,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final resourceId in resourceIds) {
      for (final tagId in tagIds) {
        await db.insert('resource_tags', {
          'resource_id': resourceId,
          'tag_id': tagId,
          'created_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }
}
