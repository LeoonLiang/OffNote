import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/backup_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFilePicker.channel, null);
  });

  test('exportBackupToDownloads invokes native export method', () async {
    const picker = BackupFilePicker();
    String? method;
    Object? arguments;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(BackupFilePicker.channel, (
          MethodCall call,
        ) async {
          method = call.method;
          arguments = call.arguments;
          return 'Download/OffNote/offnote-backup.offnote-backup';
        });

    final exported = await picker.exportBackupToDownloads(
      '/tmp/offnote-backup.offnote-backup',
    );

    expect(exported, 'Download/OffNote/offnote-backup.offnote-backup');
    expect(method, 'exportBackupToDownloads');
    expect(arguments, {'path': '/tmp/offnote-backup.offnote-backup'});
  });
}
