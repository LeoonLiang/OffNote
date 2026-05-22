part of '../main.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key, required this.store, required this.onChanged});

  final ArticleSnapshotStore store;
  final VoidCallback onChanged;

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late Future<List<SavedCategory>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.store.listCategories();
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.store.listCategories());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '分类管理',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          ShadButton.ghost(onPressed: _createCategory, child: const Text('新建')),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<SavedCategory>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final categories = snapshot.data ?? const <SavedCategory>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ShadButton.outline(
                  onPressed: _createCategory,
                  width: double.infinity,
                  leading: const Icon(LucideIcons.folderPlus, size: 18),
                  child: const Text('新建文件夹'),
                ),
                const SizedBox(height: 12),
                if (categories.isEmpty)
                  const _EmptyMessage(
                    icon: Icons.folder_open_rounded,
                    text: '还没有分类文件夹',
                  ),
                ...categories.map(
                  (category) => _CategoryTile(
                    category: category,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ArticleListPage(
                          title: category.name,
                          category: category,
                          store: widget.store,
                          onChanged: widget.onChanged,
                        ),
                      ),
                    ),
                    onRename: () => _renameCategory(category),
                    onDelete: () => _deleteCategory(category),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _createCategory() async {
    final name = await _askName(title: '新建文件夹', initialValue: '');
    if (name == null || name.trim().isEmpty) {
      return;
    }
    final color =
        _folderColors[DateTime.now().millisecond % _folderColors.length];
    await widget.store.createCategory(name, color);
    widget.onChanged();
    await _refresh();
  }

  Future<void> _renameCategory(SavedCategory category) async {
    final name = await _askName(title: '重命名文件夹', initialValue: category.name);
    if (name == null || name.trim().isEmpty) {
      return;
    }
    await widget.store.renameCategory(category.id, name);
    widget.onChanged();
    await _refresh();
  }

  Future<void> _deleteCategory(SavedCategory category) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('删除分类'),
        description: Text('删除「${category.name}」后，文章会变为未分类。'),
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
    await widget.store.deleteCategory(category.id);
    widget.onChanged();
    await _refresh();
  }

  Future<String?> _askName({
    required String title,
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    try {
      return await showShadDialog<String>(
        context: context,
        builder: (context) => ShadDialog(
          title: Text(title),
          description: const Text('分类会显示在底部“分类”页里。'),
          constraints: const BoxConstraints(maxWidth: 420),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ShadButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('保存'),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: ShadInput(
              controller: controller,
              autofocus: true,
              placeholder: const Text('文件夹名称'),
              leading: const Icon(LucideIcons.folder, size: 18),
            ),
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}
