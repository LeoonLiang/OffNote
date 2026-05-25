import 'saved_article.dart';

String? articleCategoryLabel(
  SavedArticle article,
  Map<String, String> categoryNamesById,
) {
  final categoryId = article.categoryId;
  if (categoryId == null) {
    return null;
  }
  return categoryNamesById[categoryId] ?? '已分类';
}
