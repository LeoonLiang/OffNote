import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import 'article_database.dart';
import 'saved_article.dart';
import 'saved_category.dart';
import 'saved_resource.dart';
import 'saved_tag.dart';
import 'video_marker.dart';

class OffNoteBackupImportResult {
  const OffNoteBackupImportResult({
    required this.articleCount,
    required this.categoryCount,
    required this.tagCount,
    required this.resourceCount,
  });

  final int articleCount;
  final int categoryCount;
  final int tagCount;
  final int resourceCount;
}

class OffNoteBackupEntry {
  const OffNoteBackupEntry({
    required this.file,
    required this.createdAt,
    required this.articleCount,
    required this.categoryCount,
    required this.tagCount,
    required this.resourceCount,
    required this.sizeBytes,
  });

  final File file;
  final DateTime createdAt;
  final int articleCount;
  final int categoryCount;
  final int tagCount;
  final int resourceCount;
  final int sizeBytes;
}

class OffNoteBackupService {
  OffNoteBackupService({
    required ArticleDatabase database,
    required Directory documentsDirectory,
  }) : _database = database,
       _documentsDirectory = documentsDirectory;

  final ArticleDatabase _database;
  final Directory _documentsDirectory;

  Directory get _backupsDirectory =>
      Directory(p.join(_documentsDirectory.path, 'backups'));

  Future<File> exportToFile(File outputFile) async {
    final articles = await _database.listArticles();
    final categories = await _database.listCategories();
    final tags = await _database.listTags();
    final resources = await _database.listResources();
    final videoMarkers = await _database.listAllVideoMarkers();
    final articleTags = await _database.listArticleTagAssignments();
    final resourceTags = await _database.listResourceTagAssignments();
    final archive = Archive();

    final manifest = {
      'format': 'offnote-backup',
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'articles': articles.map(_articleToBackupMap).toList(growable: false),
      'resources': resources.map(_resourceToBackupMap).toList(growable: false),
      'categories': categories
          .map((category) => category.toMap())
          .toList(growable: false),
      'tags': tags.map((tag) => tag.toMap()).toList(growable: false),
      'video_markers': videoMarkers
          .map((marker) => marker.toMap())
          .toList(growable: false),
      'article_tags': articleTags,
      'resource_tags': resourceTags,
    };
    archive.addFile(
      ArchiveFile.string('offnote-backup.json', jsonEncode(manifest)),
    );

    _addDocumentDirectoryToArchive(archive, 'articles');
    _addDocumentDirectoryToArchive(archive, 'resources');

    outputFile.parent.createSync(recursive: true);
    outputFile.writeAsBytesSync(ZipEncoder().encodeBytes(archive));
    return outputFile;
  }

  Future<OffNoteBackupImportResult> importFromFile(File backupFile) async {
    final archive = ZipDecoder().decodeBytes(backupFile.readAsBytesSync());
    final manifestFile = archive.findFile('offnote-backup.json');
    if (manifestFile == null) {
      throw const FormatException('不是有效的 OffNote 备份文件');
    }
    final manifest = jsonDecode(utf8.decode(manifestFile.readBytes()!));
    if (manifest is! Map<String, Object?> ||
        manifest['format'] != 'offnote-backup' ||
        (manifest['version'] != 1 && manifest['version'] != 2)) {
      throw const FormatException('不支持的 OffNote 备份格式');
    }

    _replaceManagedDirectory('articles');
    _replaceManagedDirectory('resources');
    for (final entry in archive) {
      if (entry.isFile &&
          (entry.name.startsWith('articles/') ||
              entry.name.startsWith('resources/'))) {
        final target = _safeDocumentFile(entry.name);
        target.parent.createSync(recursive: true);
        target.writeAsBytesSync(entry.readBytes()!);
      }
    }

    final categories = _listOfMaps(
      manifest['categories'],
    ).map(SavedCategory.fromMap).toList(growable: false);
    final articles = _listOfMaps(
      manifest['articles'],
    ).map(_articleFromBackupMap).toList(growable: false);
    final tags = _listOfMaps(
      manifest['tags'],
    ).map(SavedTag.fromMap).toList(growable: false);
    final videoMarkers = _listOfMaps(
      manifest['video_markers'],
    ).map(VideoMarker.fromMap).toList(growable: false);
    final resources = _listOfMaps(
      manifest['resources'],
    ).map(_resourceFromBackupMap).toList(growable: false);
    final articleTags = _listOfMaps(manifest['article_tags']);
    final resourceTags = _listOfMaps(manifest['resource_tags']);

    await _database.replaceBackupData(
      categories: categories,
      tags: tags,
      articles: articles,
      videoMarkers: videoMarkers,
      resources: resources,
      articleTags: articleTags,
      resourceTags: resourceTags,
    );

    return OffNoteBackupImportResult(
      articleCount: articles.length,
      categoryCount: categories.length,
      tagCount: tags.length,
      resourceCount: resources.length,
    );
  }

