import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/article_file_paths.dart';

void main() {
  test('returns the article directory from an index html path', () {
    expect(
      articleDirectoryPathFromHtmlPath('/tmp/offnote/articles/abc/index.html'),
      '/tmp/offnote/articles/abc',
    );
  });
}
