String? extractFirstUrl(String text) {
  final match = RegExp(r'https?://[^\s，。！？；：、）】》」』]+').firstMatch(text);
  if (match == null) {
    return null;
  }

  return match.group(0)?.replaceFirst(RegExp(r'[),.;!?]+$'), '');
}
