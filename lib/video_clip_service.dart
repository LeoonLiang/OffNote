import 'package:flutter/services.dart';

class VideoClipService {
  const VideoClipService();

  static const _channel = MethodChannel('offnote/video_tools');

  Future<void> trimVideo({
    required String inputPath,
    required String outputPath,
    required Duration start,
    required Duration end,
  }) async {
    if (end <= start) {
      throw ArgumentError.value(end, 'end', 'End must be after start.');
    }
    await _channel.invokeMethod<void>('trimVideo', {
      'inputPath': inputPath,
      'outputPath': outputPath,
      'startMs': start.inMilliseconds,
      'endMs': end.inMilliseconds,
    });
  }
}
