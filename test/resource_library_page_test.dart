import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/saved_resource.dart';

void main() {
  test('source-less uploaded video resources have no source article', () {
    final uploadedVideo = SavedResource(
      id: 'r1',
      type: SavedResourceType.videoClip,
      articleId: '',
      sourcePath: '/tmp/video.mp4',
      title: '我的视频',
      note: '',
      status: SavedResourceStatus.ready,
      createdAt: DateTime(2026, 6, 29),
    );
    final clippedVideo = SavedResource(
      id: 'r2',
      type: SavedResourceType.videoClip,
      articleId: 'a1',
      sourcePath: '/tmp/clip.mp4',
      title: '笔记片段',
      note: '',
      status: SavedResourceStatus.ready,
      createdAt: DateTime(2026, 6, 29),
    );

    expect(savedResourceHasSourceArticle(uploadedVideo), isFalse);
    expect(savedResourceHasSourceArticle(clippedVideo), isTrue);
  });
}
