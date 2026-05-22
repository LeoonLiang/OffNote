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
  late SavedArticle _article = widget.article;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadFile(widget.article.htmlPath);
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
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
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
