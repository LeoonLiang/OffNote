import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/article_detail_result.dart';

void main() {
  test('only changed detail result requests a list refresh', () {
    expect(ArticleDetailResult.unchanged.needsListRefresh, isFalse);
    expect(ArticleDetailResult.changed.needsListRefresh, isTrue);
  });
}
