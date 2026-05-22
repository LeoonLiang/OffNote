import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android manifest registers a text share target', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.intent.action.SEND'));
    expect(manifest, contains('android.intent.category.DEFAULT'));
    expect(manifest, contains('android:mimeType="text/plain"'));
  });
}
