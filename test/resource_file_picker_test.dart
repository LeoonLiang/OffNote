import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/resource_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ResourceFilePicker.channel, null);
  });

  test('pickImageResourceFile invokes native image picker', () async {
    const picker = ResourceFilePicker();
    String? method;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ResourceFilePicker.channel, (
          MethodCall call,
        ) async {
          method = call.method;
          return '/tmp/image.png';
        });

    expect(await picker.pickImageResourceFilePath(), '/tmp/image.png');
    expect(method, 'pickImageResourceFile');
  });

  test('pickVideoResourceFile invokes native video picker', () async {
    const picker = ResourceFilePicker();
    String? method;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ResourceFilePicker.channel, (
          MethodCall call,
        ) async {
          method = call.method;
          return '/tmp/video.mp4';
        });

    expect(await picker.pickVideoResourceFilePath(), '/tmp/video.mp4');
    expect(method, 'pickVideoResourceFile');
  });
}
