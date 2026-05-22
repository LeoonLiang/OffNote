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
  });

  final String title;
  final ArticleSnapshotStore store;
  final SavedCategory? category;
  final VoidCallback onChanged;
  final bool searchable;
  final List<Widget> actions;

  @override
  State<ArticleListPage> createState() => _ArticleListPageState();
}

class _ArticleListPageState extends State<ArticleListPage> {
  static const _pageSize = 20;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _selectedIds = <String>{};
  final _articles = <SavedArticle>[];
  Timer? _searchDebounce;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorText;

  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<SavedArticle>> _loadPage(int offset) {
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
      );
    }
    return widget.store.listArticlesPage(limit: _pageSize, offset: offset);
  }

  Future<void> _loadFirstPage() async {
    if (_isLoading) {
      return;
    }
    setState(() {
      _isLoading = true;
      _hasMore = true;
      _errorText = null;
      _selectedIds.clear();
    });
    try {
      final page = await _loadPage(0);
      if (!mounted) {
        return;
      }
      setState(() {
        _articles
          ..clear()
          ..addAll(page);
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
    setState(() => _isLoading = true);
    try {
      final page = await _loadPage(_articles.length);
      if (!mounted) {
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
                  onPressed: _assignSelectedCategory,
                  tooltip: '设置分类',
                  icon: const Icon(Icons.sell_outlined),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: ShadInput(
                  controller: _searchController,
                  placeholder: const Text('搜索标题、正文或备注'),
                  leading: const Icon(LucideIcons.search, size: 18),
                  onChanged: _onSearchChanged,
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArticleDetailPage(
          article: article,
          store: widget.store,
          onChanged: () {
            widget.onChanged();
            _refresh();
          },
        ),
      ),
    );
    await _refresh();
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
