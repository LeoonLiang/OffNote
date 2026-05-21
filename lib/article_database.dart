import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'saved_article.dart';

class ArticleDatabase {
  Database? _database;

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final supportDir = await getApplicationSupportDirectory();
    final database = await openDatabase(
      p.join(supportDir.path, 'offnote.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE articles (
            id TEXT PRIMARY KEY,
            title TEXT,
            content TEXT,
            html_path TEXT,
            cover_path TEXT,
            source_url TEXT,
            created_at INTEGER
          )
        ''');
        await db.execute(
          'CREATE INDEX articles_created_at_idx ON articles(created_at)',
        );
        await db.execute('CREATE INDEX articles_title_idx ON articles(title)');
      },
    );
    _database = database;
    return database;
  }

  Future<void> upsertArticle(SavedArticle article) async {
    final db = await _db;
    await db.insert(
      'articles',
      article.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SavedArticle>> listArticles() async {
    final db = await _db;
    final rows = await db.query('articles', orderBy: 'created_at DESC');
    return rows.map(SavedArticle.fromMap).toList(growable: false);
  }

  Future<List<SavedArticle>> searchArticles(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return listArticles();
    }

    final db = await _db;
    final rows = await db.query(
      'articles',
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$normalized%', '%$normalized%'],
      orderBy: 'created_at DESC',
    );
    return rows.map(SavedArticle.fromMap).toList(growable: false);
  }

  Future<void> deleteArticle(String id) async {
    final db = await _db;
    await db.delete('articles', where: 'id = ?', whereArgs: [id]);
  }
}
