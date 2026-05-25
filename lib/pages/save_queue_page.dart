part of '../main.dart';

class SaveQueuePage extends StatelessWidget {
  const SaveQueuePage({super.key, required this.queue});

  final SaveQueueController queue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '收录队列',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: AnimatedBuilder(
        animation: queue,
        builder: (context, _) {
          final tasks = queue.tasks;
          if (tasks.isEmpty) {
            return const _EmptyMessage(
              icon: Icons.playlist_add_check_rounded,
              text: '暂无收录任务',
            );
          }
          return SafeArea(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _SaveQueueTile(queue: queue, task: tasks[index]),
            ),
          );
        },
      ),
    );
  }
}

class _SaveQueueTile extends StatelessWidget {
  const _SaveQueueTile({required this.queue, required this.task});

  final SaveQueueController queue;
  final SaveQueueTask task;

  @override
  Widget build(BuildContext context) {
    final status = _statusView(task.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffdedfd7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(dimension: 28, child: Center(child: status.icon)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.article?.title ?? task.url,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  task.status == SaveQueueTaskStatus.failed ||
                          task.status == SaveQueueTaskStatus.needsAction
                      ? task.errorMessage ?? '收录失败'
                      : status.label,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: status.color,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (task.errorDetail != null &&
                    task.errorDetail != task.errorMessage) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.errorDetail!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
                if (task.status == SaveQueueTaskStatus.needsAction ||
                    task.status == SaveQueueTaskStatus.failed) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => queue.retry(task.id),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('重试'),
                      ),
                      if (task.canConfirmPartial)
                        FilledButton.icon(
                          onPressed: () => queue.confirmPartial(task.id),
                          icon: const Icon(Icons.check_rounded, size: 16),
                          label: const Text('仍然保存'),
                        ),
                      if (task.status == SaveQueueTaskStatus.needsAction)
                        TextButton.icon(
                          onPressed: () => queue.cancel(task.id),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('取消'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  _QueueStatusView _statusView(SaveQueueTaskStatus status) {
    switch (status) {
      case SaveQueueTaskStatus.waiting:
        return const _QueueStatusView(
          label: '等待中',
          color: _muted,
          icon: Icon(Icons.schedule_rounded, color: _muted, size: 20),
        );
      case SaveQueueTaskStatus.running:
        return const _QueueStatusView(
          label: '处理中',
          color: _accent,
          icon: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
          ),
        );
      case SaveQueueTaskStatus.success:
        return const _QueueStatusView(
          label: '已完成',
          color: _accent,
          icon: Icon(Icons.check_circle_rounded, color: _accent, size: 20),
        );
      case SaveQueueTaskStatus.failed:
        return const _QueueStatusView(
          label: '收录失败',
          color: Colors.redAccent,
          icon: Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 20,
          ),
        );
      case SaveQueueTaskStatus.needsAction:
        return const _QueueStatusView(
          label: '需要处理',
          color: Colors.orange,
          icon: Icon(
            Icons.report_problem_outlined,
            color: Colors.orange,
            size: 20,
          ),
        );
      case SaveQueueTaskStatus.cancelled:
        return const _QueueStatusView(
          label: '已取消',
          color: _muted,
          icon: Icon(Icons.cancel_outlined, color: _muted, size: 20),
        );
    }
  }
}

class _QueueStatusView {
  const _QueueStatusView({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final Widget icon;
}
