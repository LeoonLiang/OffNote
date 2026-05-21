import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/web_navigation_policy.dart';

void main() {
  group('shouldLoadInWebView', () {
    test('allows http and https pages', () {
      expect(
        shouldLoadInWebView(Uri.parse('http://xhslink.com/o/demo')),
        isTrue,
      );
      expect(
        shouldLoadInWebView(
          Uri.parse('https://www.xiaohongshu.com/discovery/item/demo'),
        ),
        isTrue,
      );
    });

    test('blocks app deep links triggered by xiaohongshu pages', () {
      final uri = Uri.parse(
        'xhsdiscover://item/688c765e00000000230333d0?open_url=%2Fdiscovery%2Fitem%2F688c765e00000000230333d0',
      );

      expect(shouldLoadInWebView(uri), isFalse);
    });
  });
}
