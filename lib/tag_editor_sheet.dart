import 'package:flutter/material.dart';

import 'saved_tag.dart';

class TagEditResult {
  const TagEditResult({required this.tags, required this.selectedIds});

  final List<SavedTag> tags;
  final Set<String> selectedIds;
}

class TagEditorSheet extends StatefulWidget {
  const TagEditorSheet({
    super.key,
    required this.initialTags,
    required this.initialSelectedIds,
    required this.onCreateTag,
    required this.accentColor,
  });

  final List<SavedTag> initialTags;
  final Set<String> initialSelectedIds;
  final Future<SavedTag> Function(String name) onCreateTag;
  final Color accentColor;

  @override
  State<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<TagEditorSheet> {
  late var _tags = widget.initialTags.toList(growable: true);
  late final _selectedIds = Set<String>.of(widget.initialSelectedIds);
  final _nameController = TextEditingController();
  bool _creating = false;
  bool _showCreateField = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            ListTile(
              title: const Text(
                '文章标签',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              trailing: TextButton(
                onPressed: () => Navigator.of(context).pop(
                  TagEditResult(
                    tags: _tags,
                    selectedIds: Set<String>.of(_selectedIds),
                  ),
                ),
                child: const Text('保存'),
              ),
            ),
            if (_showCreateField) _buildCreateField() else _buildCreateButton(),
            if (_tags.isEmpty) const ListTile(title: Text('还没有标签')),
            ..._tags.map(
              (tag) => CheckboxListTile(
                value: _selectedIds.contains(tag.id),
                secondary: Icon(Icons.label_rounded, color: Color(tag.color)),
                title: Text(tag.name),
                activeColor: widget.accentColor,
                onChanged: (_) {
                  setState(() {
                    if (!_selectedIds.add(tag.id)) {
                      _selectedIds.remove(tag.id);
                    }
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return ListTile(
      leading: Icon(Icons.add_rounded, color: widget.accentColor),
      title: const Text('新建标签'),
      enabled: !_creating,
      onTap: () {
        setState(() => _showCreateField = true);
      },
    );
  }

  Widget _buildCreateField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: '标签名称',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (_) => _createTag(),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _creating
                ? null
                : () {
                    _nameController.clear();
                    setState(() => _showCreateField = false);
                  },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: _creating ? null : _createTag,
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTag() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    setState(() => _creating = true);
    try {
      final tag = await widget.onCreateTag(name);
      if (!mounted) {
        return;
      }
      setState(() {
        _tags = [tag, ..._tags];
        _selectedIds.add(tag.id);
        _nameController.clear();
        _showCreateField = false;
        _creating = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _creating = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('创建失败：$error')));
    }
  }
}
