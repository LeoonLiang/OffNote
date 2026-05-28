import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/link_parser.dart';

void main() {
  group('extractUrls', () {
    test('extracts multiple URLs from shared text in order', () {
      const text =
          'OffNote 分享了 2 篇笔记：\n\n'
          'https://xhslink.com/a，'
          'https://www.xiaohongshu.com/discovery/item/b?x=1。';

      expect(extractUrls(text), [
        'https://xhslink.com/a',
        'https://www.xiaohongshu.com/discovery/item/b?x=1',
      ]);
    });

    test('removes duplicates while preserving first occurrence', () {
      const text =
          'https://xhslink.com/a https://xhslink.com/b https://xhslink.com/a';

      expect(extractUrls(text), [
        'https://xhslink.com/a',
        'https://xhslink.com/b',
      ]);
    });
  });

  group('extractFirstUrl', () {
    test('extracts xhs short link from shared Chinese text', () {
      const text =
          '格木村，让我来帮你宣传好了！ 徒步格聂扎营格木村 意... http://xhslink.com/o/5ZfJTdyoUMS \n'
          '小伙伴复制一下，打开【小红书】就能看到内容。';

      expect(extractFirstUrl(text), 'http://xhslink.com/o/5ZfJTdyoUMS');
    });

    test('extracts a standalone xhs short link', () {
      expect(
        extractFirstUrl('http://xhslink.com/o/5ZfJTdyoUMS'),
        'http://xhslink.com/o/5ZfJTdyoUMS',
      );
    });

    test('extracts full xiaohongshu URL with query parameters', () {
      const text =
          '【汉lev最近有人提新车了吗？该继续等吗？ - .LM | 小红书 - 你的生活兴趣社区】 😆 eubalkjxb9IW34I 😆 '
          'https://www.xiaohongshu.com/discovery/item/6a0670430000000035021c0d?source=webshare&xhsshare=pc_web&xsec_token=ABwydeN1rvbM1LikUZGj65kBAAU5dkCxNcQgy2fYpR58o=&xsec_source=pc_share';

      expect(
        extractFirstUrl(text),
        'https://www.xiaohongshu.com/discovery/item/6a0670430000000035021c0d?source=webshare&xhsshare=pc_web&xsec_token=ABwydeN1rvbM1LikUZGj65kBAAU5dkCxNcQgy2fYpR58o=&xsec_source=pc_share',
      );
    });

    test('returns null when no URL is present', () {
      expect(extractFirstUrl('没有链接的分享文本'), isNull);
    });
  });
}
