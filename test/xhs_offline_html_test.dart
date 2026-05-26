import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/article_snapshot.dart';
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

  test('shows an offline media warning when all media downloads fail', () {
    final html = buildXhsOfflineHtml(
      title: '离线失败的笔记',
      content: '正文仍然应该可以阅读',
      localImageUris: const [],
      failedImageCount: 2,
    );

    expect(html, contains('媒体未完整保存'));
    expect(html, contains('2 张图片保存失败'));
    expect(html, isNot(contains('1</span> / 0')));
  });

  test('renders saved note comments below the article body', () {
    final html = buildXhsOfflineHtml(
      title: '格木村，让我来帮你宣传好了！',
      content: '徒步格聂扎营格木村',
      localImageUris: const ['file:///tmp/article/images/image_0.jpg'],
      comments: const [
        ArticleComment(
          authorName: '墩墩',
          content: '国庆去不知道还好看吗？',
          localAuthorAvatarUri: 'file:///tmp/article/images/comment_avatar_0.jpg',
          ipLocation: '河南',
          likeCount: 3,
          depth: 0,
          localImageUris: ['file:///tmp/article/images/comment_0_0.jpg'],
        ),
        ArticleComment(
          authorName: '蓝蓝',
          content: '花期就那么一个多月',
          ipLocation: '河南',
          depth: 1,
        ),
      ],
      commentCount: 57,
    );

    expect(html, contains('评论 57'));
    expect(html, contains('class="comment-avatar"'));
    expect(
      html,
      contains('src="file:///tmp/article/images/comment_avatar_0.jpg"'),
    );
    expect(html, contains('墩墩'));
    expect(html, contains('国庆去不知道还好看吗？'));
    expect(html, contains('河南'));
    expect(html, contains('3 赞'));
    expect(html, contains('class="comment reply"'));
    expect(html, isNot(contains('border-left: 2px solid')));
    expect(html, contains('file:///tmp/article/images/comment_0_0.jpg'));
  });
}
