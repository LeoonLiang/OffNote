bool shouldLoadInWebView(Uri uri) {
  return uri.scheme == 'http' || uri.scheme == 'https';
}
