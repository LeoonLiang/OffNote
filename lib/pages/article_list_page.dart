part of '../main.dart';

class ArticleListPage extends StatefulWidget {
  const ArticleListPage({
    super.key,
    required this.title,
    required this.store,
    required this.onChanged,
    this.category,
    this.searchable = false,
    this.actions = const [],
    this.refreshToken = 0,
  });

  final String title;
  final ArticleSnapshotStore store;
  final SavedCategory? category;
  final VoidCallback onChanged;
  final bool searchable;
  final List<Widget> actions;
  final int refreshToken;

  @override
  State<ArticleListPage> createState() => _ArticleListPageState();
}

class _ArticleListPageState extends State<ArticleListPage> {
  static const _pageSize = 20;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _selectedIds = <String>{};
  final _articles = <SavedArticle>[];
  _GalleryFilter _filter = const _GalleryFilter.all();
  ArticleSort _sort = ArticleSort.publishedNewest;
  Set<ArticleMediaType> _mediaTypes = <ArticleMediaType>{};
  bool _starredOnly = false;
  bool _isFilterExpanded = false;
  var _categories = <SavedCategory>[];
  var _categoryNamesById = <String, String>{};
  Timer? _searchDebounce;
  int _loadGeneration = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorText;

  bool get _isSelecting => _selectedIds.isNotEmpty;

