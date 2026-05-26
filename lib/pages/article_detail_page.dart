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
  bool _hasListChanges = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadFile(widget.article.htmlPath);
    _videoSourceFuture = _loadVideoSource();
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
        return _VideoArticleView(article: _article, source: source);
      },
    );
  }

  Future<OffNoteVideoSource?> _loadVideoSource() async {
    final html = await File(widget.article.htmlPath).readAsString();
    return OffNoteVideoSource.fromHtml(html);
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

class _DetailBottomActionBar extends StatelessWidget {
  const _DetailBottomActionBar({
    required this.article,
    required this.isVideo,
    required this.onStarredTap,
    required this.onOpenOriginalTap,
    required this.onRemarkTap,
    required this.onCategoryTap,
  });

  final SavedArticle article;
  final bool isVideo;
  final VoidCallback onStarredTap;
  final VoidCallback? onOpenOriginalTap;
  final VoidCallback onRemarkTap;
  final VoidCallback onCategoryTap;

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
  const _VideoArticleView({required this.article, required this.source});

  final SavedArticle article;
  final OffNoteVideoSource source;

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
                  OffNoteVideoPlayer(source: widget.source),
                  if (!_isContentExpanded)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 46,
                      child: _CollapsedContentPreview(
                        article: widget.article,
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
    required this.onExpandTap,
  });

  final SavedArticle article;
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
