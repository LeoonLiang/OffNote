import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/article_database.dart';
import 'package:offnote/offnote_backup_service.dart';
import 'package:offnote/saved_article.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'exports all saved data and imports it into a different app root',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'offnote_backup_test_',
      );
      addTearDown(() {
        if (root.existsSync()) {
          root.deleteSync(recursive: true);
        }
      });

      final sourceDocs = Directory('${root.path}/source_docs')..createSync();
      final sourceSupport = Directory('${root.path}/source_support')
        ..createSync();
      final targetDocs = Directory('${root.path}/target_docs')..createSync();
      final targetSupport = Directory('${root.path}/target_support')
        ..createSync();

      final sourceDb = ArticleDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: '${sourceSupport.path}/offnote.db',
      );
      final category = await sourceDb.createCategory('旅行', 0xff51b96b);
      final tag = await sourceDb.createTag('攻略', 0xffd83f5f);
      final articleDir = Directory('${sourceDocs.path}/articles/a1/images')
        ..createSync(recursive: true);
      final htmlFile = File('${sourceDocs.path}/articles/a1/index.html')
        ..writeAsStringSync('<html>offline</html>');
      final coverFile = File('${articleDir.path}/cover.jpg')
        ..writeAsStringSync('cover');
      final imageFile = File('${articleDir.path}/image_0.jpg')
        ..writeAsStringSync('image');
      await sourceDb.upsertArticle(
        SavedArticle(
          id: 'a1',
          title: '离线攻略',
          content: '正文',
          htmlPath: htmlFile.path,
          coverPath: coverFile.path,
          sourceUrl: 'https://www.xiaohongshu.com/discovery/item/a1',
          originalUrl: 'https://xhslink.com/a1',
          publishedAt: DateTime(2026, 5, 1),
          savedAt: DateTime(2026, 5, 2),
          imagePaths: [imageFile.path],
          categoryId: category.id,
        ),
      );
      await sourceDb.setArticleTags('a1', {tag.id});

      final backupFile = File('${root.path}/offnote.offnote-backup');
      await OffNoteBackupService(
        database: sourceDb,
        documentsDirectory: sourceDocs,
      ).exportToFile(backupFile);

      final targetDb = ArticleDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: '${targetSupport.path}/offnote.db',
      );
      await OffNoteBackupService(
        database: targetDb,
        documentsDirectory: targetDocs,
      ).importFromFile(backupFile);

      final importedArticles = await targetDb.listArticles();
      final importedCategories = await targetDb.listCategories();
      final importedTags = await targetDb.listTags();
      final importedArticleTags = await targetDb.listArticleTags('a1');

      expect(importedCategories.single.name, '旅行');
      expect(importedTags.single.name, '攻略');
      expect(importedArticleTags.single.id, tag.id);
      expect(importedArticles.single.title, '离线攻略');
      expect(importedArticles.single.categoryId, category.id);
      expect(
        importedArticles.single.htmlPath,
        '${targetDocs.path}/articles/a1/index.html',
      );
      expect(
        File(importedArticles.single.htmlPath).readAsStringSync(),
        '<html>offline</html>',
      );
      expect(
        importedArticles.single.coverPath,
        '${targetDocs.path}/articles/a1/images/cover.jpg',
      );
      expect(importedArticles.single.imagePaths, [
        '${targetDocs.path}/articles/a1/images/image_0.jpg',
      ]);
    },
  );

  test('creates, lists, and deletes managed backup entries', () async {
    final root = await Directory.systemTemp.createTemp('offnote_backup_list_');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    final docs = Directory('${root.path}/docs')..createSync();
    final support = Directory('${root.path}/support')..createSync();
    final db = ArticleDatabase(
      databaseFactory: databaseFactoryFfi,
      databasePath: '${support.path}/offnote.db',
    );
    await db.createCategory('旅行', 0xff51b96b);
    await db.upsertArticle(
      SavedArticle(
        id: 'a1',
        title: '离线攻略',
        content: '正文',
        htmlPath: '${docs.path}/articles/a1/index.html',
        coverPath: null,
        sourceUrl: 'https://www.xiaohongshu.com/discovery/item/a1',
        originalUrl: 'https://xhslink.com/a1',
        publishedAt: DateTime(2026, 5, 1),
        savedAt: DateTime(2026, 5, 2),
      ),
    );

    final service = OffNoteBackupService(
      database: db,
      documentsDirectory: docs,
    );
    final backup = await service.createManagedBackup();
    final entries = await service.listBackups();

    expect(backup.path, contains('/backups/offnote-backup-'));
    expect(entries.single.file.path, backup.path);
    expect(entries.single.articleCount, 1);
    expect(entries.single.categoryCount, 1);
    expect(entries.single.tagCount, 0);
    expect(entries.single.sizeBytes, greaterThan(0));

    await service.deleteBackup(backup);

    expect(await service.listBackups(), isEmpty);
    expect(backup.existsSync(), isFalse);
  });
}
