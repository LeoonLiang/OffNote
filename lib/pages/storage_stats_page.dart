part of '../main.dart';

class StorageStatsPage extends StatelessWidget {
  const StorageStatsPage({super.key, required this.store});

  final ArticleSnapshotStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '使用统计',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<ArticleStorageStats>(
        future: store.loadStorageStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _EmptyMessage(
              icon: Icons.error_outline_rounded,
              text: '统计失败：${snapshot.error}',
            );
          }
          final stats = snapshot.data!;
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _StatsHero(stats: stats),
                const SizedBox(height: 16),
                _StatsSection(
                  title: '内容',
                  children: [
                    _StatsRow(label: '文章总数', value: '${stats.articleCount}'),
                    _StatsRow(label: '图文', value: '${stats.imageArticleCount}'),
                    _StatsRow(label: '视频', value: '${stats.videoArticleCount}'),
                    _StatsRow(label: '分类', value: '${stats.categoryCount}'),
                    _StatsRow(
                      label: '未分类',
                      value: '${stats.uncategorizedCount}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _StatsSection(
                  title: '空间',
                  children: [
                    _StatsRow(
                      label: '图片',
                      value: _formatBytes(stats.imageBytes),
                    ),
                    _StatsRow(
                      label: '视频',
                      value: _formatBytes(stats.videoBytes),
                    ),
                    _StatsRow(
                      label: 'HTML',
                      value: _formatBytes(stats.htmlBytes),
                    ),
                    _StatsRow(
                      label: '其他',
                      value: _formatBytes(stats.otherBytes),
                    ),
                    _StatsRow(
                      label: '平均每篇',
                      value: _formatBytes(stats.averageArticleBytes),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  final kb = bytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(1)} KB';
  }
  final mb = kb / 1024;
  if (mb < 1024) {
    return '${mb.toStringAsFixed(1)} MB';
  }
  return '${(mb / 1024).toStringAsFixed(1)} GB';
}

class _StatsHero extends StatelessWidget {
  const _StatsHero({required this.stats});

  final ArticleStorageStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffdedfd7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.storage_rounded, color: _accent, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '本地占用',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatBytes(stats.totalBytes),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffdedfd7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
