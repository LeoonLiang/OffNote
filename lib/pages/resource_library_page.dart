part of '../main.dart';

enum _UploadResourceChoice { image, video }

class ResourceLibraryPage extends StatefulWidget {
  const ResourceLibraryPage({
    super.key,
    required this.store,
    required this.onChanged,
    required this.resourceQueue,
    this.filePicker = const ResourceFilePicker(),
    this.actions = const [],
    this.refreshToken = 0,
  });

  final ArticleSnapshotStore store;
  final VoidCallback onChanged;
  final ResourceProcessingQueueController resourceQueue;
  final ResourceFilePicker filePicker;
  final List<Widget> actions;
  final int refreshToken;

  @override
  State<ResourceLibraryPage> createState() => _ResourceLibraryPageState();
}

class _ResourceLibraryPageState extends State<ResourceLibraryPage> {
  static const _pageSize = 30;

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _resources = <SavedResource>[];
  Timer? _processingRefreshTimer;
  var _tags = <SavedTag>[];
  var _tagsByResource = <String, List<SavedTag>>{};
  Set<SavedResourceType> _types = const {};
  Set<String> _tagIds = const {};
  bool _isFilterExpanded = false;
  bool _isLoading = false;
  bool _isUploading = false;
  bool _hasMore = true;
  int _loadGeneration = 0;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    widget.resourceQueue.addListener(_onResourceQueueChanged);
    _loadFirstPage();
  }

  @override
  void didUpdateWidget(covariant ResourceLibraryPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshToken != oldWidget.refreshToken) {
      _loadFirstPage();
    }
    if (widget.resourceQueue != oldWidget.resourceQueue) {
      oldWidget.resourceQueue.removeListener(_onResourceQueueChanged);
      widget.resourceQueue.addListener(_onResourceQueueChanged);
    }
  }

  @override
  void dispose() {
    _processingRefreshTimer?.cancel();
    widget.resourceQueue.removeListener(_onResourceQueueChanged);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onResourceQueueChanged() {
    if (mounted && !_isLoading) {
      _loadFirstPage();
    }
  }

  Future<void> _loadFirstPage() async {
    final generation = ++_loadGeneration;
    final query = _searchController.text;
    final types = Set<SavedResourceType>.of(_types);
    final tagIds = Set<String>.of(_tagIds);
    setState(() {
      _isLoading = true;
      _hasMore = true;
      _errorText = null;
    });
    try {
      final tags = await widget.store.listTags();
      final availableTagIds = tags.map((tag) => tag.id).toSet();
      final effectiveTagIds = tagIds.where(availableTagIds.contains).toSet();
      final page = await widget.store.searchResourcesPage(
        query,
        limit: _pageSize,
        types: types,
        tagIds: effectiveTagIds,
      );
      final tagsByResource = await widget.store.listTagsByResourceIds(
        page.map((resource) => resource.id),
      );
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _tags = tags;
        _tagIds = effectiveTagIds;
        _resources
          ..clear()
          ..addAll(page);
        _tagsByResource = tagsByResource;
        _hasMore = page.length == _pageSize;
        _isLoading = false;
      });
      _syncProcessingRefreshTimer();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '$error';
        _isLoading = false;
      });
      _syncProcessingRefreshTimer();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) {
      return;
    }
    final generation = _loadGeneration;
    setState(() => _isLoading = true);
    try {
      final page = await widget.store.searchResourcesPage(
        _searchController.text,
        limit: _pageSize,
        offset: _resources.length,
        types: _types,
        tagIds: _tagIds,
      );
      final tagsByResource = await widget.store.listTagsByResourceIds(
        page.map((resource) => resource.id),
      );
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _resources.addAll(page);
        _tagsByResource = {..._tagsByResource, ...tagsByResource};
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

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent - position.pixels < 520) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('素材库', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _isUploading ? null : _showUploadSheet,
            tooltip: '上传素材',
            icon: const Icon(Icons.upload_file_rounded),
          ),
          ...widget.actions,
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '搜索素材标题、备注',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _loadFirstPage();
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => _loadFirstPage(),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                panel: _ResourceFilterPanel(
                  types: _types,
                  tagIds: _tagIds,
                  tags: _tags,
                  onChanged: (types, tagIds) {
                    setState(() {
                      _types = types;
                      _tagIds = tagIds;
                    });
                    _loadFirstPage();
                  },
                  onReset: () {
                    setState(() {
                      _types = const {};
                      _tagIds = const {};
                    });
                    _loadFirstPage();
                  },
                  onCollapse: () {
                    setState(() => _isFilterExpanded = false);
                  },
                ),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_errorText != null) {
      return _EmptyMessage(
        icon: Icons.error_outline_rounded,
        text: '加载失败：$_errorText',
      );
    }
    if (_resources.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_resources.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadFirstPage,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: const _EmptyMessage(
                icon: Icons.bookmarks_outlined,
                text: '还没有收藏或上传的图片、视频',
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadFirstPage,
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 28),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemCount: _resources.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _resources.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final resource = _resources[index];
          return _ResourceTile(
            resource: resource,
            tags: _tagsByResource[resource.id] ?? const [],
            onTap: () => _openResource(resource),
            onEditTags: () => _editResourceTags(resource),
            onRetry: () => _retryResource(resource),
            onDelete: () => _deleteResource(resource),
          );
        },
      ),
    );
  }

  Future<void> _openResource(SavedResource resource) async {
    if (resource.status == SavedResourceStatus.processing) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('片段还在后台截取中')));
      return;
    }
    if (resource.status == SavedResourceStatus.failed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(resource.error ?? '片段截取失败')));
      return;
    }
    if (resource.type == SavedResourceType.image) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _ResourceImagePreview(resource: resource),
        ),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ResourceVideoPreview(
          resource: resource,
          onOpenSource: savedResourceHasSourceArticle(resource)
              ? () => _openSourceArticle(resource)
              : null,
        ),
      ),
    );
  }

  Future<void> _openSourceArticle(SavedResource resource) async {
    final article = await widget.store.getArticle(resource.articleId);
    if (!mounted) {
      return;
    }
    if (article == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('来源笔记已不存在')));
      return;
    }
    await Navigator.of(context).push<ArticleDetailResult>(
      MaterialPageRoute<ArticleDetailResult>(
        builder: (_) => ArticleDetailPage(
          article: article,
          store: widget.store,
          resourceQueue: widget.resourceQueue,
          initialVideoPosition: resource.start,
        ),
      ),
    );
  }

  Future<void> _editResourceTags(SavedResource resource) async {
    final allTags = await widget.store.listTags();
    final currentTags = await widget.store.listResourceTags(resource.id);
    if (!mounted) {
      return;
    }
    final result = await showModalBottomSheet<TagEditResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => TagEditorSheet(
        initialTags: allTags,
        initialSelectedIds: currentTags.map((tag) => tag.id).toSet(),
        accentColor: _accent,
        onCreateTag: (name) async {
          final color =
              _folderColors[DateTime.now().millisecond % _folderColors.length];
          return widget.store.createTag(name, color);
        },
      ),
    );
    if (result == null) {
      return;
    }
    await widget.store.setResourceTags(resource.id, result.selectedIds);
    await _loadFirstPage();
    widget.onChanged();
  }

  Future<void> _deleteResource(SavedResource resource) async {
    await widget.store.deleteResource(resource);
    await _loadFirstPage();
    widget.onChanged();
  }

  Future<void> _showUploadSheet() async {
    final choice = await showModalBottomSheet<_UploadResourceChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('上传图片'),
              onTap: () {
                Navigator.of(context).pop(_UploadResourceChoice.image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.movie_outlined),
              title: const Text('上传视频'),
              onTap: () {
                Navigator.of(context).pop(_UploadResourceChoice.video);
              },
            ),
          ],
        ),
      ),
    );
    if (choice == null) {
      return;
    }
    await _uploadResource(choice);
  }

  Future<void> _uploadResource(_UploadResourceChoice choice) async {
    setState(() => _isUploading = true);
    try {
      final path = switch (choice) {
        _UploadResourceChoice.image =>
          await widget.filePicker.pickImageResourceFilePath(),
        _UploadResourceChoice.video =>
          await widget.filePicker.pickVideoResourceFilePath(),
      };
      if (path == null || path.trim().isEmpty) {
        return;
      }
      switch (choice) {
        case _UploadResourceChoice.image:
          await widget.store.importImageResource(path);
        case _UploadResourceChoice.video:
          await widget.store.importVideoResource(path);
      }
      await _loadFirstPage();
      widget.onChanged();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('素材已上传')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上传失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _retryResource(SavedResource resource) {
    if (resource.type != SavedResourceType.videoClip ||
        resource.status != SavedResourceStatus.failed ||
        resource.originalSourcePath == null ||
        resource.start == null ||
        resource.end == null) {
      return;
    }
    widget.resourceQueue.retryResource(
      resource,
      (_tagsByResource[resource.id] ?? const []).map((tag) => tag.id).toSet(),
    );
  }

  void _syncProcessingRefreshTimer() {
    final hasProcessing = _resources.any(
      (resource) => resource.status == SavedResourceStatus.processing,
    );
    if (!hasProcessing) {
      _processingRefreshTimer?.cancel();
      _processingRefreshTimer = null;
      return;
    }
    _processingRefreshTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted && !_isLoading) {
        _loadFirstPage();
      }
    });
  }

  String get _filterSummary {
    final parts = <String>[];
    if (_types.isEmpty) {
      parts.add('全部类型');
    } else {
      parts.addAll(_types.map(_resourceTypeLabel));
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
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.resource,
    required this.tags,
    required this.onTap,
    required this.onEditTags,
    required this.onRetry,
    required this.onDelete,
  });

  final SavedResource resource;
  final List<SavedTag> tags;
  final VoidCallback onTap;
  final VoidCallback onEditTags;
  final VoidCallback onRetry;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final previewPath = resource.previewPath ?? resource.sourcePath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (previewPath.isNotEmpty)
                      Image.file(
                        File(previewPath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const ColoredBox(
                          color: _accentSoft,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      )
                    else
                      const ColoredBox(
                        color: Colors.black,
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    if (resource.type == SavedResourceType.videoClip)
                      ColoredBox(
                        color: Color(0x33000000),
                        child: Center(
                          child: Icon(
                            resource.status == SavedResourceStatus.processing
                                ? Icons.hourglass_top_rounded
                                : resource.status == SavedResourceStatus.failed
                                ? Icons.error_outline_rounded
                                : Icons.movie_filter_rounded,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            resource.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (resource.type == SavedResourceType.videoClip &&
                              resource.start != null &&
                              resource.end != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                '${formatVideoMarkerPosition(resource.start!)} - ${formatVideoMarkerPosition(resource.end!)}',
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (resource.status != SavedResourceStatus.ready)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                resource.status ==
                                        SavedResourceStatus.processing
                                    ? '截取中'
                                    : '截取失败',
                                style: TextStyle(
                                  color:
                                      resource.status ==
                                          SavedResourceStatus.processing
                                      ? _muted
                                      : const Color(0xffb42318),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (tags.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                tags.map((tag) => '#${tag.name}').join(' '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _accent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: '更多',
                      onSelected: (value) {
                        if (value == 'tags') {
                          onEditTags();
                        } else if (value == 'retry') {
                          onRetry();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'tags', child: Text('编辑标签')),
                        if (resource.type == SavedResourceType.videoClip &&
                            resource.status == SavedResourceStatus.failed)
                          const PopupMenuItem(
                            value: 'retry',
                            child: Text('重试截取'),
                          ),
                        const PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceImagePreview extends StatelessWidget {
  const _ResourceImagePreview({required this.resource});

  final SavedResource resource;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(resource.title, maxLines: 1),
      ),
      body: Center(
        child: PhotoView(
          imageProvider: FileImage(File(resource.sourcePath)),
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
        ),
      ),
    );
  }
}

class _ResourceVideoPreview extends StatelessWidget {
  const _ResourceVideoPreview({
    required this.resource,
    required this.onOpenSource,
  });

  final SavedResource resource;
  final VoidCallback? onOpenSource;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(resource.title, maxLines: 1),
        actions: [
          if (onOpenSource != null)
            IconButton(
              onPressed: onOpenSource,
              tooltip: '打开来源',
              icon: const Icon(Icons.call_made_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: OffNoteVideoPlayer(
          source: OffNoteVideoSource(
            videoUri: File(resource.sourcePath).uri.toString(),
            posterUri: resource.previewPath == null
                ? null
                : File(resource.previewPath!).uri.toString(),
          ),
        ),
      ),
    );
  }
}

class _ResourceFilterPanel extends StatelessWidget {
  const _ResourceFilterPanel({
    required this.types,
    required this.tagIds,
    required this.tags,
    required this.onChanged,
    required this.onReset,
    required this.onCollapse,
  });

  final Set<SavedResourceType> types;
  final Set<String> tagIds;
  final List<SavedTag> tags;
  final void Function(Set<SavedResourceType> types, Set<String> tagIds)
  onChanged;
  final VoidCallback onReset;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xffeeeeee))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ResourceFilterSection(
                  title: '素材类型',
                  children: [
                    _ResourceOptionChip(
                      label: '不限',
                      selected: types.isEmpty,
                      onSelected: () => onChanged(const {}, tagIds),
                    ),
                    for (final type in SavedResourceType.values)
                      _ResourceOptionChip(
                        label: _resourceTypeLabel(type),
                        selected: types.contains(type),
                        onSelected: () => _toggleType(type),
                      ),
                  ],
                ),
                if (tags.isNotEmpty)
                  _ResourceFilterSection(
                    title: '标签',
                    children: [
                      _ResourceOptionChip(
                        label: '不限',
                        selected: tagIds.isEmpty,
                        onSelected: () => onChanged(types, const {}),
                      ),
                      for (final tag in tags)
                        _ResourceOptionChip(
                          label: tag.name,
                          selected: tagIds.contains(tag.id),
                          onSelected: () => _toggleTag(tag.id),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xffeeeeee)),
          SizedBox(
            height: 56,
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重置'),
                  ),
                ),
                const VerticalDivider(width: 1, color: Color(0xffeeeeee)),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onCollapse,
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    label: const Text('收起'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleType(SavedResourceType type) {
    final next = Set<SavedResourceType>.of(types);
    if (!next.add(type)) {
      next.remove(type);
    }
    if (next.length == SavedResourceType.values.length) {
      next.clear();
    }
    onChanged(next, tagIds);
  }

  void _toggleTag(String tagId) {
    final next = Set<String>.of(tagIds);
    if (!next.add(tagId)) {
      next.remove(tagId);
    }
    onChanged(types, next);
  }
}

class _ResourceFilterSection extends StatelessWidget {
  const _ResourceFilterSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _muted,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: children),
        ],
      ),
    );
  }
}

class _ResourceOptionChip extends StatelessWidget {
  const _ResourceOptionChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: SizedBox(
        width: 80,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: const Color(0xfff5f5f5),
      selectedColor: _accentSoft,
      labelStyle: TextStyle(
        color: selected ? _accent : _ink,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

String _resourceTypeLabel(SavedResourceType type) {
  return switch (type) {
    SavedResourceType.image => '图片',
    SavedResourceType.videoClip => '视频片段',
  };
}
