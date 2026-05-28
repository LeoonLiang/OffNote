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

  bool get _showsFolderFilter => widget.category == null;

  Future<List<SavedArticle>> _loadPage(_GalleryFilter filter, int offset) {
    final category = widget.category;
    if (category != null) {
      return widget.store.listArticlesByCategoryPage(
        category.id,
        limit: _pageSize,
        offset: offset,
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
        starredOnly: filter.kind == _GalleryFilterKind.starred,
      );
    }
    if (filter.kind == _GalleryFilterKind.starred) {
      return widget.store.listStarredArticlesPage(
        limit: _pageSize,
        offset: offset,
      );
    }
    if (filter.kind == _GalleryFilterKind.category) {
      return widget.store.listArticlesByCategoryPage(
        filter.category!.id,
        limit: _pageSize,
        offset: offset,
      );
    }
    if (filter.kind == _GalleryFilterKind.uncategorized) {
      return widget.store.listUncategorizedArticlesPage(
        limit: _pageSize,
        offset: offset,
      );
    }
    return widget.store.listArticlesPage(limit: _pageSize, offset: offset);
  }

  Future<void> _loadFirstPage() async {
    final generation = ++_loadGeneration;
    final filter = _filter;
    setState(() {
      _isLoading = true;
      _hasMore = true;
      _errorText = null;
      _selectedIds.clear();
    });
    try {
      final results = await Future.wait([
        _loadPage(filter, 0),
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
    setState(() => _isLoading = true);
    try {
      final page = await _loadPage(filter, _articles.length);
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

  void _selectFilter(_GalleryFilter filter) {
    if (_filter.key == filter.key) {
      return;
    }
    setState(() => _filter = filter);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _loadFirstPage();
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
    final filters = [
      const _GalleryFilter.all(),
      const _GalleryFilter.starred(),
      const _GalleryFilter.uncategorized(),
      ..._categories.map(_GalleryFilter.category),
    ];
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
            if (_showsFolderFilter && !_isSelecting)
              SizedBox(
                height: 46,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = filters[index];
                    final selected = filter.key == _filter.key;
                    return ChoiceChip(
                      selected: selected,
                      label: Text(filter.label),
                      avatar: switch (filter.kind) {
                        _GalleryFilterKind.starred => Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: selected ? Colors.white : _accent,
                        ),
                        _GalleryFilterKind.category => Icon(
                          Icons.folder_rounded,
                          size: 16,
                          color: selected
                              ? Colors.white
                              : Color(filter.category!.color),
                        ),
                        _ => null,
                      },
                      showCheckmark: false,
                      selectedColor: _accent,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : _ink,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide(
                        color: selected ? _accent : const Color(0xffdedfd7),
                      ),
                      onSelected: (_) => _selectFilter(filter),
                    );
                  },
                ),
              ),
            Expanded(
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
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index >= _articles.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(child: CircularProgressIndicator()),
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
}
