import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/gallery.dart';
import 'package:offnote/saved_article.dart';

void main() {
  SavedArticle article({
    required String id,
    required ArticleMediaType mediaType,
    List<String> imagePaths = const [],
    String? coverPath,
    String? categoryId,
  }) {
    return SavedArticle(
      id: id,
      title: '标题$id',
      content: '正文',
      htmlPath: '/tmp/$id/index.html',
      coverPath: coverPath,
      sourceUrl: 'https://example.com/$id',
      publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
      savedAt: DateTime.fromMillisecondsSinceEpoch(2),
      imagePaths: imagePaths,
      mediaType: mediaType,
      categoryId: categoryId,
    );
  }

  test('expands every image article image into gallery items', () {
    final items = buildGalleryItems([
      article(
        id: 'image',
        mediaType: ArticleMediaType.image,
        imagePaths: ['/tmp/1.jpg', '/tmp/2.jpg', '/tmp/3.jpg'],
      ),
    ]);

    expect(items.map((item) => item.mediaPath), [
      '/tmp/1.jpg',
      '/tmp/2.jpg',
      '/tmp/3.jpg',
    ]);
    expect(items.every((item) => !item.isVideo), isTrue);
  });

  test('uses video cover as one playable gallery item', () {
    final items = buildGalleryItems([
      article(
        id: 'video',
        mediaType: ArticleMediaType.video,
        coverPath: '/tmp/poster.jpg',
      ),
    ]);

    expect(items, hasLength(1));
    expect(items.single.mediaPath, '/tmp/poster.jpg');
    expect(items.single.isVideo, isTrue);
  });

  test('filters gallery items by category including uncategorized', () {
    final articles = [
      article(
        id: 'a',
        mediaType: ArticleMediaType.image,
        imagePaths: ['/tmp/a.jpg'],
        categoryId: 'food',
      ),
      article(
        id: 'b',
        mediaType: ArticleMediaType.image,
        imagePaths: ['/tmp/b.jpg'],
      ),
    ];

    expect(
      buildGalleryItems(
        articles,
        categoryId: 'food',
      ).map((item) => item.article.id),
      ['a'],
    );
    expect(
      buildGalleryItems(
        articles,
        uncategorizedOnly: true,
      ).map((item) => item.article.id),
      ['b'],
    );
  });

  test('lays items into the shortest masonry column', () {
    final items = buildGalleryItems([
      article(
        id: 'image',
        mediaType: ArticleMediaType.image,
        imagePaths: ['/tmp/1.jpg', '/tmp/2.jpg', '/tmp/3.jpg'],
      ),
    ]);

    final columns = distributeGalleryItems(
      items,
      columnCount: 2,
      heightForIndex: (index) => [300.0, 120.0, 120.0][index],
    );

    expect(columns[0].map((item) => item.mediaPath), ['/tmp/1.jpg']);
    expect(columns[1].map((item) => item.mediaPath), [
      '/tmp/2.jpg',
      '/tmp/3.jpg',
    ]);
  });
}
