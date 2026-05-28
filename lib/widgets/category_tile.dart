part of '../main.dart';

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onTap,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
  });

  final SavedCategory category;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ShadCard(
        padding: EdgeInsets.zero,
        radius: BorderRadius.circular(18),
        border: ShadBorder.all(color: theme.colorScheme.border),
        child: ListTile(
          onTap: onTap,
          leading: Icon(
            Icons.folder_rounded,
            color: Color(category.color),
            size: 34,
          ),
          title: Text(
            category.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text('文件夹'),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'share') {
                onShare();
              } else if (value == 'rename') {
                onRename();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'share', child: Text('分享链接')),
              PopupMenuItem(value: 'rename', child: Text('重命名')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ),
      ),
    );
  }
}
