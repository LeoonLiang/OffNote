import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import 'media_download_failure.dart';

String describeSaveFailure(Object error) {
  final text = error.toString();
  if (text.contains('没有识别到链接')) {
    return '没有识别到链接，请粘贴小红书分享文本或网页链接。';
  }

  if (error is TimeoutException || text.contains('网页内容还没加载完成')) {
    return '网页内容还没加载完整，可能是网络慢或页面被拦截。请稍后重试，或先复制链接再打开小红书确认页面可访问。';
  }

  if (error is MediaDownloadIncompleteException) {
    return '${error.summary}。${error.detail}';
  }

  if (error is DioException) {
    if (error.type == DioExceptionType.connectionError ||
        error.error is SocketException) {
      return '网络连接失败，请检查网络后重试。';
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return '网络请求超时，请稍后重试。';
    }
  }

  if (error is SocketException || text.contains('SocketException')) {
    return '网络连接失败，请检查网络后重试。';
  }

  return '保存失败，请稍后重试。诊断信息：$text';
}
