import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'article_snapshot.dart';

class XhsNoteSnapshot {
  const XhsNoteSnapshot({
    required this.title,
    required this.content,
    required this.imageUrls,
    this.comments = const [],
    this.commentCount,
    this.videoUrl,
    this.posterUrl,
    this.authorName,
    this.authorAvatarUrl,
    this.publishedAt,
  });

  final String title;
  final String content;
  final List<String> imageUrls;
  final List<ArticleComment> comments;
  final int? commentCount;
  final String? videoUrl;
  final String? posterUrl;
  final String? authorName;
  final String? authorAvatarUrl;
  final DateTime? publishedAt;
}

XhsNoteSnapshot? parseXhsNoteSnapshot({
  required String html,
  required String sourceUrl,
}) {
  final renderedSnapshot = _parseRenderedNoteSnapshot(
    html: html,
    sourceUrl: sourceUrl,
  );
  if (renderedSnapshot != null) {
    return renderedSnapshot;
  }

  final state = _decodeInitialState(html);
  if (state == null) {
    return null;
  }

  final note = _findNoteMap(state);
  if (note == null) {
    return null;
  }

  final title = _stringValue(note['title']) ?? _titleFromHtml(html);
  final content =
      _contentStringValue(note['desc']) ?? _descriptionFromHtml(html);
  final user = note['user'] is Map ? note['user'] as Map : null;
  final authorName =
      _stringValue(user?['nickName']) ??
      _stringValue(user?['nickname']) ??
      _stringValue(user?['name']);
  final authorAvatar = normalizeResourceUrl(
    _stringValue(user?['avatar']) ?? _stringValue(user?['image']) ?? '',
    sourceUrl,
  );
  final imageUrls = _extractImageUrlsFromNote(note, sourceUrl);
  final videoUrl = _extractVideoUrlFromNote(note, sourceUrl);
  final posterUrl = _extractPosterUrlFromHtml(html, sourceUrl);
  final publishedAt =
      _extractPublishTimeFromNote(note) ??
      extractPublishTimeFromHtml(html, sourceUrl);
  final commentsData = _findCommentsMap(state);
  final comments = _extractComments(commentsData, sourceUrl);

  if (title == null ||
      content == null ||
      (imageUrls.isEmpty && videoUrl == null)) {
    return null;
  }

  return XhsNoteSnapshot(
    title: title,
    content: content,
    imageUrls: imageUrls,
    comments: comments,
    commentCount: _intValueOrNull(commentsData?['commentCount']),
    videoUrl: videoUrl,
    posterUrl: posterUrl,
    authorName: authorName,
    authorAvatarUrl: authorAvatar.isEmpty ? null : authorAvatar,
    publishedAt: publishedAt,
  );
}

XhsNoteSnapshot? _parseRenderedNoteSnapshot({
  required String html,
  required String sourceUrl,
}) {
  final document = html_parser.parse(html);
  final carousel =
      document.querySelector('.image-gallery-container') ??
      document.querySelector('.onix-carousel');
  if (carousel == null) {
    return null;
  }

  final imageUrls = <String>{};
  for (final item in carousel.querySelectorAll('.onix-carousel-item')) {
    final image = item.querySelector('img');
    final rawUrl =
        image?.attributes['src'] ??
        image?.attributes['data-src'] ??
        image?.attributes['data-original'];
    final normalized = normalizeResourceUrl(rawUrl ?? '', sourceUrl);
    if (normalized.isNotEmpty && !_looksLikeAvatarUrl(normalized)) {
      imageUrls.add(normalized);
    }
  }

  final title =
      _textFromSelector(document, '.title') ??
      _titleFromHtml(html)?.replaceFirst(RegExp(r'\s*-\s*小红书$'), '');
  final jsonState = _decodeInitialState(html);
  final jsonNote = jsonState != null ? _findNoteMap(jsonState) : null;
  final content =
      (jsonNote != null ? _contentStringValue(jsonNote['desc']) : null) ??
      _contentFromSelector(document, '.note-content') ??
      _contentFromSelector(document, '.desc') ??
      _descriptionFromHtml(html);
  final authorName =
      _textFromSelector(document, '.author-wrapper .name') ??
      _textFromSelector(document, '.nickname') ??
      _authorNameFromLdJson(html);
  final authorAvatar = normalizeResourceUrl(
    document
            .querySelector('.author-wrapper img, .author-container img')
            ?.attributes['src'] ??
        _authorAvatarFromLdJson(html) ??
        '',
    sourceUrl,
  );
  final publishedAt =
      (jsonNote == null ? null : _extractPublishTimeFromNote(jsonNote)) ??
      extractPublishTimeFromHtml(html, sourceUrl);
  final commentsData = jsonState == null ? null : _findCommentsMap(jsonState);
  final comments = _extractComments(commentsData, sourceUrl);

  if (title == null || content == null || imageUrls.isEmpty) {
    return null;
  }

  return XhsNoteSnapshot(
    title: title,
    content: content,
    imageUrls: imageUrls.toList(growable: false),
    comments: comments,
    commentCount: _intValueOrNull(commentsData?['commentCount']),
    authorName: authorName,
    authorAvatarUrl: authorAvatar.isEmpty ? null : authorAvatar,
    publishedAt: publishedAt,
  );
}

