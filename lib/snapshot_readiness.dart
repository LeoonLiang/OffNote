import 'dart:convert';

const snapshotReadyProbeScript = '''
(function () {
  var initialStateText = '';
  try {
    initialStateText = window.__INITIAL_STATE__
      ? JSON.stringify(window.__INITIAL_STATE__)
      : '';
  } catch (e) {
    initialStateText = '';
  }
  var hasInitialState = !!(
    initialStateText &&
    initialStateText.indexOf('"imageList"') !== -1 &&
    initialStateText.indexOf('"desc"') !== -1
  );
  var hasRenderedNote = !!(
    document.querySelector('.image-gallery-container img') &&
    (
      document.querySelector('.note-content') ||
      document.querySelector('[class*="note-content"]') ||
      document.querySelector('[class*="desc"]')
    )
  );
  var hasGenericArticle = !!(
    document.querySelector('article, main') &&
    document.querySelector('img')
  );
  return hasInitialState || hasRenderedNote || hasGenericArticle;
})()
''';

bool decodeSnapshotReadinessResult(Object? result) {
  if (result is bool) {
    return result;
  }
  if (result is String) {
    final trimmed = result.trim();
    if (trimmed == 'true') {
      return true;
    }
    if (trimmed == 'false') {
      return false;
    }
    try {
      final decoded = jsonDecode(trimmed);
      return decoded == true || decoded == 'true';
    } catch (_) {
      return false;
    }
  }
  return false;
}
