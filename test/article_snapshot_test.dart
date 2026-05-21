import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/article_snapshot.dart';

void main() {
  group('parseArticleSnapshot', () {
    test('extracts title, readable text, and normalized image URLs', () {
      const html = '''
      <html>
        <head><title>格木村徒步 - 小红书</title></head>
        <body>
          <script>window.bad = true;</script>
          <style>.hidden { display: none; }</style>
          <main>
            <h1>格木村徒步</h1>
            <p>徒步格聂扎营格木村。</p>
            <img src="http://sns-webpic-qc.xhscdn.com/a/b.jpg">
            <img data-src="//sns-webpic-qc.xhscdn.com/c/d.jpg">
          </main>
        </body>
      </html>
      ''';

      final snapshot = parseArticleSnapshot(
        html: html,
        sourceUrl: 'https://www.xiaohongshu.com/discovery/item/demo',
      );

      expect(snapshot.title, '格木村徒步 - 小红书');
      expect(snapshot.content, contains('徒步格聂扎营格木村'));
      expect(snapshot.content, isNot(contains('window.bad')));
      expect(snapshot.imageUrls, [
        'https://sns-webpic-qc.xhscdn.com/a/b.jpg',
        'https://sns-webpic-qc.xhscdn.com/c/d.jpg',
      ]);
    });

    test('falls back to source host when title is missing', () {
      final snapshot = parseArticleSnapshot(
        html: '<html><body><p>正文</p></body></html>',
        sourceUrl: 'https://example.com/a',
      );

      expect(snapshot.title, 'example.com');
    });

    test('prefers article metadata and filters app/recommendation chrome', () {
      const html = '''
      <html>
        <head>
          <meta property="og:title" content="露营笔记">
          <meta name="description" content="这里是完整正文第一段。这里是完整正文第二段。">
        </head>
        <body>
          <button>打开 App</button>
          <section>相关推荐 你可能还喜欢</section>
          <main>
            <p>这里是完整正文第一段。</p>
            <p>这里是完整正文第二段。</p>
          </main>
        </body>
      </html>
      ''';

      final snapshot = parseArticleSnapshot(
        html: html,
        sourceUrl: 'https://www.xiaohongshu.com/discovery/item/demo',
      );

      expect(snapshot.title, '露营笔记');
      expect(snapshot.content, '这里是完整正文第一段。这里是完整正文第二段。');
      expect(snapshot.content, isNot(contains('打开 App')));
      expect(snapshot.content, isNot(contains('相关推荐')));
    });
  });
}
