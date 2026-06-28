part of '../main.dart';

class ResourceProcessingQueuePage extends StatelessWidget {
  const ResourceProcessingQueuePage({super.key, required this.queue});

  final ResourceProcessingQueueController queue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '素材处理队列',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          AnimatedBuilder(
            animation: queue,
            builder: (context, _) {
              final hasFailed = queue.hasFailed;
              final hasFinished = queue.tasks.any(
                (task) =>
                    task.status == ResourceQueueTaskStatus.success ||
                    task.status == ResourceQueueTaskStatus.failed,
              );
              if (!hasFailed && !hasFinished) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (value) {
                  if (value == 'retry_failed') {
                    queue.retryFailed();
                  } else if (value == 'clear_finished') {
                    queue.clearFinished();
                  }
                },
                itemBuilder: (context) => [
                  if (hasFailed)
                    const PopupMenuItem(
                      value: 'retry_failed',
                      child: Text('重试失败任务'),
                    ),
                  if (hasFinished)
                    const PopupMenuItem(
                      value: 'clear_finished',
                      child: Text('清理完成记录'),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: queue,
        builder: (context, _) {
          final tasks = queue.tasks;
          if (tasks.isEmpty) {
            return const _EmptyMessage(
              icon: Icons.video_file_outlined,
              text: '暂无素材处理任务',
            );
          }
          return SafeArea(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _ResourceQueueTile(queue: queue, task: tasks[index]),
            ),
          );
        },
      ),
    );
  }
}

class _ResourceQueueTile extends StatelessWidget {
  const _ResourceQueueTile({required this.queue, required this.task});

  final ResourceProcessingQueueController queue;
  final ResourceQueueTask task;

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
                  task.title,
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
                  task.status == ResourceQueueTaskStatus.failed
                      ? task.errorMessage ?? '截取失败'
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
                const SizedBox(height: 4),
                Text(
                  '${formatVideoMarkerPosition(task.request.start)} - ${formatVideoMarkerPosition(task.request.end)}',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (task.status == ResourceQueueTaskStatus.failed) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => queue.retry(task.id),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('重试'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  _QueueStatusView _statusView(ResourceQueueTaskStatus status) {
    switch (status) {
      case ResourceQueueTaskStatus.waiting:
        return const _QueueStatusView(
          label: '等待截取',
          color: _muted,
          icon: Icon(Icons.schedule_rounded, color: _muted, size: 20),
        );
      case ResourceQueueTaskStatus.running:
        return const _QueueStatusView(
          label: '截取中',
          color: _accent,
          icon: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
          ),
        );
      case ResourceQueueTaskStatus.success:
        return const _QueueStatusView(
          label: '已完成',
          color: _accent,
          icon: Icon(Icons.check_circle_rounded, color: _accent, size: 20),
        );
      case ResourceQueueTaskStatus.failed:
        return const _QueueStatusView(
          label: '截取失败',
          color: Colors.redAccent,
          icon: Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 20,
          ),
        );
    }
  }
}
