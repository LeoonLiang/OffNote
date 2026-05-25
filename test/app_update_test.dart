import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/app_update.dart';

void main() {
  test('compares semantic versions without build numbers', () {
    expect(
      isReleaseNewer(currentVersion: '1.0.0+1', releaseTag: 'v1.0.1'),
      isTrue,
    );
    expect(
      isReleaseNewer(currentVersion: '1.2.0', releaseTag: 'v1.1.9'),
      isFalse,
    );
    expect(
      isReleaseNewer(currentVersion: '1.0.0+1', releaseTag: 'v1.0.0'),
      isFalse,
    );
  });

  test('builds accelerated download url', () {
    expect(
      acceleratedDownloadUrl(
        'https://github.com/LeoonLiang/OffNote/releases/download/v1/app.apk',
      ),
      'https://down.npee.cn/?https://github.com/LeoonLiang/OffNote/releases/download/v1/app.apk',
    );
  });

  test('picks apk asset from latest release json', () {
    final release = GithubRelease.fromJson({
      'tag_name': 'v1.1.0',
      'name': 'OffNote 1.1.0',
      'html_url': 'https://github.com/LeoonLiang/OffNote/releases/tag/v1.1.0',
      'body': '更新内容',
      'assets': [
        {
          'name': 'notes.txt',
          'browser_download_url': 'https://example.com/notes.txt',
          'size': 10,
        },
        {
          'name': 'OffNote-v1.1.0.apk',
          'browser_download_url': 'https://example.com/app.apk',
          'size': 123,
        },
      ],
    });

    expect(release.apkAsset?.name, 'OffNote-v1.1.0.apk');
    expect(release.apkAsset?.downloadUrl, 'https://example.com/app.apk');
  });
}
