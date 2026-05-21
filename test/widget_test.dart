import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/link_parser.dart';

void main() {
  test('extracts a URL from pasted share text', () {
    expect(
      extractFirstUrl('复制这段话打开 App https://example.com/a?b=c'),
      'https://example.com/a?b=c',
    );
  });
}