  Future<File> createManagedBackup() async {
    final now = DateTime.now();
    final file = File(
      p.join(
        _backupsDirectory.path,
        'offnote-backup-${_backupStamp(now)}.offnote-backup',
      ),
    );
    return exportToFile(file);
  }

  Future<File> importManagedBackupFile(File sourceFile) async {
    final entry = _readBackupEntry(sourceFile);
    if (entry == null) {
      throw const FormatException('不是有效的 OffNote 备份文件');
    }
    _backupsDirectory.createSync(recursive: true);
    final created = entry.createdAt;
    var target = File(
      p.join(
        _backupsDirectory.path,
        'offnote-backup-${_backupStamp(created)}.offnote-backup',
      ),
    );
    if (p.equals(p.normalize(sourceFile.path), p.normalize(target.path))) {
      return sourceFile;
    }
    var suffix = 1;
    while (target.existsSync()) {
      target = File(
        p.join(
          _backupsDirectory.path,
          'offnote-backup-${_backupStamp(created)}-$suffix.offnote-backup',
        ),
      );
      suffix++;
    }
    return sourceFile.copy(target.path);
  }

  Future<List<OffNoteBackupEntry>> listBackups() async {
    if (!_backupsDirectory.existsSync()) {
      return const [];
    }
    final entries = <OffNoteBackupEntry>[];
    for (final entity in _backupsDirectory.listSync()) {
      if (entity is! File || !entity.path.endsWith('.offnote-backup')) {
        continue;
      }
      final entry = _readBackupEntry(entity);
      if (entry != null) {
        entries.add(entry);
      }
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<void> deleteBackup(File backupFile) async {
    final normalizedRoot = p.normalize(_backupsDirectory.path);
    final normalizedFile = p.normalize(backupFile.path);
    if (!p.isWithin(normalizedRoot, normalizedFile)) {
      throw const FormatException('只能删除 OffNote 管理的备份');
    }
    if (backupFile.existsSync()) {
      backupFile.deleteSync();
    }
  }

  Map<String, Object?> _articleToBackupMap(SavedArticle article) {
    final map = article.toMap();
    map['html_path'] = _relativeDocumentPath(article.htmlPath);
    map['cover_path'] = _relativeDocumentPath(article.coverPath);
    map['image_paths'] = jsonEncode(
      article.imagePaths
          .map(_relativeDocumentPath)
          .whereType<String>()
          .toList(),
    );
    return map;
  }

  Map<String, Object?> _resourceToBackupMap(SavedResource resource) {
    final map = resource.toMap();
    map['source_path'] = _relativeDocumentPath(resource.sourcePath);
    map['preview_path'] = _relativeDocumentPath(resource.previewPath);
    map['original_source_path'] = _relativeDocumentPath(
      resource.originalSourcePath,
    );
    return map;
  }

  SavedArticle _articleFromBackupMap(Map<String, Object?> map) {
    final restored = Map<String, Object?>.from(map);
    restored['html_path'] = _absoluteDocumentPath(restored['html_path']);
    restored['cover_path'] = _absoluteDocumentPath(restored['cover_path']);
    final imagePaths = SavedArticle.fromMap(map).imagePaths;
    restored['image_paths'] = jsonEncode(
      imagePaths.map(_absoluteDocumentPath).whereType<String>().toList(),
    );
    return SavedArticle.fromMap(restored);
  }

  SavedResource _resourceFromBackupMap(Map<String, Object?> map) {
    final restored = Map<String, Object?>.from(map);
    restored['source_path'] = _absoluteDocumentPath(restored['source_path']);
    restored['preview_path'] = _absoluteDocumentPath(restored['preview_path']);
    restored['original_source_path'] = _absoluteDocumentPath(
      restored['original_source_path'],
    );
    return SavedResource.fromMap(restored);
  }

  void _addDocumentDirectoryToArchive(Archive archive, String directoryName) {
    final directory = Directory(
      p.join(_documentsDirectory.path, directoryName),
    );
    if (!directory.existsSync()) {
      return;
    }
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File) {
        continue;
      }
      final relativePath = p.relative(
        entity.path,
        from: _documentsDirectory.path,
      );
      archive.addFile(
        ArchiveFile.bytes(_archivePath(relativePath), entity.readAsBytesSync()),
      );
    }
  }