Map<dynamic, dynamic>? _findCommentsMap(Object? value) {
  if (value is Map) {
    if (value['comments'] is List &&
        (value.containsKey('commentCount') ||
            value.containsKey('commentCountL1') ||
            value.containsKey('hasMore'))) {
      return value;
    }

    for (final child in value.values) {
      final comments = _findCommentsMap(child);
      if (comments != null) {
        return comments;
      }
    }
  }

  if (value is List) {
    for (final child in value) {
      final comments = _findCommentsMap(child);
      if (comments != null) {
        return comments;
      }
    }
  }

  return null;
}

List<ArticleComment> _extractComments(
  Map<dynamic, dynamic>? commentsData,
  String sourceUrl,
) {
  final rawComments = commentsData?['comments'];
  if (rawComments is! List) {
    return const [];
  }

  final comments = <ArticleComment>[];
  for (final rawComment in rawComments) {
    if (rawComment is! Map) {
      continue;
    }
    _appendComment(comments, rawComment, sourceUrl, depth: 0);
  }
  return comments.toList(growable: false);
}

void _appendComment(
  List<ArticleComment> comments,
  Map<dynamic, dynamic> rawComment,
  String sourceUrl, {
  required int depth,
}) {
  final content = _contentStringValue(rawComment['content']);
  if (content == null) {
    return;
  }

  final user = rawComment['user'] is Map ? rawComment['user'] as Map : null;
  final avatarUrl = normalizeResourceUrl(
    _stringValue(user?['image']) ?? _stringValue(user?['avatar']) ?? '',
    sourceUrl,
  );
  comments.add(
    ArticleComment(
      authorName:
          _stringValue(user?['nickname']) ??
          _stringValue(user?['nickName']) ??
          _stringValue(user?['name']) ??
          '小红书用户',
      content: content,
      authorAvatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
      publishedAt: parsePublishTimeValue(rawComment['time']),
      ipLocation: _stringValue(rawComment['ipLocation']),
      likeCount: _intValue(rawComment['likeCount']),
      depth: depth,
      imageUrls: _extractCommentImageUrls(rawComment, sourceUrl),
    ),
  );

  final subComments = rawComment['subComments'];
  if (subComments is! List) {
    return;
  }
  for (final subComment in subComments) {
    if (subComment is Map) {
      _appendComment(comments, subComment, sourceUrl, depth: depth + 1);
    }
  }
}

List<String> _extractCommentImageUrls(
  Map<dynamic, dynamic> rawComment,
  String sourceUrl,
) {
  final pictures = rawComment['pictures'];
  if (pictures is! List) {
    return const [];
  }

  final urls = <String>{};
  for (final picture in pictures) {
    if (picture is! Map) {
      continue;
    }
    final normalized = normalizeResourceUrl(
      _stringValue(picture['url']) ?? _stringValue(picture['originUrl']) ?? '',
      sourceUrl,
    );
    if (normalized.isNotEmpty) {
      urls.add(normalized);
    }
  }
  return urls.toList(growable: false);
}

DateTime? _extractPublishTimeFromNote(Map<dynamic, dynamic> note) {
  for (final key in [
    'time',
    'publishTime',
    'publishTimeMills',
    'publishTimeMillis',
    'lastUpdateTime',
    'timestamp',
  ]) {
    final parsed = parsePublishTimeValue(note[key]);
    if (parsed != null) {
      return parsed;
    }
  }
  return null;
}

Map<String, dynamic>? _decodeInitialState(String html) {
  const marker = 'window.__INITIAL_STATE__=';
  final start = html.indexOf(marker);
  if (start == -1) {
    return null;
  }

  final jsonStart = start + marker.length;
  final jsonEnd = html.indexOf('</script>', jsonStart);
  if (jsonEnd == -1) {
    return null;
  }

  // XHS embeds JavaScript (not strict JSON) — replace JS-only literals.
  final rawJson = html
      .substring(jsonStart, jsonEnd)
      .trim()
      .replaceAll(RegExp(r'\bundefined\b'), 'null')
      .replaceAll(RegExp(r'\bNaN\b'), 'null')
      .replaceAll(RegExp(r'\bInfinity\b'), 'null');
  try {
    final value = jsonDecode(rawJson);
    return value is Map<String, dynamic> ? value : null;
  } catch (_) {
    return null;
  }
}

Map<dynamic, dynamic>? _findNoteMap(Object? value) {
  if (value is Map) {
    if ((value['imageList'] is List || value['video'] is Map) &&
        value['user'] is Map &&
        value['desc'] is String) {
      return value;
    }

    for (final child in value.values) {
      final note = _findNoteMap(child);
      if (note != null) {
        return note;
      }
    }
  }

  if (value is List) {
    for (final child in value) {
      final note = _findNoteMap(child);
      if (note != null) {
        return note;
      }
    }
  }

  return null;
}

