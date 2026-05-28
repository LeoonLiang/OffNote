part of 'main.dart';

class SaveArticleDialog extends StatefulWidget {
  const SaveArticleDialog({super.key, required this.queue, this.initialText});

  final SaveQueueController queue;
  final String? initialText;

  @override
  State<SaveArticleDialog> createState() => _SaveArticleDialogState();
}

class _SaveArticleDialogState extends State<SaveArticleDialog> {
  final _textController = TextEditingController();
  String? _message;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialText;
    if (initial != null && initial.isNotEmpty) {
      _textController.text = initial;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      final urls = supportedXhsUrls(extractUrls(_textController.text));
      if (urls.isEmpty) {
        throw Exception('没有识别到链接');
      }
      for (final url in urls) {
        widget.queue.enqueue(url);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(urls.length);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = describeSaveFailure(error);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      title: const Text('加入收录队列'),
      description: const Text('链接会在后台解析并保存，多个链接会依次排队处理。'),
      closeIcon: ShadIconButton.ghost(
        enabled: !_saving,
        icon: const Icon(LucideIcons.x),
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
      ),
      constraints: const BoxConstraints(maxWidth: 480),
      radius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(24),
      gap: 16,
      child: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShadTextarea(
              controller: _textController,
              enabled: !_saving,
              placeholder: const Text('粘贴小红书分享文本或网页链接'),
              minHeight: 80,
              maxHeight: 116,
              resizable: false,
              leading: const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(LucideIcons.link, size: 16),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _paper,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const _QueueHintRow(),
                  if (_message != null) ...[
                    const Divider(
                      height: 18,
                      thickness: 1,
                      color: Color(0xffe8ebe2),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 1),
                          child: Icon(
                            LucideIcons.circleAlert,
                            size: 13,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _message!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ShadButton.outline(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    height: 44,
                    enabled: !_saving,
                    width: double.infinity,
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ShadButton(
                    onPressed: _saving ? null : _save,
                    enabled: !_saving,
                    height: 44,
                    width: double.infinity,
                    leading: _saving
                        ? const SizedBox.square(
                            dimension: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(LucideIcons.listPlus, size: 16),
                    child: Text(_saving ? '入队中...' : '加入队列'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueHintRow extends StatelessWidget {
  const _QueueHintRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(LucideIcons.listChecks, size: 16, color: _accent),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            '大图和视频会排队下载，不用停在这个窗口等待。',
            style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }
}
