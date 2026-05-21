import 'package:path/path.dart' as p;

String articleDirectoryPathFromHtmlPath(String htmlPath) {
  return p.dirname(htmlPath);
}
