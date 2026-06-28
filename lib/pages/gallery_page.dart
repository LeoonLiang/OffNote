part of '../main.dart';

enum _GalleryFilterKind { all, uncategorized, category }

class _GalleryFilter {
  const _GalleryFilter._({
    required this.kind,
    required this.label,
    this.category,
  });

  const _GalleryFilter.all()
    : this._(kind: _GalleryFilterKind.all, label: '全部');

  const _GalleryFilter.uncategorized()
    : this._(kind: _GalleryFilterKind.uncategorized, label: '未分类');

  _GalleryFilter.category(SavedCategory category)
    : this._(
        kind: _GalleryFilterKind.category,
        label: category.name,
        category: category,
      );

  final _GalleryFilterKind kind;
  final String label;
  final SavedCategory? category;

  String get key => switch (kind) {
    _GalleryFilterKind.all => '__all__',
    _GalleryFilterKind.uncategorized => '__uncategorized__',
    _GalleryFilterKind.category => category!.id,
  };
}

class GalleryPage extends StatefulWidget {
  const GalleryPage({
    super.key,
    required this.store,
    required this.onChanged,
    required this.resourceQueue,
    this.actions = const [],
    this.refreshToken = 0,
  });

  final ArticleSnapshotStore store;
  final VoidCallback onChanged;
  final ResourceProcessingQueueController resourceQueue;
  final List<Widget> actions;
  final int refreshToken;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  final _articles = <SavedArticle>[];
  var _categories = <SavedCategory>[];
  _GalleryFilter _filter = const _GalleryFilter.all();
  ArticleSort _sort = ArticleSort.publishedNewest;
  Set<ArticleMediaType> _mediaTypes = <ArticleMediaType>{};
  Set<String> _tagIds = <String>{};
  bool _starredOnly = false;
  bool _isFilterExpanded = false;
  var _tags = <SavedTag>[];
  int _loadGeneration = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void didUpdateWidget(covariant GalleryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadFirstPage();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<SavedArticle>> _loadPage(
    _GalleryFilter filter,
    int offset, {
    required ArticleSort sort,
    required Set<ArticleMediaType> mediaTypes,
    required Set<String> tagIds,
    required bool starredOnly,
  }) {
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
      tagIds: tagIds,
    );
  }

