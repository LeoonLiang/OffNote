part of '../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _store = ArticleSnapshotStore();
  int _index = 0;
  int _refreshTick = 0;
  String? _lastClipboard;
  String? _lastSharedText;
  StreamSubscription<List<SharedMediaFile>>? _shareSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
    _shareSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedMedia,
      onError: (Object error) {
        debugPrint('Receive share stream failed: $error');
      },
    );
    _loadInitialSharedMedia();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkClipboard();
  }

  void _refresh() => setState(() => _refreshTick++);

  bool _isXhsUrl(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    return host == 'xhslink.com' ||
        host == 'xiaohongshu.com' ||
        host.endsWith('.xiaohongshu.com');
  }

  Future<void> _checkClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || text == _lastClipboard) return;
    final url = extractFirstUrl(text);
    if (url == null || !_isXhsUrl(url)) return;
    if (!mounted) return;
    _lastClipboard = text;
    _showClipboardPrompt(text);
  }

  Future<void> _loadInitialSharedMedia() async {
    try {
      final media = await ReceiveSharingIntent.instance.getInitialMedia();
      await _handleSharedMedia(media);
      await ReceiveSharingIntent.instance.reset();
    } catch (error) {
      debugPrint('Load initial shared media failed: $error');
    }
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> media) async {
    final text = _textFromSharedMedia(media);
    if (text == null || text == _lastSharedText) {
      return;
    }
    final url = extractFirstUrl(text);
    if (url == null || !_isXhsUrl(url)) {
      return;
    }
    if (!mounted) {
      return;
    }
    _lastSharedText = text;
    await _openSaveDialog(initialText: text);
  }

  String? _textFromSharedMedia(List<SharedMediaFile> media) {
    for (final file in media) {
      final candidates = [file.message, file.path];
      for (final candidate in candidates) {
        final text = candidate?.trim();
        if (text != null && text.isNotEmpty && extractFirstUrl(text) != null) {
          return text;
        }
      }
    }
    return null;
  }

  void _showClipboardPrompt(String clipText) {
    showShadDialog<void>(
      context: context,
      builder: (_) => ShadDialog.alert(
        title: const Text('检测到小红书链接'),
        description: const Text('发现剪贴板中有小红书内容，是否直接保存？'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('忽略'),
          ),
          ShadButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openSaveDialog(initialText: clipText);
            },
            child: const Text('立即保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSaveDialog({String? initialText}) async {
    final article = await showShadDialog<SavedArticle>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          SaveArticleDialog(store: _store, initialText: initialText),
    );
    if (article == null || !mounted) {
      return;
    }
    _refresh();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArticleDetailPage(
          article: article,
          store: _store,
          onChanged: _refresh,
        ),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ArticleListPage(
        key: ValueKey('home-$_refreshTick'),
        title: '全部文章',
        store: _store,
        onChanged: _refresh,
        searchable: true,
      ),
      CategoryPage(
        key: ValueKey('category-$_refreshTick'),
        store: _store,
        onChanged: _refresh,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: FloatingActionButton(
        onPressed: _openSaveDialog,
        shape: const CircleBorder(),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 12,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                selected: _index == 0,
                icon: Icons.home_rounded,
                label: '首页',
                onTap: () => setState(() => _index = 0),
              ),
              const SizedBox(width: 56),
              _NavItem(
                selected: _index == 1,
                icon: Icons.folder_rounded,
                label: '分类',
                onTap: () => setState(() => _index = 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
