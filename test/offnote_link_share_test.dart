import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/offnote_link_share.dart';
import 'package:offnote/saved_article.dart';

void main() {
  group('selectedArticleShareUrls', () {
    test('prefers original URL and falls back to source URL', () {
      final articles = [
        _article(
          id: '1',
          originalUrl: 'https://xhslink.com/original',
          sourceUrl: 'https://www.xiaohongshu.com/discovery/item/source',
        ),
        _article(
          id: '2',
          originalUrl: '',
          sourceUrl: 'https://xhslink.com/fallback',
        ),
      ];

      expect(selectedArticleShareUrls(articles), [
        'https://xhslink.com/original',
        'https://xhslink.com/fallback',
      ]);
    });

    test('keeps Xiaohongshu links once in article order', () {
      final articles = [
        _article(id: '1', originalUrl: 'https://example.com/ignored'),
        _article(id: '2', originalUrl: 'https://xhslink.com/a'),
        _article(id: '3', originalUrl: 'https://xhslink.com/a'),
        _article(id: '4', originalUrl: 'https://xhslink.com/b'),
      ];

      expect(selectedArticleShareUrls(articles), [
        'https://xhslink.com/a',
        'https://xhslink.com/b',
      ]);
    });
  });

  test('returns only supported URLs that have not been consumed', () {
    expect(
      unconsumedSupportedXhsUrls(
        [
          'https://xhslink.com/a',
          'https://example.com/ignored',
          'https://xhslink.com/b',
        ],
        {'https://xhslink.com/a'},
      ),
      ['https://xhslink.com/b'],
    );
  });

  test('formats selected article links as plain text', () {
    final text = formatSelectedArticleLinks([
      'https://xhslink.com/a',
      'https://xhslink.com/b',
    ]);

    expect(
      text,
      'OffNote 分享了 2 篇笔记：\n\n'
      'https://xhslink.com/a\n'
      'https://xhslink.com/b',
    );
  });

  test('formats folder article links with folder name', () {
    final text = formatSelectedArticleLinks([
      'https://xhslink.com/a',
      'https://xhslink.com/b',
    ], title: '旅行');

    expect(
      text,
      'OffNote 分享了「旅行」里的 2 篇笔记：\n\n'
      'https://xhslink.com/a\n'
      'https://xhslink.com/b',
    );
  });
}

SavedArticle _article({
  required String id,
  String sourceUrl = 'https://xhslink.com/source',
  String originalUrl = 'https://xhslink.com/original',
}) {
  return SavedArticle(
    id: id,
    title: 'title $id',
    content: '',
    htmlPath: '/tmp/$id/index.html',
    coverPath: null,
    sourceUrl: sourceUrl,
    originalUrl: originalUrl,
    publishedAt: DateTime(2026),
    savedAt: DateTime(2026),
  );
}
