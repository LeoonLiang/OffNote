import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/article_display.dart';
import 'package:offnote/saved_article.dart';

void main() {
  SavedArticle article({String? categoryId}) {
    return SavedArticle(
      id: 'a',
      title: '标题',
      content: '正文',
      htmlPath: '/tmp/a/index.html',
      coverPath: null,
      sourceUrl: 'https://example.com/a',
      publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
      savedAt: DateTime.fromMillisecondsSinceEpoch(2),
      categoryId: categoryId,
    );
  }

  test('returns folder name for categorized article', () {
    expect(
      articleCategoryLabel(article(categoryId: 'food'), {'food': '吃的'}),
      '吃的',
    );
  });

  test('returns null for uncategorized article', () {
    expect(articleCategoryLabel(article(), {'food': '吃的'}), isNull);
  });
}