  Future<void> _loadFirstPage() async {
    final generation = ++_loadGeneration;
    final filter = _filter;
    final sort = _sort;
    final mediaTypes = Set<ArticleMediaType>.of(_mediaTypes);
    final tagIds = Set<String>.of(_tagIds);
    final starredOnly = _starredOnly;
    setState(() {
      _isLoading = true;
      _hasMore = true;
      _errorText = null;
    });
    try {
      final metadata = await Future.wait([
        widget.store.listCategories(),
        widget.store.listTags(),
      ]);
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      final categories = metadata[0] as List<SavedCategory>;
      final tags = metadata[1] as List<SavedTag>;
      final availableTagIds = tags.map((tag) => tag.id).toSet();
      final effectiveTagIds = tagIds.where(availableTagIds.contains).toSet();
      final page = await _loadPage(
        filter,
        0,
        sort: sort,
        mediaTypes: mediaTypes,
        tagIds: effectiveTagIds,
        starredOnly: starredOnly,
      );
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _categories = categories;
        _tags = tags;
        _tagIds = effectiveTagIds;
        _articles
          ..clear()
          ..addAll(page);
        _hasMore = _articles.length == _pageSize;
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
    final tagIds = Set<String>.of(_tagIds);
    final starredOnly = _starredOnly;
    setState(() => _isLoading = true);
    try {
      final page = await _loadPage(
        filter,
        _articles.length,
        sort: sort,
        mediaTypes: mediaTypes,
        tagIds: tagIds,
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

  Future<void> _refresh() => _loadFirstPage();

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels < 520) {
      _loadMore();
    }
  }

  void _applyFilters({
    required _GalleryFilter filter,
    required bool starredOnly,
    required ArticleSort sort,
    required Set<ArticleMediaType> mediaTypes,
    required Set<String> tagIds,
  }) {
    setState(() {
      _filter = filter;
      _starredOnly = starredOnly;
      _sort = sort;
      _mediaTypes = mediaTypes;
      _tagIds = tagIds;
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
      tagIds: settings.tagIds,
    );
  }

  void _resetFilters() {
    _applyFilters(
      filter: const _GalleryFilter.all(),
      starredOnly: false,
      sort: ArticleSort.publishedNewest,
      mediaTypes: const {},
      tagIds: const {},
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

  List<GalleryItem> get _items => buildGalleryItems(_articles);

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('画廊', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: widget.actions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: _FilterBar(
                summary: _filterSummary,
                expanded: _isFilterExpanded,
                onTap: () {
                  setState(() => _isFilterExpanded = !_isFilterExpanded);
                },
              ),
            ),
            Expanded(
              child: _FilterOverlay(
                expanded: _isFilterExpanded,
                onDismiss: () => setState(() => _isFilterExpanded = false),
                panel: ArticleFilterPanel(
                  settings: _currentFilterSettings,
                  categories: _categories,
                  tags: _tags,
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
                    : items.isEmpty && _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                    ? const _EmptyMessage(
                        icon: Icons.photo_library_outlined,
                        text: '还没有可展示的图片或视频封面',
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: CustomScrollView(
                          key: const PageStorageKey<String>(
                            'offnote-gallery-scroll',
                          ),
                          controller: _scrollController,
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
                              sliver: SliverToBoxAdapter(
                                child: _MasonryGalleryGrid(
                                  items: items,
                                  onTap: _openArticle,
                                ),
                              ),
                            ),
                            if (_hasMore)
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ),
                          ],
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
        builder: (_) => ArticleDetailPage(
          article: article,
          store: widget.store,
          resourceQueue: widget.resourceQueue,
        ),
      ),
    );
    if (!result.needsListRefresh) {
      return;
    }
    widget.onChanged();
    await _refresh();
  }

  String get _filterSummary {
    final parts = <String>[_sortLabel(_sort)];
    if (_starredOnly) {
      parts.add('星标');
    }
    if (_filter.kind != _GalleryFilterKind.all) {
      parts.add(_filter.label);
    }
    if (_mediaTypes.length == 1) {
      parts.add(_mediaTypeLabel(_mediaTypes.single));
    }
    if (_tagIds.isNotEmpty) {
      final tagNames = _tags
          .where((tag) => _tagIds.contains(tag.id))
          .map((tag) => tag.name)
          .toList(growable: false);
      parts.add(tagNames.isEmpty ? '标签 ${_tagIds.length}' : tagNames.join('、'));
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
    tagIds: _tagIds,
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

class _MasonryGalleryGrid extends StatelessWidget {
  const _MasonryGalleryGrid({required this.items, required this.onTap});

  final List<GalleryItem> items;
  final ValueChanged<SavedArticle> onTap;

  @override
  Widget build(BuildContext context) {
    final columns = distributeGalleryItems(
      items,
      columnCount: 2,
      heightForIndex: _estimatedHeightForIndex,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var columnIndex = 0; columnIndex < columns.length; columnIndex++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: columnIndex == 0 ? 0 : 5,
                right: columnIndex == columns.length - 1 ? 0 : 5,
              ),
              child: Column(
                children: [
                  for (final item in columns[columnIndex]) ...[
                    _GalleryTile(
                      key: ValueKey(
                        'gallery-${item.article.id}-${item.mediaIndex}-${item.mediaPath}',
                      ),
                      item: item,
                      height: _estimatedHeightForItem(item),
                      onTap: () => onTap(item.article),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  double _estimatedHeightForIndex(int index) {
    return _estimatedHeightForItem(items[index]);
  }

  double _estimatedHeightForItem(GalleryItem item) {
    if (item.isVideo) {
      return 236;
    }
    const pattern = [248.0, 180.0, 220.0, 292.0, 204.0, 264.0];
    final seed = item.article.id.hashCode + item.mediaIndex;
    return pattern[seed.abs() % pattern.length];
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    super.key,
    required this.item,
    required this.height,
    required this.onTap,
  });

  final GalleryItem item;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: _accentSoft,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(item.mediaPath),
                  fit: BoxFit.cover,
                  cacheWidth: galleryPreviewCacheWidth(
                    180,
                    devicePixelRatio: devicePixelRatio,
                  ),
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: _accentSoft,
                    child: Center(
                      child: Icon(Icons.broken_image_outlined, color: _accent),
                    ),
                  ),
                ),
                if (item.isVideo)
                  const ColoredBox(
                    color: Color(0x33000000),
                    child: Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 44,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
