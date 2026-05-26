enum ArticleDetailResult { unchanged, changed }

extension ArticleDetailResultRefresh on ArticleDetailResult? {
  bool get needsListRefresh => this == ArticleDetailResult.changed;
}
