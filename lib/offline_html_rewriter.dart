import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'article_snapshot.dart';

String localizeHtmlResources({
  required String rawHtml,
  required String sourceUrl,
  required Map<String, String> localImageUrisByUrl,
}) {
  final document = html_parser.parse(rawHtml);

  for (final image in document.querySelectorAll('img')) {
    _rewriteImageAttributes(
      image: image,
      sourceUrl: sourceUrl,
      localImageUrisByUrl: localImageUrisByUrl,
    );
  }

  _trimToCoreNoteDom(document);

  return document.outerHtml;
}

void _trimToCoreNoteDom(dom.Document document) {
  final tagBlock = _lastMatchingElement(
    document,
    (element) => _looksLikeTagBlock(element),
  );
  if (tagBlock != null) {
    _removeFollowingSiblingsAfter(_blockChildForTruncation(tagBlock));
  }

  for (final element in document.querySelectorAll('*').toList().reversed) {
    if (_isProtectedContainer(element)) {
      continue;
    }
    if (_looksLikeLowerPageChrome(element)) {
      element.remove();
    }
  }
}

void _rewriteImageAttributes({
  required dom.Element image,
  required String sourceUrl,
  required Map<String, String> localImageUrisByUrl,
}) {
  for (final attribute in ['src', 'data-src', 'data-original', 'data-lazy']) {
    final value = image.attributes[attribute];
    if (value == null) {
      continue;
    }

    final localUri =
        localImageUrisByUrl[normalizeResourceUrl(value, sourceUrl)];
    if (localUri != null) {
      image.attributes[attribute] = localUri;
    }
  }

  final srcset = image.attributes['srcset'];
  if (srcset != null) {
    image.attributes['srcset'] = _rewriteSrcset(
      srcset: srcset,
      sourceUrl: sourceUrl,
      localImageUrisByUrl: localImageUrisByUrl,
    );
  }
}

String _rewriteSrcset({
  required String srcset,
  required String sourceUrl,
  required Map<String, String> localImageUrisByUrl,
}) {
  return srcset
      .split(',')
      .map((candidate) {
        final trimmed = candidate.trim();
        if (trimmed.isEmpty) {
          return trimmed;
        }

        final parts = trimmed.split(RegExp(r'\s+'));
        final normalized = normalizeResourceUrl(parts.first, sourceUrl);
        final localUri = localImageUrisByUrl[normalized];
        if (localUri == null) {
          return trimmed;
        }

        return [localUri, ...parts.skip(1)].join(' ');
      })
      .join(', ');
}

dom.Element? _lastMatchingElement(
  dom.Document document,
  bool Function(dom.Element element) matches,
) {
  dom.Element? result;
  for (final element in document.querySelectorAll('*')) {
    if (matches(element)) {
      result = element;
    }
  }
  return result;
}

bool _looksLikeTagBlock(dom.Element element) {
  final marker = _elementMarker(element);
  if (RegExp(r'(tag|topic|hashtag|keyword)').hasMatch(marker)) {
    return true;
  }

  final text = _normalizedText(element);
  if (text.length > 160) {
    return false;
  }

  return RegExp(r'(^|\s)#\S+').hasMatch(text) ||
      element
          .querySelectorAll('a')
          .any((anchor) => _normalizedText(anchor).startsWith('#'));
}

bool _looksLikeLowerPageChrome(dom.Element element) {
  final marker = _elementMarker(element);
  if (RegExp(
    r'(recommend|related|comment|footer|bottom|open[-_]?app|download|app[-_]?banner|login|modal|toast|popup|feed)',
  ).hasMatch(marker)) {
    return true;
  }

  final text = _normalizedText(element);
  if (text.length > 240) {
    return false;
  }

  return RegExp(
    r'(打开\s*(App|APP|小红书)|小红书\s*App\s*查看|相关推荐|更多推荐|你可能还喜欢|评论|写评论|打开看看)',
  ).hasMatch(text);
}

dom.Element _blockChildForTruncation(dom.Element element) {
  var current = element;
  while (current.parent is dom.Element) {
    final parent = current.parent as dom.Element;
    if (_isProtectedContainer(parent)) {
      return current;
    }
    current = parent;
  }
  return element;
}

void _removeFollowingSiblingsAfter(dom.Element element) {
  var sibling = element.nextElementSibling;
  while (sibling != null) {
    final next = sibling.nextElementSibling;
    if (!_isRuntimeAsset(sibling)) {
      sibling.remove();
    }
    sibling = next;
  }
}

bool _isProtectedContainer(dom.Element element) {
  return const {'html', 'head', 'body'}.contains(element.localName) ||
      _isRuntimeAsset(element);
}

bool _isRuntimeAsset(dom.Element element) {
  return const {'script', 'style', 'link'}.contains(element.localName);
}

String _elementMarker(dom.Element element) {
  return [
    element.localName,
    element.id,
    element.classes.join(' '),
    element.attributes['role'],
    element.attributes['aria-label'],
    element.attributes['data-testid'],
  ].whereType<String>().join(' ').toLowerCase();
}

String _normalizedText(dom.Element element) {
  return element.text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