List<String> _extractImageUrlsFromNote(
  Map<dynamic, dynamic> note,
  String sourceUrl,
) {
  final urls = <String>{};
  final imageList = note['imageList'];
  if (imageList is! List) {
    return const [];
  }

  for (final image in imageList) {
    if (image is! Map) {
      continue;
    }

    final candidates = [
      _stringValue(image['url']),
      ..._urlsFromInfoList(image['infoList']),
    ];
    for (final candidate in candidates) {
      final normalized = normalizeResourceUrl(candidate ?? '', sourceUrl);
      if (normalized.isNotEmpty && !_looksLikeAvatarUrl(normalized)) {
        urls.add(normalized);
        break;
      }
    }
  }

  return urls.toList(growable: false);
}

String? _extractVideoUrlFromNote(Map<dynamic, dynamic> note, String sourceUrl) {
  final video = note['video'];
  if (video is! Map) {
    return null;
  }
  final media = video['media'];
  if (media is! Map) {
    return null;
  }
  final stream = media['stream'];
  if (stream is! Map) {
    return null;
  }

  for (final codec in ['h264', 'h265']) {
    final streams = stream[codec];
    if (streams is! List) {
      continue;
    }
    final candidates = streams.whereType<Map>().toList(growable: false)
      ..sort((a, b) => _intValue(b['size']).compareTo(_intValue(a['size'])));
    for (final candidate in candidates) {
      final rawUrl =
          _stringValue(candidate['masterUrl']) ??
          _firstBackupUrl(candidate['backupUrls']);
      final normalized = normalizeResourceUrl(rawUrl ?? '', sourceUrl);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
  }

  return null;
}

String? _firstBackupUrl(Object? backupUrls) {
  if (backupUrls is! List) {
    return null;
  }
  for (final value in backupUrls) {
    final url = _stringValue(value);
    if (url != null) {
      return url;
    }
  }
  return null;
}

String? _extractPosterUrlFromHtml(String html, String sourceUrl) {
  final document = html_parser.parse(html);
  final image =
      document.querySelector('#video_note_poster') ??
      document.querySelector('.video-container img') ??
      document.querySelector('.video-stage img');
  final rawUrl =
      image?.attributes['src'] ??
      image?.attributes['data-src'] ??
      image?.attributes['data-original'];
  final normalized = normalizeResourceUrl(rawUrl ?? '', sourceUrl);
  return normalized.isEmpty ? null : normalized;
}

List<String?> _urlsFromInfoList(Object? infoList) {
  if (infoList is! List) {
    return const [];
  }

  return infoList
      .whereType<Map>()
      .map((info) => _stringValue(info['url']))
      .toList(growable: false);
}

String? _stringValue(Object? value) {
  if (value is! String) {
    return null;
  }
  final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized.isEmpty ? null : normalized;
}

int _intValue(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? 0;
  }
  return 0;
}

int? _intValueOrNull(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

// Like _stringValue but preserves newlines — used for note body text.
// XHS stores line breaks as \n in the JSON desc field.
String? _contentStringValue(Object? value) {
  if (value is! String) return null;
  final normalized = value
      .replaceAll('\t', '') // XHS uses \t as blank-line filler — discard
      .replaceAll(RegExp(r'[ \u00A0]+'), ' ') // collapse runs of spaces/NBSP
      .replaceAll(RegExp(r' *\n *'), '\n') // trim spaces around newlines
      .replaceAll(RegExp(r'\n{3,}'), '\n\n') // cap consecutive blank lines
      .trim();
  return normalized.isEmpty ? null : normalized;
}

// Like _textFromSelector but preserves line breaks by converting <br> to \n.
String? _contentFromSelector(dom.Document document, String selector) {
  final element = document.querySelector(selector);
  if (element == null) return null;
  for (final br in element.querySelectorAll('br').toList()) {
    br.replaceWith(dom.Text('\n'));
  }
  final text = element.text
      .replaceAll('\t', '')
      .replaceAll(RegExp(r'[ \u00A0]+'), ' ')
      .replaceAll(RegExp(r' *\n *'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return text.isEmpty ? null : text;
}

String? _titleFromHtml(String html) {
  return RegExp(
    r'<title>(.*?)</title>',
    dotAll: true,
  ).firstMatch(html)?.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String? _descriptionFromHtml(String html) {
  return RegExp(
    r'<meta\s+name="description"\s+content="([^"]*)"',
    dotAll: true,
  ).firstMatch(html)?.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String? _textFromSelector(dom.Document document, String selector) {
  final text = document
      .querySelector(selector)
      ?.text
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text == null || text.isEmpty ? null : text;
}

String? _authorNameFromLdJson(String html) {
  final match = RegExp(
    r'"author"\s*:\s*\{.*?"name"\s*:\s*"([^"]+)"',
    dotAll: true,
  ).firstMatch(html);
  return match?.group(1);
}

String? _authorAvatarFromLdJson(String html) {
  final match = RegExp(
    r'"author"\s*:\s*\{.*?"image"\s*:\s*"([^"]+)"',
    dotAll: true,
  ).firstMatch(html);
  return match?.group(1);
}

bool _looksLikeAvatarUrl(String url) {
  return url.contains('sns-avatar') || url.contains('/avatar/');
}
