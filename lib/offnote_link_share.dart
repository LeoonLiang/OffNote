import 'saved_article.dart';

bool isSupportedXhsUrl(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return host == 'xhslink.com' ||
      host == 'xiaohongshu.com' ||
      host.endsWith('.xiaohongshu.com');
}

List<String> supportedXhsUrls(Iterable<String> urls) {
  final seen = <String>{};
  final supported = <String>[];
  for (final rawUrl in urls) {
    final url = rawUrl.trim();
    if (url.isEmpty || !isSupportedXhsUrl(url) || !seen.add(url)) {
      continue;
    }
    supported.add(url);
  }
  return supported;
}

List<String> selectedArticleShareUrls(Iterable<SavedArticle> articles) {
  return supportedXhsUrls(
    articles.map((article) {
      final originalUrl = article.originalUrl.trim();
      return originalUrl.isNotEmpty ? originalUrl : article.sourceUrl;
    }),
  );
}

String formatSelectedArticleLinks(List<String> urls) {
  return 'OffNote 分享了 ${urls.length} 篇笔记：\n\n${urls.join('\n')}';
}
