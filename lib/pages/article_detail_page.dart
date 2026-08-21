part of '../main.dart';

class ArticleDetailPage extends StatefulWidget {
  const ArticleDetailPage({
    super.key,
    required this.article,
    required this.store,
    this.resourceQueue,
    this.initialVideoPosition,
  });

  final SavedArticle article;
  final ArticleSnapshotStore store;
  final ResourceProcessingQueueController? resourceQueue;
  final Duration? initialVideoPosition;

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
          onCreateClip: _createVideoClipResource,
          initialVideoPosition: widget.initialVideoPosition,
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
          onSave: _createImageResource,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _createImageResource(File file) async {
    final result = await _showResourceEditor(
      title: '收藏图片',
      initialTitle: _article.title,
      initialNote: '',
    );
    if (result == null) {
      return;
    }
    await widget.store.createImageResource(
      articleId: _article.id,
      imagePath: file.path,
      title: result.title,
      note: result.note,
      tagIds: result.tagIds,
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已收藏到素材库')));
  }

  Future<void> _createVideoClipResource(
    OffNoteVideoSource source,
    Duration position,
    Duration duration,
  ) async {
    final sourcePath = _fileFromPreviewSource(source.videoUri)?.path;
    if (sourcePath == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有找到本地视频文件')));
      return;
    }
    final defaultStart = position - const Duration(seconds: 15);
    final start = defaultStart < Duration.zero ? Duration.zero : defaultStart;
    final defaultEnd = position + const Duration(seconds: 15);
    final end = duration > Duration.zero && defaultEnd > duration
        ? duration
        : defaultEnd;
    final result = await _showResourceEditor(
      title: '收藏视频片段',
      initialTitle: _article.title,
      initialNote: '',
      initialStart: start,
      initialEnd: end,
      maxDuration: duration,
    );
    if (result == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final resourceQueue = widget.resourceQueue;
    if (resourceQueue == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请从首页或画廊打开后再截取片段')));
      return;
    }
    resourceQueue.enqueueVideoClip(
      VideoClipQueueRequest(
        articleId: _article.id,
        videoPath: sourcePath,
        previewPath: _fileFromPreviewSource(source.posterUri ?? '')?.path,
        title: result.title,
        note: result.note,
        start: result.start!,
        end: result.end!,
        tagIds: result.tagIds,
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已加入素材处理队列'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ResourceProcessingQueuePage(queue: resourceQueue),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<_ResourceEditResult?> _showResourceEditor({
    required String title,
    required String initialTitle,
    required String initialNote,
    Duration? initialStart,
    Duration? initialEnd,
    Duration? maxDuration,
  }) async {
    final allTags = await widget.store.listTags();
    if (!mounted) {
      return null;
    }
    return showModalBottomSheet<_ResourceEditResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _ResourceEditorSheet(
        title: title,
        initialTitle: initialTitle,
        initialNote: initialNote,
        initialTags: allTags,
        initialStart: initialStart,
        initialEnd: initialEnd,
        maxDuration: maxDuration,
        onCreateTag: (name) async {
          final color =
              _folderColors[DateTime.now().millisecond % _folderColors.length];
          return widget.store.createTag(name, color);
        },
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
  const _ImagePreviewPage({
    required this.files,
    required this.initialIndex,
    required this.onSave,
  });

  final List<File> files;
  final int initialIndex;
  final Future<void> Function(File file) onSave;

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

  Future<void> _shareCurrentImage() async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(widget.files[_index].path)]),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('分享图片失败：$error')));
    }
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
        actions: [
          IconButton(
            onPressed: () => widget.onSave(widget.files[_index]),
            tooltip: '收藏图片',
            icon: const Icon(Icons.bookmark_add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onLongPress: _shareCurrentImage,
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

class _ResourceEditResult {
  const _ResourceEditResult({
    required this.title,
    required this.note,
    required this.tagIds,
    this.start,
    this.end,
  });

  final String title;
  final String note;
  final Set<String> tagIds;
  final Duration? start;
  final Duration? end;
}

class _ResourceEditorSheet extends StatefulWidget {
  const _ResourceEditorSheet({
    required this.title,
    required this.initialTitle,
    required this.initialNote,
    required this.initialTags,
    required this.onCreateTag,
    this.initialStart,
    this.initialEnd,
    this.maxDuration,
  });

  final String title;
  final String initialTitle;
  final String initialNote;
  final List<SavedTag> initialTags;
  final Future<SavedTag> Function(String name) onCreateTag;
  final Duration? initialStart;
  final Duration? initialEnd;
  final Duration? maxDuration;

  @override
  State<_ResourceEditorSheet> createState() => _ResourceEditorSheetState();
}

class _ResourceEditorSheetState extends State<_ResourceEditorSheet> {
  late var _tags = widget.initialTags.toList(growable: true);
  final _selectedIds = <String>{};
  late final _titleController = TextEditingController(
    text: widget.initialTitle,
  );
  late final _noteController = TextEditingController(text: widget.initialNote);
  late final _startController = TextEditingController(
    text: widget.initialStart == null
        ? ''
        : formatVideoMarkerPosition(widget.initialStart!),
  );
  late final _endController = TextEditingController(
    text: widget.initialEnd == null
        ? ''
        : formatVideoMarkerPosition(widget.initialEnd!),
  );
  final _newTagController = TextEditingController();
  bool _isCreatingTag = false;
  String? _errorText;

  bool get _hasTimeRange =>
      widget.initialStart != null || widget.initialEnd != null;

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _startController.dispose();
    _endController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '备注',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_hasTimeRange) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _startController,
                        decoration: const InputDecoration(
                          labelText: '开始',
                          hintText: '00:12',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _endController,
                        decoration: const InputDecoration(
                          labelText: '结束',
                          hintText: '00:42',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in _tags)
                    FilterChip(
                      selected: _selectedIds.contains(tag.id),
                      avatar: Icon(
                        Icons.label_rounded,
                        color: Color(tag.color),
                        size: 18,
                      ),
                      label: Text(tag.name),
                      selectedColor: _accentSoft,
                      checkmarkColor: _accent,
                      onSelected: (_) {
                        setState(() {
                          if (!_selectedIds.add(tag.id)) {
                            _selectedIds.remove(tag.id);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newTagController,
                      enabled: !_isCreatingTag,
                      decoration: const InputDecoration(
                        hintText: '新建标签',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _createTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _isCreatingTag ? null : _createTag,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('添加'),
                  ),
                ],
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Color(0xffb42318)),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: const Text('收藏')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createTag() async {
    final name = _newTagController.text.trim();
    if (name.isEmpty) {
      return;
    }
    setState(() => _isCreatingTag = true);
    try {
      final tag = await widget.onCreateTag(name);
      if (!mounted) {
        return;
      }
      setState(() {
        _tags = [tag, ..._tags];
        _selectedIds.add(tag.id);
        _newTagController.clear();
        _isCreatingTag = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = '标签创建失败：$error';
        _isCreatingTag = false;
      });
    }
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorText = '请填写标题');
      return;
    }
    Duration? start;
    Duration? end;
    if (_hasTimeRange) {
      start = _parseDurationText(_startController.text);
      end = _parseDurationText(_endController.text);
      if (start == null || end == null || end <= start) {
        setState(() => _errorText = '请填写有效的起止时间');
        return;
      }
      final maxDuration = widget.maxDuration;
      if (maxDuration != null &&
          maxDuration > Duration.zero &&
          end > maxDuration) {
        setState(() => _errorText = '结束时间不能超过视频长度');
        return;
      }
    }
    Navigator.of(context).pop(
      _ResourceEditResult(
        title: title,
        note: _noteController.text.trim(),
        tagIds: Set<String>.of(_selectedIds),
        start: start,
        end: end,
      ),
    );
  }
}

Duration? _parseDurationText(String text) {
  final parts = text.trim().split(':');
  if (parts.length == 2) {
    return parseVideoMarkerPositionFields(minutes: parts[0], seconds: parts[1]);
  }
  if (parts.length == 3) {
    return parseVideoMarkerPositionFields(
      hours: parts[0],
      minutes: parts[1],
      seconds: parts[2],
    );
  }
  final seconds = int.tryParse(text.trim());
  if (seconds == null || seconds < 0) {
    return null;
  }
  return Duration(seconds: seconds);
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
    required this.onCreateClip,
    this.initialVideoPosition,
  });

  final SavedArticle article;
  final OffNoteVideoSource source;
  final List<VideoMarker> markers;
  final VideoMarkerCreateCallback onCreateMarker;
  final VideoMarkerUpdateCallback onUpdateMarker;
  final VideoMarkerDeleteCallback onDeleteMarker;
  final Future<void> Function(
    OffNoteVideoSource source,
    Duration position,
    Duration duration,
  )
  onCreateClip;
  final Duration? initialVideoPosition;

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
                    onCreateClip: (position, duration) =>
                        widget.onCreateClip(widget.source, position, duration),
                    initialPosition: widget.initialVideoPosition,
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
