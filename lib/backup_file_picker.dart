import 'package:flutter/services.dart';

class BackupFilePicker {
  const BackupFilePicker();

  static const _channel = MethodChannel('offnote/backup_files');

  Future<String?> pickBackupFilePath() {
    return _channel.invokeMethod<String>('pickBackupFile');
  }
}
