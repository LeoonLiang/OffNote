part of '../main.dart';

class TagManagerPage extends StatefulWidget {
  const TagManagerPage({
    super.key,
    required this.store,
    required this.onChanged,
  });

  final ArticleSnapshotStore store;
  final VoidCallback onChanged;

  @override
  State<TagManagerPage> createState() => _TagManagerPageState();
}

class _TagManagerPageState extends State<TagManagerPage> {
  late Future<List<SavedTag>> _future = widget.store.listTags();
  String? _busyTagId;

  Future<void> _refresh() async {
    setState(() => _future = widget.store.listTags());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '标签管理',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<SavedTag>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final tags = snapshot.data ?? const <SavedTag>[];
            if (tags.isEmpty) {
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 80, 16, 24),
                  children: const [
                    _EmptyMessage(
                      icon: Icons.label_outline_rounded,
                      text: '还没有标签',
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                itemCount: tags.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _buildTagTile(tags[index]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTagTile(SavedTag tag) {
    final busy = _busyTagId == tag.id;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xffdedfd7)),
      ),
      child: ListTile(
        leading: Icon(Icons.label_rounded, color: Color(tag.color)),
        title: Text(
          tag.name,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: const Text('删除标签不会删除文章'),
        trailing: busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Wrap(
                spacing: 2,
                children: [
                  IconButton(
                    tooltip: '编辑标签',
                    onPressed: () => _renameTag(tag),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                  IconButton(
                    tooltip: '删除标签',
                    onPressed: () => _deleteTag(tag),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _renameTag(SavedTag tag) async {
    final controller = TextEditingController(text: tag.name);
    final nextName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑标签'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '标签名称',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
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
    if (nextName == null || nextName.isEmpty || nextName == tag.name) {
      return;
    }
    setState(() => _busyTagId = tag.id);
    try {
      await widget.store.renameTag(tag.id, nextName);
      widget.onChanged();
      if (!mounted) {
        return;
      }
      await _refresh();
      _showSnackBar('标签已更新');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('更新标签失败：$error');
    } finally {
      if (mounted) {
        setState(() => _busyTagId = null);
      }
    }
  }

  Future<void> _deleteTag(SavedTag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('确定删除「${tag.name}」吗？不会删除文章，只会移除文章上的这个标签。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _busyTagId = tag.id);
    try {
      await widget.store.deleteTag(tag.id);
      widget.onChanged();
      if (!mounted) {
        return;
      }
      await _refresh();
      _showSnackBar('标签已删除');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar('删除标签失败：$error');
    } finally {
      if (mounted) {
        setState(() => _busyTagId = null);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }
}
