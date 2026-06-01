part of '../main.dart';

class ArticleDetailPage extends StatefulWidget {
  const ArticleDetailPage({
    super.key,
    required this.article,
    required this.store,
  });

  final SavedArticle article;
  final ArticleSnapshotStore store;

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  static const double _videoActionBarHeight = 51;

  late final WebViewController _controller;
  late final Future<OffNoteVideoSource?> _videoSourceFuture;
  late SavedArticle _article = widget.article;
  var _articleTags = <SavedTag>[];
  var _videoMarkers = <VideoMarker>[];
  bool _hasListChanges = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'OffNoteImagePreview',
        onMessageReceived: (message) => _openImagePreview(message.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _installImagePreviewHandler(),
        ),
      )
      ..loadFile(widget.article.htmlPath);
    _videoSourceFuture = _loadVideoSource();
    _loadArticleTags();
    if (widget.article.mediaType == ArticleMediaType.video) {
      _loadVideoMarkers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionBar = _DetailBottomActionBar(
      article: _article,
      isVideo: _article.mediaType == ArticleMediaType.video,
      onStarredTap: _toggleStarred,
      onOpenOriginalTap: _article.originalUrl.trim().isEmpty
          ? null
          : _openOriginalUrl,
      onRemarkTap: _editRemark,
      onCategoryTap: _chooseCategory,
      onTagsTap: _editTags,
      hasTags: _articleTags.isNotEmpty,
    );
    return PopScope<ArticleDetailResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        _closeDetail();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_article.title, maxLines: 1)),
        body: SafeArea(
          child: _article.mediaType == ArticleMediaType.video
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(left: 0, right: 0, bottom: 0, child: actionBar),
                    Positioned.fill(
                      bottom: _videoActionBarHeight,
                      child: _buildArticleBody(),
                    ),
                  ],
                )
              : Column(
                  children: [
                    Expanded(child: _buildArticleBody()),
                    actionBar,
                  ],
                ),
        ),
      ),
    );
  }

  void _closeDetail() {
    Navigator.of(context).pop(
      _hasListChanges
          ? ArticleDetailResult.changed
          : ArticleDetailResult.unchanged,
    );
  }

  Widget _buildArticleBody() {
    if (_article.mediaType != ArticleMediaType.video) {
      return WebViewWidget(controller: _controller);
    }

    return FutureBuilder<OffNoteVideoSource?>(
      future: _videoSourceFuture,
      builder: (context, snapshot) {
        final source = snapshot.data;
        if (source == null) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return WebViewWidget(controller: _controller);
        }
        return _VideoArticleView(
          article: _article,
          source: source,
          markers: _videoMarkers,
          onCreateMarker: _createVideoMarker,
          onUpdateMarker: _updateVideoMarker,
          onDeleteMarker: _deleteVideoMarker,
        );
      },
    );
  }

  Future<OffNoteVideoSource?> _loadVideoSource() async {
    final html = await File(widget.article.htmlPath).readAsString();
    return OffNoteVideoSource.fromHtml(html);
  }

  Future<void> _loadArticleTags() async {
    final tags = await widget.store.listArticleTags(_article.id);
    if (!mounted) {
      return;
    }
    setState(() => _articleTags = tags);
  }

  Future<void> _loadVideoMarkers() async {
    final markers = await widget.store.listVideoMarkers(_article.id);
    if (!mounted) {
      return;
    }
    setState(() => _videoMarkers = markers);
  }

  Future<void> _createVideoMarker(Duration position, String note) async {
    await _runVideoMarkerMutation(() async {
      final marker = await widget.store.createVideoMarker(
        articleId: _article.id,
        position: position,
        note: note,
      );
      setState(() {
        _videoMarkers = [..._videoMarkers, marker]
          ..sort((a, b) => a.position.compareTo(b.position));
      });
    });
  }

  Future<void> _updateVideoMarker(
    VideoMarker marker,
    Duration position,
    String note,
  ) async {
    await _runVideoMarkerMutation(() async {
      final updated = marker.copyWith(
        position: position,
        note: note,
        updatedAt: DateTime.now(),
      );
      await widget.store.updateVideoMarker(updated);
      setState(() {
        _videoMarkers =
            _videoMarkers
                .map(
                  (existing) => existing.id == updated.id ? updated : existing,
                )
                .toList(growable: false)
              ..sort((a, b) => a.position.compareTo(b.position));
      });
    });
  }

  Future<void> _deleteVideoMarker(VideoMarker marker) async {
    await _runVideoMarkerMutation(() async {
      await widget.store.deleteVideoMarker(marker.id);
      setState(() {
        _videoMarkers = _videoMarkers
            .where((existing) => existing.id != marker.id)
            .toList(growable: false);
      });
    });
  }

  Future<void> _runVideoMarkerMutation(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('时间点保存失败')));
    }
  }

  Future<void> _chooseCategory() async {
    final categories = await widget.store.listCategories();
    if (!mounted) {
      return;
    }
    const uncategorizedValue = '__offnote_uncategorized__';
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                '选择分类',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: Icon(
                _article.categoryId == null
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: _article.categoryId == null ? _accent : Colors.black26,
              ),
              title: const Text('未分类'),
              onTap: () => Navigator.of(context).pop(uncategorizedValue),
            ),
            ...categories.map(
              (category) => ListTile(
                leading: Icon(
                  Icons.folder_rounded,
                  color: Color(category.color),
                ),
                title: Text(category.name),
                trailing: _article.categoryId == category.id
                    ? const Icon(Icons.check_rounded, color: _accent)
                    : null,
                onTap: () => Navigator.of(context).pop(category.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null) {
      return;
    }
    final categoryId = selected == uncategorizedValue ? null : selected;
    if (categoryId == _article.categoryId) {
      return;
    }
    await widget.store.assignArticleCategory(_article.id, categoryId);
    setState(() {
      _article = _article.copyWith(categoryId: categoryId);
      _hasListChanges = true;
    });
  }

  Future<void> _editTags() async {
    final allTags = await widget.store.listTags();
    if (!mounted) {
      return;
    }
    final selected = _articleTags.map((tag) => tag.id).toSet();
    final result = await showModalBottomSheet<TagEditResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => TagEditorSheet(
        initialTags: allTags,
        initialSelectedIds: selected,
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
    await widget.store.setArticleTags(_article.id, result.selectedIds);
    if (!mounted) {
      return;
    }
    setState(() {
      _articleTags = result.tags
          .where((tag) => result.selectedIds.contains(tag.id))
          .toList(growable: false);
      _hasListChanges = true;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('标签已更新')));
  }

  Future<void> _openOriginalUrl() async {
    final uri = Uri.tryParse(_article.originalUrl.trim());
    if (uri == null) {
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || opened) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('没能打开原始链接')));
  }

  Future<void> _openImagePreview(String message) async {
    final preview = _ImagePreviewRequest.fromMessage(message);
    final files = preview.sources
        .map(_fileFromPreviewSource)
        .whereType<File>()
        .where((file) => file.existsSync())
        .toList(growable: false);
    if (files.isEmpty || !mounted) {
      return;
    }
    final tappedFile = _fileFromPreviewSource(preview.src);
    final matchedIndex = tappedFile == null
        ? -1
        : files.indexWhere((file) => file.path == tappedFile.path);
    final fallbackIndex = preview.index.clamp(0, files.length - 1);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ImagePreviewPage(
          files: files,
          initialIndex: matchedIndex < 0 ? fallbackIndex : matchedIndex,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _installImagePreviewHandler() async {
    try {
      await _controller.runJavaScript(r'''
        (function () {
          if (window.__offnoteImagePreviewInstalled) return;
          window.__offnoteImagePreviewInstalled = true;
          var images = document.querySelectorAll('.slide img, .comment-images img');
          images.forEach(function (image) {
            if (!image.dataset.previewSrc) image.dataset.previewSrc = image.currentSrc || image.src;
            image.classList.add('previewable-image');
            image.style.cursor = 'zoom-in';
          });
          document.addEventListener('click', function (event) {
            var target = event.target;
            if (!target || !target.dataset || !target.dataset.previewSrc) return;
            if (!window.OffNoteImagePreview || !window.OffNoteImagePreview.postMessage) return;
            var src = target.dataset.previewSrc;
            var group = target.closest('.carousel, .comment-images');
            var images = group ? Array.prototype.slice.call(group.querySelectorAll('[data-preview-src]')) : [target];
            var sources = images.map(function (image) { return image.dataset.previewSrc; }).filter(Boolean);
            window.OffNoteImagePreview.postMessage(JSON.stringify({
              src: src,
              sources: sources,
              index: Math.max(0, sources.indexOf(src))
            }));
          });
        })();
      ''');
    } catch (error) {
      debugPrint('Install image preview handler failed: $error');
    }
  }

  File? _fileFromPreviewSource(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.scheme == 'file') {
      return File(uri.toFilePath());
    }
    return File(trimmed);
  }

  Future<void> _toggleStarred() async {
    final next = !_article.isStarred;
    await widget.store.updateArticleStarred(_article.id, next);
    if (!mounted) {
      return;
    }
    setState(() {
      _article = _article.copyWith(isStarred: next);
      _hasListChanges = true;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(next ? '已星标' : '已取消星标')));
  }

  Future<void> _editRemark() async {
    final controller = TextEditingController(text: _article.remark);
    final remark = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('文章备注'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: '写点只给自己看的补充信息',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (remark == null) {
      return;
    }
    await widget.store.updateArticleRemark(_article.id, remark);
    setState(() {
      _article = _article.copyWith(remark: remark);
      _hasListChanges = true;
    });
  }
}

class _ImagePreviewRequest {
  const _ImagePreviewRequest({
    required this.src,
    required this.sources,
    required this.index,
  });

  final String src;
  final List<String> sources;
  final int index;

  factory _ImagePreviewRequest.fromMessage(String message) {
    try {
      final decoded = jsonDecode(message);
      if (decoded is Map<String, Object?>) {
        final src = decoded['src'] as String? ?? '';
        final sources = decoded['sources'] is List
            ? (decoded['sources'] as List).whereType<String>().toList()
            : <String>[];
        final indexValue = decoded['index'];
        return _ImagePreviewRequest(
          src: src,
          sources: sources.isEmpty ? [src] : sources,
          index: indexValue is num ? indexValue.toInt() : 0,
        );
      }
    } catch (_) {
      return _ImagePreviewRequest(src: message, sources: [message], index: 0);
    }
    return _ImagePreviewRequest(src: message, sources: [message], index: 0);
  }
}

class _ImagePreviewPage extends StatefulWidget {
  const _ImagePreviewPage({required this.files, required this.initialIndex});

  final List<File> files;
  final int initialIndex;

  @override
  State<_ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<_ImagePreviewPage> {
  late final PageController _pageController;
  late int _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '关闭',
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(
          '${_index + 1} / ${widget.files.length}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: PhotoViewGallery.builder(
          pageController: _pageController,
          itemCount: widget.files.length,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          onPageChanged: (index) => setState(() => _index = index),
          builder: (context, index) {
            return PhotoViewGalleryPageOptions(
              imageProvider: FileImage(widget.files[index]),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4,
              errorBuilder: (_, _, _) => const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white70,
                  size: 42,
                ),
              ),
            );
          },
          loadingBuilder: (_, _) => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _DetailBottomActionBar extends StatelessWidget {
  const _DetailBottomActionBar({
    required this.article,
    required this.isVideo,
    required this.onStarredTap,
    required this.onOpenOriginalTap,
    required this.onRemarkTap,
    required this.onCategoryTap,
    required this.onTagsTap,
    required this.hasTags,
  });

  final SavedArticle article;
  final bool isVideo;
  final VoidCallback onStarredTap;
  final VoidCallback? onOpenOriginalTap;
  final VoidCallback onRemarkTap;
  final VoidCallback onCategoryTap;
  final VoidCallback onTagsTap;
  final bool hasTags;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _FloatingDetailAction(
        icon: article.isStarred
            ? Icons.star_rounded
            : Icons.star_border_rounded,
        iconColor: article.isStarred ? const Color(0xffffb300) : _muted,
        inactiveIconColor: isVideo ? Colors.white70 : _muted,
        onTap: onStarredTap,
      ),
      if (onOpenOriginalTap != null)
        _FloatingDetailAction(
          icon: Icons.open_in_new_rounded,
          inactiveIconColor: isVideo ? Colors.white70 : _muted,
          onTap: onOpenOriginalTap!,
        ),
      _FloatingDetailAction(
        icon: article.remark.isEmpty
            ? Icons.sticky_note_2_outlined
            : Icons.sticky_note_2_rounded,
        iconColor: article.remark.isEmpty ? _muted : _accent,
        inactiveIconColor: isVideo ? Colors.white70 : _muted,
        onTap: onRemarkTap,
      ),
      _FloatingDetailAction(
        icon: Icons.sell_outlined,
        iconColor: article.categoryId == null ? _muted : _accent,
        inactiveIconColor: isVideo ? Colors.white70 : _muted,
        onTap: onCategoryTap,
      ),
      _FloatingDetailAction(
        icon: hasTags ? Icons.label_rounded : Icons.label_outline_rounded,
        iconColor: hasTags ? _accent : _muted,
        inactiveIconColor: isVideo ? Colors.white70 : _muted,
        onTap: onTagsTap,
      ),
    ];

    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: isVideo ? Colors.black : Colors.white,
              border: isVideo
                  ? null
                  : const Border(top: BorderSide(color: Color(0xffdedfd7))),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(10, isVideo ? 5 : 2, 10, 4),
              child: Row(
                children: [
                  for (final action in actions) Expanded(child: action),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingDetailAction extends StatelessWidget {
  const _FloatingDetailAction({
    required this.icon,
    required this.onTap,
    this.iconColor = _muted,
    this.inactiveIconColor = _muted,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;
  final Color inactiveIconColor;

  @override
  Widget build(BuildContext context) {
    final color = iconColor == _muted ? inactiveIconColor : iconColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(height: 42, child: Icon(icon, color: color, size: 23)),
      ),
    );
  }
}

class _VideoArticleView extends StatefulWidget {
  const _VideoArticleView({
    required this.article,
    required this.source,
    required this.markers,
    required this.onCreateMarker,
    required this.onUpdateMarker,
    required this.onDeleteMarker,
  });

  final SavedArticle article;
  final OffNoteVideoSource source;
  final List<VideoMarker> markers;
  final VideoMarkerCreateCallback onCreateMarker;
  final VideoMarkerUpdateCallback onUpdateMarker;
  final VideoMarkerDeleteCallback onDeleteMarker;

  @override
  State<_VideoArticleView> createState() => _VideoArticleViewState();
}

class _VideoArticleViewState extends State<_VideoArticleView> {
  bool _isContentExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final playerHeight = calculateVideoPlayerHeight(
          availableHeight: availableHeight,
          isContentExpanded: _isContentExpanded,
        );

        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              height: playerHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  OffNoteVideoPlayer(
                    source: widget.source,
                    markers: widget.markers,
                    hasCollapsedContentPreview: !_isContentExpanded,
                    onCreateMarker: widget.onCreateMarker,
                    onUpdateMarker: widget.onUpdateMarker,
                    onDeleteMarker: widget.onDeleteMarker,
                  ),
                  if (!_isContentExpanded)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 46,
                      child: _CollapsedContentPreview(
                        article: widget.article,
                        hasMarkerEntry: true,
                        onExpandTap: () {
                          setState(() => _isContentExpanded = true);
                        },
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: (child, animation) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(animation);
                  return SlideTransition(
                    position: offset,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: _isContentExpanded
                    ? _ExpandedContent(
                        key: const ValueKey('expanded-video-content'),
                        article: widget.article,
                        onCollapse: () {
                          setState(() => _isContentExpanded = false);
                        },
                      )
                    : const SizedBox(
                        key: ValueKey('collapsed-video-content-space'),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CollapsedContentPreview extends StatelessWidget {
  const _CollapsedContentPreview({
    required this.article,
    required this.hasMarkerEntry,
    required this.onExpandTap,
  });

  final SavedArticle article;
  final bool hasMarkerEntry;
  final VoidCallback onExpandTap;

  static TextSpan _buildTextWithTopics(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'#([^#\[]+)\[话题\]#');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      // 添加话题前的普通文本
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }

      // 添加蓝色话题标签（去掉[话题]）
      final topic = match.group(1);
      spans.add(
        TextSpan(
          text: '#$topic#',
          style: baseStyle.copyWith(color: const Color(0xff1E90FF)),
        ),
      );

      lastIndex = match.end;
    }

    // 添加剩余的普通文本
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onExpandTap,
      child: Container(
        color: Colors.transparent,
        padding: EdgeInsets.fromLTRB(
          calculateCollapsedContentLeadingPadding(hasMarkerEntry),
          8,
          16,
          0,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    article.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                  if (article.content.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    RichText(
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      text: _buildTextWithTopics(
                        article.content,
                        const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const DecoratedBox(
              decoration: BoxDecoration(color: Colors.transparent),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '展开',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpandedContent extends StatelessWidget {
  const _ExpandedContent({
    super.key,
    required this.article,
    required this.onCollapse,
  });

  final SavedArticle article;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xffd8d8d8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: onCollapse,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _muted,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: _CollapsedContentPreview._buildTextWithTopics(
                      article.title,
                      const TextStyle(
                        color: _ink,
                        fontSize: 18,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (article.content.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    RichText(
                      text: _CollapsedContentPreview._buildTextWithTopics(
                        article.content,
                        const TextStyle(
                          color: _ink,
                          fontSize: 15,
                          height: 1.6,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
