import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/save_failure_message.dart';

void main() {
  group('describeSaveFailure', () {
    test('explains missing links without exposing exception wrappers', () {
      expect(
        describeSaveFailure(Exception('没有识别到链接')),
        '没有识别到链接，请粘贴小红书分享文本或网页链接。',
      );
    });

    test('explains page readiness timeout as a retryable loading problem', () {
      expect(
        describeSaveFailure(TimeoutException('网页内容还没加载完成，请稍后重试')),
        '网页内容还没加载完整，可能是网络慢或页面被拦截。请稍后重试，或先复制链接再打开小红书确认页面可访问。',
      );
    });

    test('explains dio connection failures as network problems', () {
      final error = DioException(
        requestOptions: RequestOptions(path: 'https://example.com/a.jpg'),
        type: DioExceptionType.connectionError,
        error: const SocketException('offline'),
      );

      expect(describeSaveFailure(error), '网络连接失败，请检查网络后重试。');
    });
  });
}
