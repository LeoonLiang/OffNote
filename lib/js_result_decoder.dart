import 'dart:convert';

String decodeJavaScriptStringResult(Object result) {
  final text = result.toString();
  if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
    final decoded = jsonDecode(text);
    if (decoded is String) {
      return decoded;
    }
  }
  return text;
}
