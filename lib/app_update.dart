import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const offNoteGithubRepoUrl = 'https://github.com/LeoonLiang/OffNote';
const offNoteGithubLatestReleaseApi =
    'https://api.github.com/repos/LeoonLiang/OffNote/releases/latest';
const offNoteAuthor = 'Leoon';

String acceleratedDownloadUrl(String originalUrl) =>
    'https://down.npee.cn/?$originalUrl';

bool isReleaseNewer({
  required String currentVersion,
  required String releaseTag,
}) {
  final current = _versionParts(currentVersion);
  final release = _versionParts(releaseTag);
  for (var index = 0; index < 3; index++) {
    if (release[index] > current[index]) {
      return true;
    }
    if (release[index] < current[index]) {
      return false;
    }
  }
  return false;
}

List<int> _versionParts(String value) {
  final normalized = value
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split('+')
      .first
      .split('-')
      .first;
  final parts = normalized
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts.take(3).toList(growable: false);
}

class GithubReleaseAsset {
  const GithubReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  factory GithubReleaseAsset.fromJson(Map<String, Object?> json) {
    return GithubReleaseAsset(
      name: json['name'] as String? ?? '安装包',
      downloadUrl: json['browser_download_url'] as String? ?? '',
      size: json['size'] as int? ?? 0,
    );
  }

  final String name;
  final String downloadUrl;
  final int size;
}

class GithubRelease {
  const GithubRelease({
    required this.tagName,
    required this.name,
    required this.htmlUrl,
    required this.body,
    required this.assets,
  });

  factory GithubRelease.fromJson(Map<String, Object?> json) {
    final rawAssets = json['assets'];
    return GithubRelease(
      tagName: json['tag_name'] as String? ?? '',
      name: json['name'] as String? ?? '',
      htmlUrl: json['html_url'] as String? ?? offNoteGithubRepoUrl,
      body: json['body'] as String? ?? '',
      assets: rawAssets is List
          ? rawAssets
                .whereType<Map<String, Object?>>()
                .map(GithubReleaseAsset.fromJson)
                .toList(growable: false)
          : const [],
    );
  }

  final String tagName;
  final String name;
  final String htmlUrl;
  final String body;
  final List<GithubReleaseAsset> assets;

  GithubReleaseAsset? get apkAsset {
    for (final asset in assets) {
      if (asset.name.toLowerCase().endsWith('.apk') &&
          asset.downloadUrl.isNotEmpty) {
        return asset;
      }
    }
    return null;
  }
}

class AppUpdateService {
  AppUpdateService({Dio? dio}) : _dio = dio ?? Dio();

  static const _channel = MethodChannel('offnote/app_update');

  final Dio _dio;

  Future<GithubRelease> fetchLatestRelease() async {
    final response = await _dio.get<Map<String, Object?>>(
      offNoteGithubLatestReleaseApi,
      options: Options(headers: {'Accept': 'application/vnd.github+json'}),
    );
    final data = response.data;
    if (data == null) {
      throw Exception('GitHub Release 返回为空');
    }
    return GithubRelease.fromJson(data);
  }

  Future<File> downloadApk({
    required String url,
    required String fileName,
    required void Function(int received, int total) onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await _dio.download(url, file.path, onReceiveProgress: onProgress);
    return file;
  }

  Future<void> installApk(File file) {
    return _channel.invokeMethod<void>('installApk', {'path': file.path});
  }
}
