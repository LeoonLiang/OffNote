String? extractFirstUrl(String text) {
  final urls = extractUrls(text);
  return urls.isEmpty ? null : urls.first;
}

List<String> extractUrls(String text) {
  final seen = <String>{};
  final urls = <String>[];
  final matches = RegExp(r'https?://[^\s，。！？；：、）】》」』]+').allMatches(text);
  for (final match in matches) {
    final url = match.group(0)?.replaceFirst(RegExp(r'[),.;!?]+$'), '');
    if (url == null || url.isEmpty || !seen.add(url)) {
      continue;
    }
    urls.add(url);
  }
  return urls;
}
