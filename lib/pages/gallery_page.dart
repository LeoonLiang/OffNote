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
    this.actions = const [],
  });

  final ArticleSnapshotStore store;
  final VoidCallback onChanged;
  final List<Widget> actions;

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  final _articles = <SavedArticle>[];
  var _categories = <SavedCategory>[];
  _GalleryFilter _filter = const _GalleryFilter.all();
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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<SavedArticle>> _loadPage(_GalleryFilter filter, int offset) {
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
    });
    try {
      final results = await Future.wait([
        widget.store.listCategories(),
        _loadPage(filter, 0),
      ]);
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _categories = results[0] as List<SavedCategory>;
        _articles
          ..clear()
          ..addAll(results[1] as List<SavedArticle>);
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

  List<GalleryItem> get _items => buildGalleryItems(_articles);

  @override
  Widget build(BuildContext context) {
    final filters = [
      const _GalleryFilter.all(),
      const _GalleryFilter.uncategorized(),
      ..._categories.map(_GalleryFilter.category),
    ];
    final items = _items;

    return Scaffold(
      appBar: AppBar(
        title: const Text('画廊', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: widget.actions,
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                scrollDirection: Axis.horizontal,
                itemCount: filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filter = filters[index];
                  final selected = filter.key == _filter.key;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(filter.label),
                    avatar: filter.kind == _GalleryFilterKind.category
                        ? Icon(
                            Icons.folder_rounded,
                            size: 16,
                            color: selected
                                ? Colors.white
                                : Color(filter.category!.color),
                          )
                        : null,
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
    required this.item,
    required this.height,
    required this.onTap,
  });

  final GalleryItem item;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
