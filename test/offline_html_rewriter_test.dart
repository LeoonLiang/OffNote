import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/offline_html_rewriter.dart';

void main() {
  test('preserves original note html while trimming lower page chrome', () {
    const rawHtml = '''
    <html>
      <head>
        <style>.note-card { color: red; }</style>
      </head>
      <body>
        <main class="note-card">
          <section class="carousel">
            <img class="slide" src="http://sns-webpic-qc.xhscdn.com/a/b.jpg">
            <img srcset="//sns-webpic-qc.xhscdn.com/c/d.jpg 2x, https://example.com/e.jpg 1x">
          </section>
          <section class="author">作者 A</section>
          <section class="note-content">正文内容</section>
          <section class="tag-list"><a>#徒步</a><a>#露营</a></section>
          <section class="recommend-feed">相关推荐</section>
          <button>打开 App</button>
        </main>
        <script>window.keepOriginalBehavior = true;</script>
      </body>
    </html>
    ''';

    final html = localizeHtmlResources(
      rawHtml: rawHtml,
      sourceUrl: 'https://www.xiaohongshu.com/discovery/item/demo',
      localImageUrisByUrl: const {
        'https://sns-webpic-qc.xhscdn.com/a/b.jpg':
            'file:///tmp/article/images/image_0.jpg',
        'https://sns-webpic-qc.xhscdn.com/c/d.jpg':
            'file:///tmp/article/images/image_1.jpg',
      },
    );

    expect(html, contains('class="note-card"'));
    expect(html, contains('<style>.note-card { color: red; }</style>'));
    expect(html, contains('window.keepOriginalBehavior = true'));
    expect(html, contains('作者 A'));
    expect(html, contains('正文内容'));
    expect(html, contains('#徒步'));
    expect(html, contains('src="file:///tmp/article/images/image_0.jpg"'));
    expect(html, contains('file:///tmp/article/images/image_1.jpg 2x'));
    expect(html, isNot(contains('相关推荐')));
    expect(html, isNot(contains('打开 App')));
  });
}
