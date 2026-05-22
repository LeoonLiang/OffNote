import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/xhs_offline_html.dart';

void main() {
  test('builds a static xhs-style page with carousel author and body only', () {
    final html = buildXhsOfflineHtml(
      title: '格木村，让我来帮你宣传好了！',
      content: '徒步格聂扎营格木村\n#这里是格聂[话题]#',
      authorName: '蓝蓝',
      authorAvatarUri: 'file:///tmp/article/images/author_avatar.jpg',
      localImageUris: const [
        'file:///tmp/article/images/image_0.jpg',
        'file:///tmp/article/images/image_1.jpg',
      ],
    );

    expect(html, contains('class="carousel"'));
    expect(html, contains('file:///tmp/article/images/image_0.jpg'));
    expect(html, contains('id="current-slide"'));
    expect(html, contains('class="dot active"'));
    expect(html, contains('蓝蓝'));
    expect(html, contains('徒步格聂扎营格木村'));
    expect(html, isNot(contains('相关推荐')));
    expect(html, isNot(contains('打开 App')));
  });

  test('builds a static xhs-style page with local video player', () {
    final html = buildXhsOfflineHtml(
      title: '外骨骼徒步',
      content: '走进雪山\n#外骨骼[话题]#',
      authorName: '阿呸Ah bah',
      authorAvatarUri: 'file:///tmp/article/images/author_avatar.jpg',
      localImageUris: const [],
      localVideoUri: 'file:///tmp/article/videos/video_0.mp4',
      localPosterUri: 'file:///tmp/article/images/poster.jpg',
    );

    expect(html, contains('<video class="video-player" controls'));
    expect(html, contains('src="file:///tmp/article/videos/video_0.mp4"'));
    expect(html, contains('poster="file:///tmp/article/images/poster.jpg"'));
    expect(html, contains('外骨骼徒步'));
    expect(html, contains('走进雪山'));
  });
}
