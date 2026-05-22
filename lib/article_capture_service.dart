import 'dart:async';

import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'article_snapshot_store.dart';
import 'js_result_decoder.dart';
import 'saved_article.dart';
import 'snapshot_readiness.dart';
import 'web_navigation_policy.dart';

class ArticleCaptureService {
  ArticleCaptureService({required ArticleSnapshotStore store}) : _store = store;

  final ArticleSnapshotStore _store;
  Completer<void>? _pageLoaded;

  Future<SavedArticle> saveUrl(String url) async {
    final controller = await _createController();
    _pageLoaded = Completer<void>();
    await controller.loadRequest(Uri.parse(url));
    await _pageLoaded!.future.timeout(const Duration(seconds: 35));
    await _waitForSnapshotReady(controller);
    final sourceUrl = await controller.currentUrl() ?? url;
    final htmlResult = await controller.runJavaScriptReturningResult(
      'document.documentElement.outerHTML',
    );
    final html = decodeJavaScriptStringResult(htmlResult);
    return _store.save(rawHtml: html, sourceUrl: sourceUrl);
  }

  Future<void> _waitForSnapshotReady(WebViewController controller) async {
    final deadline = DateTime.now().add(const Duration(seconds: 18));
    while (DateTime.now().isBefore(deadline)) {
      final result = await controller.runJavaScriptReturningResult(
        snapshotReadyProbeScript,
      );
      if (decodeSnapshotReadinessResult(result)) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw TimeoutException('网页内容还没加载完成，请稍后重试');
  }

  Future<WebViewController> _createController() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (_pageLoaded?.isCompleted == false) {
              _pageLoaded?.complete();
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);
            return shouldLoadInWebView(uri)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (_pageLoaded?.isCompleted == false &&
                error.isForMainFrame == true) {
              _pageLoaded?.completeError(error.description);
            }
          },
        ),
      );
    final platformController = controller.platform;
    if (platformController is AndroidWebViewController) {
      await platformController.setMixedContentMode(
        MixedContentMode.alwaysAllow,
      );
    }
    return controller;
  }
}
