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

List<String> unconsumedSupportedXhsUrls(
  Iterable<String> urls,
  Set<String> consumedUrls,
) {
  return supportedXhsUrls(
    urls,
  ).where((url) => !consumedUrls.contains(url)).toList(growable: false);
}

List<String> selectedArticleShareUrls(Iterable<SavedArticle> articles) {
  return supportedXhsUrls(
    articles.map((article) {
      final originalUrl = article.originalUrl.trim();
      return originalUrl.isNotEmpty ? originalUrl : article.sourceUrl;
    }),
  );
}

String formatSelectedArticleLinks(List<String> urls, {String? title}) {
  final normalizedTitle = title?.trim();
  final prefix = normalizedTitle == null || normalizedTitle.isEmpty
      ? 'OffNote 分享了 ${urls.length} 篇笔记：'
      : 'OffNote 分享了「$normalizedTitle」里的 ${urls.length} 篇笔记：';
  return '$prefix\n\n${urls.join('\n')}';
}
