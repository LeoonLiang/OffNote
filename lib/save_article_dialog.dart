part of 'main.dart';

class SaveArticleDialog extends StatefulWidget {
  const SaveArticleDialog({super.key, required this.store, this.initialText});

  final ArticleSnapshotStore store;
  final String? initialText;

  @override
  State<SaveArticleDialog> createState() => _SaveArticleDialogState();
}

class _SaveArticleDialogState extends State<SaveArticleDialog> {
  final _textController = TextEditingController();
  final _steps = <_SaveStep>[
    _SaveStep('识别链接'),
    _SaveStep('加载网页'),
    _SaveStep('提取正文'),
    _SaveStep('下载图片'),
    _SaveStep('保存到本地'),
  ];
  Completer<void>? _pageLoaded;
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

  void _setStep(int index, _StepState state) {
    if (!mounted) {
      return;
    }
    setState(() => _steps[index].state = state);
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    for (final step in _steps) {
      step.state = _StepState.waiting;
    }
    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      _setStep(0, _StepState.running);
      final url = extractFirstUrl(_textController.text);
      if (url == null) {
        throw Exception('没有识别到链接');
      }
      _setStep(0, _StepState.done);

      _setStep(1, _StepState.running);
      final controller = await _createController();
      _pageLoaded = Completer<void>();
      await controller.loadRequest(Uri.parse(url));
      await _pageLoaded!.future.timeout(const Duration(seconds: 35));
      setState(() => _message = '网页已打开，正在等待正文和图片渲染完整...');
      await _waitForSnapshotReady(controller);
      final sourceUrl = await controller.currentUrl() ?? url;
      _setStep(1, _StepState.done);
      setState(() => _message = '网页内容已就绪，正在生成离线快照...');

      _setStep(2, _StepState.running);
      final htmlResult = await controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      final html = decodeJavaScriptStringResult(htmlResult);
      _setStep(2, _StepState.done);

      _setStep(3, _StepState.running);
      _setStep(4, _StepState.running);
      final article = await widget.store.save(
        rawHtml: html,
        sourceUrl: sourceUrl,
      );
      _setStep(3, _StepState.done);
      _setStep(4, _StepState.done);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(article);
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

  Future<void> _waitForSnapshotReady(WebViewController controller) async {
    final deadline = DateTime.now().add(const Duration(seconds: 18));
    Object? lastResult;
    while (DateTime.now().isBefore(deadline)) {
      lastResult = await controller.runJavaScriptReturningResult(
        snapshotReadyProbeScript,
      );
      if (decodeSnapshotReadinessResult(lastResult)) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw TimeoutException('网页内容还没加载完成，请稍后重试');
  }

  Future<WebViewController> _createController() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (_) {},
          onPageFinished: (_) {
            if (_pageLoaded?.isCompleted == false) {
              _pageLoaded?.complete();
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);
            return shouldLoadInWebView(uri)
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (_pageLoaded?.isCompleted == false &&
                error.isForMainFrame == true) {
              _pageLoaded?.completeError(error.description);
            }
          },
        ),
      );
    final platformController = controller.platform;
    if (platformController is AndroidWebViewController) {
      await platformController.setMixedContentMode(
        MixedContentMode.alwaysAllow,
      );
    }
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      title: const Text('保存网页'),
      description: const Text('网页将被转为离线快照永久保存到本地。'),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _paper,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  ..._steps.map((step) => _ProgressRow(step: step)),
                  if (_message != null) ...[
                    const Divider(
                      height: 18,
                      thickness: 1,
                      color: Color(0xffe8ebe2),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            _message!.startsWith('保存失败')
                                ? LucideIcons.circleAlert
                                : LucideIcons.info,
                            size: 13,
                            color: _message!.startsWith('保存失败')
                                ? Colors.redAccent
                                : _muted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _message!,
                            style: TextStyle(
                              color: _message!.startsWith('保存失败')
                                  ? Colors.redAccent
                                  : _muted,
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
                        : const Icon(LucideIcons.bookMarked, size: 16),
                    child: Text(_saving ? '保存中...' : '解析并保存'),
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

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.step});

  final _SaveStep step;

  @override
  Widget build(BuildContext context) {
    final isDone = step.state == _StepState.done;
    final isRunning = step.state == _StepState.running;
    final isWaiting = step.state == _StepState.waiting;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isRunning ? _accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 18,
            child: isRunning
                ? CircularProgressIndicator(strokeWidth: 2, color: _accent)
                : Icon(
                    isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 18,
                    color: isDone ? _accent : const Color(0xffc8cbc1),
                  ),
          ),
          const SizedBox(width: 10),
          Text(
            step.label,
            style: TextStyle(
              fontSize: 13.5,
              color: isWaiting ? const Color(0xffb0b5ae) : _ink,
              fontWeight: isRunning ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveStep {
  _SaveStep(this.label);

  final String label;
  _StepState state = _StepState.waiting;
}

enum _StepState { waiting, running, done }