  void _replaceManagedDirectory(String directoryName) {
    final directory = Directory(
      p.join(_documentsDirectory.path, directoryName),
    );
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }

  String? _relativeDocumentPath(String? path) {
    if (path == null || path.trim().isEmpty) {
      return null;
    }
    final normalizedPath = p.normalize(path);
    final normalizedRoot = p.normalize(_documentsDirectory.path);
    if (normalizedPath == normalizedRoot ||
        p.isWithin(normalizedRoot, normalizedPath)) {
      return p.relative(normalizedPath, from: normalizedRoot);
    }
    return path;
  }

  String? _absoluteDocumentPath(Object? path) {
    if (path is! String || path.trim().isEmpty) {
      return null;
    }
    if (p.isAbsolute(path)) {
      return path;
    }
    return p.join(_documentsDirectory.path, path);
  }

  File _safeDocumentFile(String archivePath) {
    final segments = p.posix.split(archivePath);
    if (segments.any((segment) => segment == '..' || segment.isEmpty)) {
      throw const FormatException('备份文件包含非法路径');
    }
    final target = File(p.joinAll([_documentsDirectory.path, ...segments]));
    final normalizedRoot = p.normalize(_documentsDirectory.path);
    final normalizedTarget = p.normalize(target.path);
    if (!p.isWithin(normalizedRoot, normalizedTarget)) {
      throw const FormatException('备份文件包含非法路径');
    }
    return target;
  }

  List<Map<String, Object?>> _listOfMaps(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((map) => Map<String, Object?>.from(map))
        .toList(growable: false);
  }

  String _archivePath(String path) => p.split(path).join('/');

  OffNoteBackupEntry? _readBackupEntry(File file) {
    try {
      final archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
      final manifestFile = archive.findFile('offnote-backup.json');
      if (manifestFile == null) {
        return null;
      }
      final manifest = jsonDecode(utf8.decode(manifestFile.readBytes()!));
      if (manifest is! Map<String, Object?> ||
          manifest['format'] != 'offnote-backup') {
        return null;
      }
      final createdAt =
          DateTime.tryParse(manifest['exported_at'] as String? ?? '') ??
          file.lastModifiedSync();
      return OffNoteBackupEntry(
        file: file,
        createdAt: createdAt,
        articleCount: _listOfMaps(manifest['articles']).length,
        categoryCount: _listOfMaps(manifest['categories']).length,
        tagCount: _listOfMaps(manifest['tags']).length,
        resourceCount: _listOfMaps(manifest['resources']).length,
        sizeBytes: file.lengthSync(),
      );
    } catch (_) {
      return null;
    }
  }

  String _backupStamp(DateTime dateTime) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dateTime.year}${two(dateTime.month)}${two(dateTime.day)}-'
        '${two(dateTime.hour)}${two(dateTime.minute)}${two(dateTime.second)}';
  }
}
