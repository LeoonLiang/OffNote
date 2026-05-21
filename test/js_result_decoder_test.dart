import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/js_result_decoder.dart';

void main() {
  group('decodeJavaScriptStringResult', () {
    test('decodes quoted JavaScript string results', () {
      expect(
        decodeJavaScriptStringResult(
          '"\\u003Chtml\\u003E正文\\u003C/html\\u003E"',
        ),
        '<html>正文</html>',
      );
    });

    test('keeps unquoted HTML results unchanged', () {
      expect(
        decodeJavaScriptStringResult('<html>正文</html>'),
        '<html>正文</html>',
      );
    });
  });
}
