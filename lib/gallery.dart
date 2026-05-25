import 'saved_article.dart';

class GalleryItem {
  const GalleryItem({
    required this.article,
    required this.mediaPath,
    required this.mediaIndex,
    required this.isVideo,
  });

  final SavedArticle article;
  final String mediaPath;
  final int mediaIndex;
  final bool isVideo;
}

List<GalleryItem> buildGalleryItems(
  Iterable<SavedArticle> articles, {
  String? categoryId,
  bool uncategorizedOnly = false,
}) {
  final items = <GalleryItem>[];
  for (final article in articles) {
    if (categoryId != null && article.categoryId != categoryId) {
      continue;
    }
    if (uncategorizedOnly && article.categoryId != null) {
      continue;
    }

    if (article.mediaType == ArticleMediaType.video) {
      final coverPath = article.coverPath;
      if (coverPath != null && coverPath.isNotEmpty) {
        items.add(
          GalleryItem(
            article: article,
            mediaPath: coverPath,
            mediaIndex: 0,
            isVideo: true,
          ),
        );
      }
      continue;
    }

    final paths = article.imagePaths.isNotEmpty
        ? article.imagePaths
        : [if (article.coverPath != null) article.coverPath!];
    for (var index = 0; index < paths.length; index++) {
      items.add(
        GalleryItem(
          article: article,
          mediaPath: paths[index],
          mediaIndex: index,
          isVideo: false,
        ),
      );
    }
  }
  return items;
}

typedef GalleryItemHeightForIndex = double Function(int index);

List<List<GalleryItem>> distributeGalleryItems(
  List<GalleryItem> items, {
  required int columnCount,
  required GalleryItemHeightForIndex heightForIndex,
}) {
  final columns = List.generate(columnCount, (_) => <GalleryItem>[]);
  final heights = List.filled(columnCount, 0.0);
  for (var index = 0; index < items.length; index++) {
    var shortestColumn = 0;
    for (var column = 1; column < columnCount; column++) {
      if (heights[column] < heights[shortestColumn]) {
        shortestColumn = column;
      }
    }
    columns[shortestColumn].add(items[index]);
    heights[shortestColumn] += heightForIndex(index);
  }
  return columns;
}
