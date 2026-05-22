part of '../main.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.store, required this.onChanged});

  final ArticleSnapshotStore store;
  final VoidCallback onChanged;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<SavedArticle> _results = const [];
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final results = await widget.store.listArticles();
    if (mounted) {
      setState(() {
        _results = results;
        _isInitialLoad = false;
      });
    }
  }

  void _onQueryChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _runSearch);
  }

  Future<void> _runSearch() async {
    final results = await widget.store.searchArticles(_controller.text);
    if (mounted) setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _controller.text.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: ShadInput(
                controller: _controller,
                autofocus: true,
                placeholder: const Text('搜索标题或正文'),
                leading: const Icon(LucideIcons.search, size: 18),
                onChanged: _onQueryChanged,
              ),
            ),
            Expanded(
              child: _isInitialLoad
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                  ? _EmptyMessage(
                      icon: hasQuery
                          ? Icons.search_off_rounded
                          : Icons.bookmarks_outlined,
                      text: hasQuery ? '没有找到相关内容' : '还没有保存任何文章',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _ArticleTile(
                        article: _results[index],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ArticleDetailPage(
                              article: _results[index],
                              store: widget.store,
                              onChanged: widget.onChanged,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
