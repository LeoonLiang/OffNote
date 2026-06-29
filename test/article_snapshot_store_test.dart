import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/article_database.dart';
import 'package:offnote/article_snapshot_store.dart';
import 'package:offnote/saved_resource.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory root;
  late Directory docs;
  late ArticleSnapshotStore store;

  setUp(() {
    root = Directory.systemTemp.createTempSync('offnote_store_test_');
    docs = Directory(p.join(root.path, 'docs'))..createSync();
    final support = Directory(p.join(root.path, 'support'))..createSync();
    store = ArticleSnapshotStore(
      database: ArticleDatabase(
        databaseFactory: databaseFactoryFfi,
        databasePath: p.join(support.path, 'offnote.db'),
      ),
      documentsDirectory: docs,
    );
  });

  tearDown(() {
    if (root.existsSync()) {
      root.deleteSync(recursive: true);
    }
  });

  test('imports image resources into a managed resource directory', () async {
    final source = File(p.join(root.path, 'picked', 'photo one.jpg'))
      ..createSync(recursive: true)
      ..writeAsStringSync('image-bytes');

    final resource = await store.importImageResource(source.path);

    expect(resource.type, SavedResourceType.image);
    expect(resource.articleId, '');
    expect(resource.title, 'photo one');
    expect(resource.previewPath, resource.sourcePath);
    expect(resource.sourcePath, isNot(source.path));
    expect(File(resource.sourcePath).readAsStringSync(), 'image-bytes');
    expect(p.basename(p.dirname(resource.sourcePath)), resource.id);
    expect(p.basename(p.dirname(p.dirname(resource.sourcePath))), 'resources');
  });

  test(
    'imports video resources as ready source-less video materials',
    () async {
      final source = File(p.join(root.path, 'picked', 'clip.mp4'))
        ..createSync(recursive: true)
        ..writeAsStringSync('video-bytes');

      final resource = await store.importVideoResource(source.path);

      expect(resource.type, SavedResourceType.videoClip);
      expect(resource.articleId, '');
      expect(resource.status, SavedResourceStatus.ready);
      expect(resource.start, isNull);
      expect(resource.end, isNull);
      expect(resource.previewPath, isNull);
      expect(File(resource.sourcePath).readAsStringSync(), 'video-bytes');
    },
  );

  test(
    'deleting imported resources removes their managed directory only',
    () async {
      final uploaded = File(p.join(root.path, 'picked', 'upload.png'))
        ..createSync(recursive: true)
        ..writeAsStringSync('upload');
      final uploadedResource = await store.importImageResource(uploaded.path);
      final uploadedDir = Directory(p.dirname(uploadedResource.sourcePath));

      final articleImage =
          File(p.join(docs.path, 'articles', 'a1', 'images', 'image_0.jpg'))
            ..createSync(recursive: true)
            ..writeAsStringSync('article');
      final articleResource = await store.createImageResource(
        articleId: 'a1',
        imagePath: articleImage.path,
        title: 'Article image',
      );

      await store.deleteResource(uploadedResource);
      await store.deleteResource(articleResource);

      expect(uploadedDir.existsSync(), isFalse);
      expect(articleImage.existsSync(), isTrue);
    },
  );
}
