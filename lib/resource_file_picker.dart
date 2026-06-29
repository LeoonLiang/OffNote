import 'package:flutter/services.dart';

class ResourceFilePicker {
  const ResourceFilePicker();

  static const channel = MethodChannel('offnote/resource_files');

  Future<String?> pickImageResourceFilePath() {
    return channel.invokeMethod<String>('pickImageResourceFile');
  }

  Future<String?> pickVideoResourceFilePath() {
    return channel.invokeMethod<String>('pickVideoResourceFile');
  }
}
