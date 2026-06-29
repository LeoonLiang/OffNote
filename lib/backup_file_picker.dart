import 'package:flutter/services.dart';

class BackupFilePicker {
  const BackupFilePicker();

  static const channel = MethodChannel('offnote/backup_files');

  Future<String?> pickBackupFilePath() {
    return channel.invokeMethod<String>('pickBackupFile');
  }

  Future<String?> exportBackupToDownloads(String path) {
    return channel.invokeMethod<String>('exportBackupToDownloads', {
      'path': path,
    });
  }
}