  bool get _allVisibleSelected =>
      _articles.isNotEmpty &&
      _articles.every((article) => _selectedIds.contains(article.id));

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void didUpdateWidget(covariant ArticleListPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadFirstPage();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<SavedArticle>> _loadPage(
    _GalleryFilter filter,
    int offset, {
    required ArticleSort sort,
    required Set<ArticleMediaType> mediaTypes,
    required bool starredOnly,
  }) {
    final category = widget.category;
    if (category != null) {
      return widget.store.listArticlesByCategoryPage(
        category.id,
        limit: _pageSize,
        offset: offset,
        sort: sort,
        mediaTypes: mediaTypes,
      );
    }
    final query = _searchController.text.trim();
    if (widget.searchable && query.isNotEmpty) {
      return widget.store.searchArticlesPage(
        query,
        limit: _pageSize,
        offset: offset,
        categoryId: filter.kind == _GalleryFilterKind.category
            ? filter.category!.id
            : null,
        uncategorizedOnly: filter.kind == _GalleryFilterKind.uncategorized,
        starredOnly: starredOnly,
        sort: sort,
        mediaTypes: mediaTypes,
      );
    }
    return widget.store.searchArticlesPage(
      '',
      limit: _pageSize,
      offset: offset,
      categoryId: filter.kind == _GalleryFilterKind.category
          ? filter.category!.id
          : null,
      uncategorizedOnly: filter.kind == _GalleryFilterKind.uncategorized,
      starredOnly: starredOnly,
      sort: sort,
      mediaTypes: mediaTypes,
    );
  }

  Future<void> _loadFirstPage() async {
    final generation = ++_loadGeneration;
    final filter = _filter;
    final sort = _sort;
    final mediaTypes = Set<ArticleMediaType>.of(_mediaTypes);
    final starredOnly = _starredOnly;
    setState(() {
      _isLoading = true;
      _hasMore = true;
      _errorText = null;
      _selectedIds.clear();
    });
    try {
      final results = await Future.wait([
        _loadPage(
          filter,
          0,
          sort: sort,
          mediaTypes: mediaTypes,
          starredOnly: starredOnly,
        ),
        widget.store.listCategories(),
      ]);
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      final page = results[0] as List<SavedArticle>;
      final categories = results[1] as List<SavedCategory>;
      setState(() {
        _articles
          ..clear()
          ..addAll(page);
        _categoryNamesById = {
          for (final category in categories) category.id: category.name,
        };
        _categories = categories;
        _hasMore = page.length == _pageSize;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '$error';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) {
      return;
    }
    final generation = _loadGeneration;
    final filter = _filter;
    final sort = _sort;
    final mediaTypes = Set<ArticleMediaType>.of(_mediaTypes);
    final starredOnly = _starredOnly;
    setState(() => _isLoading = true);
    try {
      final page = await _loadPage(
        filter,
        _articles.length,
        sort: sort,
        mediaTypes: mediaTypes,
        starredOnly: starredOnly,
      );
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _articles.addAll(page);
        _hasMore = page.length == _pageSize;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '$error';
        _isLoading = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadFirstPage();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels < 320) {
      _loadMore();
    }
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), _loadFirstPage);
  }

  void _applyFilters({
    required _GalleryFilter filter,
    required bool starredOnly,
    required ArticleSort sort,
    required Set<ArticleMediaType> mediaTypes,
  }) {
    setState(() {
      _filter = filter;
      _starredOnly = starredOnly;
      _sort = sort;
      _mediaTypes = mediaTypes;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _loadFirstPage();
  }

  void _applyFilterSettings(ArticleFilterSettings settings) {
    _applyFilters(
      filter: _filterFromSettings(settings),
      starredOnly: settings.starredOnly,
      sort: settings.sort,
      mediaTypes: settings.mediaTypes,
    );
  }

  void _resetFilters() {
    _applyFilters(
      filter: const _GalleryFilter.all(),
      starredOnly: false,
      sort: ArticleSort.publishedNewest,
      mediaTypes: const {},
    );
  }

  _GalleryFilter _filterFromSettings(ArticleFilterSettings settings) {
    if (settings.categoryId != null) {
      for (final category in _categories) {
        if (category.id == settings.categoryId) {
          return _GalleryFilter.category(category);
        }
      }
    }
    if (settings.uncategorizedOnly) {
      return const _GalleryFilter.uncategorized();
    }
    return const _GalleryFilter.all();
  }

  void _toggleSelection(SavedArticle article) {
    setState(() {
      if (!_selectedIds.add(article.id)) {
        _selectedIds.remove(article.id);
      }
    });
  }

  void _clearSelection() {
    setState(_selectedIds.clear);
  }

  void _toggleSelectAllVisible() {
    final next = toggleVisibleSelection(
      selectedIds: _selectedIds,
      visibleIds: _articles.map((article) => article.id),
    );
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        leading: _isSelecting
            ? IconButton(
                onPressed: _clearSelection,
                tooltip: '取消选择',
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        title: Text(
          _isSelecting ? '已选择 ${_selectedIds.length} 篇' : widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: _isSelecting
            ? [
                IconButton(
                  onPressed: _articles.isEmpty ? null : _toggleSelectAllVisible,
                  tooltip: _allVisibleSelected ? '取消全选' : '全选',
                  icon: Icon(
                    _allVisibleSelected
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                  ),
                ),
                IconButton(
                  onPressed: () => _updateSelectedStarred(true),
                  tooltip: '星标',
                  icon: const Icon(Icons.star_rounded),
                  color: const Color(0xffffb300),
                ),
                IconButton(
                  onPressed: () => _updateSelectedStarred(false),
                  tooltip: '取消星标',
                  icon: const Icon(Icons.star_border_rounded),
                ),
                IconButton(
                  onPressed: _assignSelectedCategory,
                  tooltip: '设置分类',
                  icon: const Icon(Icons.sell_outlined),
                ),
                IconButton(
                  onPressed: _shareSelectedLinks,
                  tooltip: '分享链接',
                  icon: const Icon(LucideIcons.share2),
                ),
                IconButton(
                  onPressed: _confirmDeleteSelected,
                  tooltip: '删除',
                  icon: const Icon(LucideIcons.trash2),
                ),
              ]
            : widget.actions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.searchable && !_isSelecting)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: ShadInput(
                  controller: _searchController,
                  placeholder: const Text('搜索标题、正文或备注'),
                  leading: const Icon(LucideIcons.search, size: 18),
                  onChanged: _onSearchChanged,
                ),
              ),
            if (!_isSelecting)
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: _FilterBar(
                      summary: _filterSummary,
                      expanded: _isFilterExpanded,
                      onTap: () {
                        setState(() => _isFilterExpanded = !_isFilterExpanded);
                      },
                    ),
                  ),
                ],
              ),
            Expanded(
              child: _FilterOverlay(
                expanded: _isFilterExpanded && !_isSelecting,
                onDismiss: () => setState(() => _isFilterExpanded = false),
                panel: ArticleFilterPanel(
                  settings: _currentFilterSettings,
                  categories: _categories,
                  showCategoryFilters: widget.category == null,
                  onChanged: _applyFilterSettings,
                  onReset: _resetFilters,
                  onCollapse: () {
                    setState(() => _isFilterExpanded = false);
                  },
                ),
                child: _errorText != null
                    ? _EmptyMessage(
                        icon: Icons.error_outline_rounded,
                        text: '加载失败：$_errorText',
                      )
                    : _articles.isEmpty && _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _articles.isEmpty
                    ? hasQuery
                          ? const _EmptyMessage(
                              icon: Icons.search_off_rounded,
                              text: '没有找到相关内容',
                            )
                          : const _EmptyLibrary()
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                          itemCount: _articles.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index >= _articles.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final article = _articles[index];
                            return _ArticleTile(
                              article: article,
                              categoryLabel: articleCategoryLabel(
                                article,
                                _categoryNamesById,
                              ),
                              selected: _selectedIds.contains(article.id),
                              selectionMode: _isSelecting,
                              onTap: () => _isSelecting
                                  ? _toggleSelection(article)
                                  : _openArticle(article),
                              onLongPress: () => _toggleSelection(article),
                              onDelete: _isSelecting
                                  ? null
                                  : () => _confirmDelete(article),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openArticle(SavedArticle article) async {
    final result = await Navigator.of(context).push<ArticleDetailResult>(
      MaterialPageRoute<ArticleDetailResult>(
        builder: (_) =>
            ArticleDetailPage(article: article, store: widget.store),
      ),
    );
    if (!result.needsListRefresh) {
      return;
    }
    widget.onChanged();
    if (widget.category != null) {
      await _refresh();
    }
  }

  Future<void> _confirmDelete(SavedArticle article) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('删除离线文章'),
        description: Text('确定删除「${article.title}」吗？本地 HTML 和图片也会一起删除。'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await widget.store.deleteArticle(article);
    widget.onChanged();
    await _refresh();
  }

  Future<void> _confirmDeleteSelected() async {
    final selected = _selectedArticles();
    if (selected.isEmpty) {
      return;
    }
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: Text('删除 ${selected.length} 篇文章'),
        description: const Text('本地 HTML、图片和视频文件也会一起删除。'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await widget.store.deleteArticles(selected);
    widget.onChanged();
    await _refresh();
  }

  Future<void> _assignSelectedCategory() async {
    final selected = _selectedArticles();
    if (selected.isEmpty) {
      return;
    }
    final categoryId = await _pickCategory();
    if (categoryId == null) {
      return;
    }
    final normalized = categoryId == '__offnote_uncategorized__'
        ? null
        : categoryId;
    for (final article in selected) {
      await widget.store.assignArticleCategory(article.id, normalized);
    }
    widget.onChanged();
    await _refresh();
  }

  Future<void> _updateSelectedStarred(bool isStarred) async {
    final selected = _selectedArticles();
    if (selected.isEmpty) {
      return;
    }
    for (final article in selected) {
      await widget.store.updateArticleStarred(article.id, isStarred);
    }
    widget.onChanged();
    await _refresh();
  }

  Future<void> _shareSelectedLinks() async {
    final urls = selectedArticleShareUrls(_selectedArticles());
    if (urls.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('选中的文章没有可分享的小红书链接')));
      return;
    }
    final text = formatSelectedArticleLinks(urls);
    try {
      await SharePlus.instance.share(ShareParams(text: text));
      if (!mounted) {
        return;
      }
      _clearSelection();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('分享失败：$error')));
    }
  }

  Future<String?> _pickCategory() async {
    final categories = await widget.store.listCategories();
    if (!mounted) {
      return null;
    }
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                '移动到分类',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inbox_outlined, color: _accent),
              title: const Text('未分类'),
              onTap: () =>
                  Navigator.of(context).pop('__offnote_uncategorized__'),
            ),
            ...categories.map(
              (category) => ListTile(
                leading: Icon(
                  Icons.folder_rounded,
                  color: Color(category.color),
                ),
                title: Text(category.name),
                onTap: () => Navigator.of(context).pop(category.id),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SavedArticle> _selectedArticles() {
    return _articles
        .where((article) => _selectedIds.contains(article.id))
        .toList(growable: false);
  }

  String get _filterSummary {
    final parts = <String>[_sortLabel(_sort)];
    if (_starredOnly) {
      parts.add('星标');
    }
    if (widget.category == null && _filter.kind != _GalleryFilterKind.all) {
      parts.add(_filter.label);
    }
    if (_mediaTypes.length == 1) {
      parts.add(_mediaTypeLabel(_mediaTypes.single));
    }
    return parts.join(' · ');
  }

  ArticleFilterSettings get _currentFilterSettings => ArticleFilterSettings(
    sort: _sort,
    starredOnly: _starredOnly,
    uncategorizedOnly: _filter.kind == _GalleryFilterKind.uncategorized,
    categoryId: _filter.kind == _GalleryFilterKind.category
        ? _filter.category!.id
        : null,
    mediaTypes: _mediaTypes,
  );

  String _sortLabel(ArticleSort sort) {
    return switch (sort) {
      ArticleSort.publishedNewest => '发布时间',
      ArticleSort.savedNewest => '最近保存',
      ArticleSort.savedOldest => '最早保存',
    };
  }

  String _mediaTypeLabel(ArticleMediaType mediaType) {
    return switch (mediaType) {
      ArticleMediaType.image => '图文',
      ArticleMediaType.video => '视频',
    };
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.summary,
    required this.expanded,
    required this.onTap,
  });

  final String summary;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xffdedfd7)),
          ),
          child: Row(
            children: [
              const Text(
                '全部',
                style: TextStyle(
                  color: _ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                expanded ? Icons.keyboard_arrow_up_rounded : Icons.tune_rounded,
                color: _muted,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterOverlay extends StatelessWidget {
  const _FilterOverlay({
    required this.expanded,
    required this.panel,
    required this.child,
    required this.onDismiss,
  });

  final bool expanded;
  final Widget panel;
  final Widget child;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (expanded)
          Positioned.fill(
            child: Column(
              children: [
                Material(color: Colors.transparent, child: panel),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDismiss,
                    child: const ColoredBox(color: Color(0x33000000)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
