import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'xhs_note_snapshot.dart';

class ArticleSnapshot {
  const ArticleSnapshot({
    required this.title,
    required this.content,
    required this.sourceUrl,
    required this.html,
    required this.imageUrls,
    this.authorName,
    this.authorAvatarUrl,
  });

  final String title;
  final String content;
  final String sourceUrl;
  final String html;
  final List<String> imageUrls;
  final String? authorName;
  final String? authorAvatarUrl;
}

ArticleSnapshot parseArticleSnapshot({
  required String html,
  required String sourceUrl,
}) {
  final xhsSnapshot = parseXhsNoteSnapshot(html: html, sourceUrl: sourceUrl);
  if (xhsSnapshot != null) {
    return ArticleSnapshot(
      title: xhsSnapshot.title,
      content: xhsSnapshot.content,
      sourceUrl: sourceUrl,
      html: html,
      imageUrls: xhsSnapshot.imageUrls,
      authorName: xhsSnapshot.authorName,
      authorAvatarUrl: xhsSnapshot.authorAvatarUrl,
    );
  }

  final document = html_parser.parse(html);
  document.querySelectorAll('script, style, noscript, svg').forEach((node) {
    node.remove();
  });

  final title = _firstNonEmpty([
    document.querySelector('meta[property="og:title"]')?.attributes['content'],
    document.querySelector('title')?.text,
    document.querySelector('h1')?.text,
    Uri.tryParse(sourceUrl)?.host,
  ]);
  final content = _extractContent(document);
  final imageUrls = _extractImageUrls(document, sourceUrl);

  return ArticleSnapshot(
    title: title,
    content: content,
    sourceUrl: sourceUrl,
    html: document.outerHtml,
    imageUrls: imageUrls,
  );
}

String _extractContent(dom.Document document) {
  final metadata = _firstNonEmpty([
    document.querySelector('meta[name="description"]')?.attributes['content'],
    document
        .querySelector('meta[property="og:description"]')
        ?.attributes['content'],
  ]);
  if (metadata != '未命名网页') {
    return _cleanArticleText(metadata);
  }

  final scope =
      document.querySelector('article') ??
      document.querySelector('main') ??
      document.body;
  return _cleanArticleText(scope?.text ?? '');
}

String _cleanArticleText(String text) {
  final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  final blocked = [
    RegExp(r'打开\s*(App|APP|小红书)'),
    RegExp(r'小红书\s*App\s*查看'),
    RegExp(r'相关推荐.*$', dotAll: true),
    RegExp(r'更多推荐.*$', dotAll: true),
    RegExp(r'你可能还喜欢.*$', dotAll: true),
  ];

  var cleaned = normalized;
  for (final pattern in blocked) {
    cleaned = cleaned.replaceAll(pattern, '');
  }
  return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String normalizeResourceUrl(String rawUrl, String sourceUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty ||
      trimmed.startsWith('data:') ||
      trimmed.startsWith('blob:')) {
    return '';
  }

  Uri? uri;
  if (trimmed.startsWith('//')) {
    uri = Uri.parse('https:$trimmed');
  } else {
    uri = Uri.tryParse(trimmed);
  }

  final sourceUri = Uri.tryParse(sourceUrl);
  if (uri == null) {
    return '';
  }

  if (!uri.hasScheme && sourceUri != null) {
    uri = sourceUri.resolveUri(uri);
  }

  if (uri.scheme == 'http' && _canUpgradeToHttps(uri)) {
    uri = uri.replace(scheme: 'https');
  }

  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return '';
  }

  return uri.toString();
}

List<String> _extractImageUrls(dom.Document document, String sourceUrl) {
  final urls = <String>{};
  for (final image in document.querySelectorAll('img')) {
    for (final attribute in ['src', 'data-src', 'data-original', 'data-lazy']) {
      final value = image.attributes[attribute];
      if (value == null) {
        continue;
      }
      final normalized = normalizeResourceUrl(value, sourceUrl);
      if (normalized.isNotEmpty) {
        urls.add(normalized);
      }
    }
  }
  return urls.toList(growable: false);
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final normalized = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized != null && normalized.isNotEmpty) {
      return normalized;
    }
  }
  return '未命名网页';
}

bool _canUpgradeToHttps(Uri uri) {
  return uri.host.endsWith('xhscdn.com') ||
      uri.host.endsWith('xiaohongshu.com');
}
