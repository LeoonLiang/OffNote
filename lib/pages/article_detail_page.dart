part of '../main.dart';

class ArticleDetailPage extends StatefulWidget {
  const ArticleDetailPage({
    super.key,
    required this.article,
    required this.store,
    required this.onChanged,
  });

  final SavedArticle article;
  final ArticleSnapshotStore store;
  final VoidCallback onChanged;

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  late final WebViewController _controller;
  late final Future<OffNoteVideoSource?> _videoSourceFuture;
  late SavedArticle _article = widget.article;

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
    return Scaffold(
      appBar: AppBar(
        title: Text(_article.title, maxLines: 1),
        actions: [
          IconButton(
            onPressed: _editRemark,
            tooltip: '备注',
            icon: const Icon(Icons.sticky_note_2_outlined),
          ),
          IconButton(
            onPressed: _chooseCategory,
            tooltip: '分类',
            icon: const Icon(Icons.sell_outlined),
          ),
          IconButton(
            onPressed: _copyHtmlToClipboard,
            tooltip: '复制 HTML',
            icon: const Icon(Icons.code),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.cloud_off_outlined, color: _accent),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _RemarkBar(article: _article, onTap: _editRemark),
            Expanded(child: _buildArticleBody()),
          ],
        ),
      ),
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
    setState(() => _article = _article.copyWith(categoryId: categoryId));
    widget.onChanged();
  }

  Future<void> _copyHtmlToClipboard() async {
    try {
      final html = await File(_article.htmlPath).readAsString();
      await Clipboard.setData(ClipboardData(text: html));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已复制 HTML：${html.length} 字符')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('复制失败：$error')));
    }
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
    setState(() => _article = _article.copyWith(remark: remark));
    widget.onChanged();
  }
}

class _RemarkBar extends StatelessWidget {
  const _RemarkBar({required this.article, required this.onTap});

  final SavedArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasRemark = article.remark.isNotEmpty;
    return Material(
      color: hasRemark ? Colors.white : _paper,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xffdedfd7))),
          ),
          child: Row(
            children: [
              Icon(
                hasRemark
                    ? Icons.sticky_note_2_rounded
                    : Icons.sticky_note_2_outlined,
                size: 18,
                color: hasRemark ? _accent : _muted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasRemark ? article.remark : '添加备注',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasRemark ? _ink : _muted,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: hasRemark ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.edit_outlined, size: 16, color: _muted),
            ],
          ),
        ),
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
    return Stack(
      fit: StackFit.expand,
      children: [
        // 视频播放器拉满屏幕
        OffNoteVideoPlayer(source: widget.source),

        // 底部正文覆盖层
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _ContentOverlay(
            article: widget.article,
            isExpanded: _isContentExpanded,
            onExpandTap: () {
              setState(() => _isContentExpanded = !_isContentExpanded);
            },
          ),
        ),
      ],
    );
  }
}

class _ContentOverlay extends StatelessWidget {
  const _ContentOverlay({
    required this.article,
    required this.isExpanded,
    required this.onExpandTap,
  });

  final SavedArticle article;
  final bool isExpanded;
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
      spans.add(TextSpan(
        text: '#$topic#',
        style: baseStyle.copyWith(color: const Color(0xff1E90FF)),
      ));

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
    if (isExpanded) {
      return _ExpandedContent(
        article: article,
        onCollapse: onExpandTap,
      );
    }

    return GestureDetector(
      onTap: onExpandTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.8),
            ],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
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
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                  ),
                  if (article.content.isNotEmpty) ...[
                    const SizedBox(height: 4),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: const Row(
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
    required this.article,
    required this.onCollapse,
  });

  final SavedArticle article;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动指示器和关闭按钮
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
                    color: Colors.white.withValues(alpha: 0.3),
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
                        color: Colors.white70,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 可滚动内容
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: _ContentOverlay._buildTextWithTopics(
                      article.title,
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (article.content.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    RichText(
                      text: _ContentOverlay._buildTextWithTopics(
                        article.content,
                        TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
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
