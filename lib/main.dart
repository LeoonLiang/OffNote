import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'article_snapshot_store.dart';
import 'js_result_decoder.dart';
import 'link_parser.dart';
import 'saved_article.dart';
import 'saved_category.dart';
import 'web_navigation_policy.dart';

void main() {
  runApp(const OffNoteApp());
}

const _ink = Color(0xff1f241f);
const _paper = Color(0xfff7f7f3);
const _accent = Color(0xff49b866);
const _accentSoft = Color(0xffe6f5ea);
const _muted = Color(0xff777b76);
const _folderColors = [
  0xfff5b744,
  0xff4e9ff4,
  0xff51b96b,
  0xffff6b6b,
  0xff8c7cf6,
  0xffff9650,
];

class OffNoteApp extends StatelessWidget {
  const OffNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OffNote',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _paper,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.light,
          surface: _paper,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _paper,
          foregroundColor: _ink,
          centerTitle: true,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _store = ArticleSnapshotStore();
  int _index = 0;
  int _refreshTick = 0;

  void _refresh() => setState(() => _refreshTick++);

  Future<void> _openSaveDialog() async {
    final article = await showDialog<SavedArticle>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SaveArticleDialog(store: _store),
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
      ),
      CategoryPage(
        key: ValueKey('category-$_refreshTick'),
        store: _store,
        onChanged: _refresh,
      ),
      SearchPage(
        key: ValueKey('search-$_refreshTick'),
        store: _store,
        onChanged: _refresh,
      ),
      const ProfilePage(),
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
              _NavItem(
                selected: _index == 1,
                icon: Icons.folder_rounded,
                label: '分类',
                onTap: () => setState(() => _index = 1),
              ),
              const SizedBox(width: 56),
              _NavItem(
                selected: _index == 2,
                icon: Icons.search_rounded,
                label: '搜索',
                onTap: () => setState(() => _index = 2),
              ),
              _NavItem(
                selected: _index == 3,
                icon: Icons.person_outline_rounded,
                label: '我的',
                onTap: () => setState(() => _index = 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SaveArticleDialog extends StatefulWidget {
  const SaveArticleDialog({super.key, required this.store});

  final ArticleSnapshotStore store;

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
  WebViewController? _controller;
  Completer<void>? _pageLoaded;
  String? _message;
  bool _saving = false;

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
      _controller = controller;
      _pageLoaded = Completer<void>();
      await controller.loadRequest(Uri.parse(url));
      await _pageLoaded!.future.timeout(const Duration(seconds: 35));
      final sourceUrl = await controller.currentUrl() ?? url;
      _setStep(1, _StepState.done);

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
        _message = '保存失败：$error';
        _saving = false;
      });
    }
  }

  Future<WebViewController> _createController() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
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
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text('保存网页'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _textController,
              enabled: !_saving,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '粘贴小红书分享文本或网页链接',
                prefixIcon: Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 16),
            ..._steps.map((step) => _ProgressRow(step: step)),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!, style: const TextStyle(color: Colors.redAccent)),
            ],
            if (_controller != null)
              SizedBox.square(
                dimension: 1,
                child: Opacity(
                  opacity: 0.01,
                  child: WebViewWidget(controller: _controller!),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.bookmark_add_rounded),
          label: const Text('保存'),
        ),
      ],
    );
  }
}

class ArticleListPage extends StatefulWidget {
  const ArticleListPage({
    super.key,
    required this.title,
    required this.store,
    required this.onChanged,
    this.category,
  });

  final String title;
  final ArticleSnapshotStore store;
  final SavedCategory? category;
  final VoidCallback onChanged;

  @override
  State<ArticleListPage> createState() => _ArticleListPageState();
}

class _ArticleListPageState extends State<ArticleListPage> {
  late Future<List<SavedArticle>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SavedArticle>> _load() {
    final category = widget.category;
    if (category != null) {
      return widget.store.listArticlesByCategory(category.id);
    }
    return widget.store.listArticles();
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<SavedArticle>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final articles = snapshot.data ?? const <SavedArticle>[];
            if (articles.isEmpty) {
              return const _EmptyLibrary();
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                itemCount: articles.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _ArticleTile(
                  article: articles[index],
                  onTap: () => _openArticle(articles[index]),
                  onDelete: () => _confirmDelete(articles[index]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openArticle(SavedArticle article) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ArticleDetailPage(
          article: article,
          store: widget.store,
          onChanged: () {
            widget.onChanged();
            _refresh();
          },
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _confirmDelete(SavedArticle article) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除离线文章'),
        content: Text('确定删除「${article.title}」吗？本地 HTML 和图片也会一起删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await widget.store.deleteArticle(article);
    widget.onChanged();
    await _refresh();
  }
}

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key, required this.store, required this.onChanged});

  final ArticleSnapshotStore store;
  final VoidCallback onChanged;

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  late Future<List<SavedCategory>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.store.listCategories();
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.store.listCategories());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '分类管理',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(onPressed: _createCategory, child: const Text('新建')),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<SavedCategory>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final categories = snapshot.data ?? const <SavedCategory>[];
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                OutlinedButton.icon(
                  onPressed: _createCategory,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('新建文件夹'),
                ),
                const SizedBox(height: 12),
                if (categories.isEmpty)
                  const _EmptyMessage(
                    icon: Icons.folder_open_rounded,
                    text: '还没有分类文件夹',
                  ),
                ...categories.map(
                  (category) => _CategoryTile(
                    category: category,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ArticleListPage(
                          title: category.name,
                          category: category,
                          store: widget.store,
                          onChanged: widget.onChanged,
                        ),
                      ),
                    ),
                    onRename: () => _renameCategory(category),
                    onDelete: () => _deleteCategory(category),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _createCategory() async {
    final name = await _askName(title: '新建文件夹', initialValue: '');
    if (name == null || name.trim().isEmpty) {
      return;
    }
    final color =
        _folderColors[DateTime.now().millisecond % _folderColors.length];
    await widget.store.createCategory(name, color);
    widget.onChanged();
    await _refresh();
  }

  Future<void> _renameCategory(SavedCategory category) async {
    final name = await _askName(title: '重命名文件夹', initialValue: category.name);
    if (name == null || name.trim().isEmpty) {
      return;
    }
    await widget.store.renameCategory(category.id, name);
    widget.onChanged();
    await _refresh();
  }

  Future<void> _deleteCategory(SavedCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('删除「${category.name}」后，文章会变为未分类。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await widget.store.deleteCategory(category.id);
    widget.onChanged();
    await _refresh();
  }

  Future<String?> _askName({
    required String title,
    required String initialValue,
  }) {
    final controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '文件夹名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.store, required this.onChanged});

  final ArticleSnapshotStore store;
  final VoidCallback onChanged;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  late Future<List<SavedArticle>> _future = widget.store.listArticles();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() =>
      setState(() => _future = widget.store.searchArticles(_controller.text));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: '搜索标题或正文',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => _search(),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<SavedArticle>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final articles = snapshot.data ?? const <SavedArticle>[];
                  if (articles.isEmpty) {
                    return const _EmptyMessage(
                      icon: Icons.search_off_rounded,
                      text: '没有找到相关内容',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: articles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _ArticleTile(
                      article: articles[index],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ArticleDetailPage(
                            article: articles[index],
                            store: widget.store,
                            onChanged: widget.onChanged,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ArticleDetailPage extends StatefulWidget {
  const ArticleDetailPage({
    super.key,
    required this.article,
    required this.store,
    required this.onChanged,
  });

  final SavedArticle article;
  final ArticleSnapshotStore store;
  final VoidCallback onChanged;

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  late final WebViewController _controller;
  late SavedArticle _article = widget.article;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadFile(widget.article.htmlPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_article.title, maxLines: 1),
        actions: [
          IconButton(
            onPressed: _chooseCategory,
            tooltip: '分类',
            icon: const Icon(Icons.sell_outlined),
          ),
          IconButton(
            onPressed: _copyHtmlToClipboard,
            tooltip: '复制 HTML',
            icon: const Icon(Icons.code),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.cloud_off_outlined, color: _accent),
          ),
        ],
      ),
      body: SafeArea(child: WebViewWidget(controller: _controller)),
    );
  }

  Future<void> _chooseCategory() async {
    final categories = await widget.store.listCategories();
    if (!mounted) {
      return;
    }
    const uncategorizedValue = '__offnote_uncategorized__';
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                '选择分类',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: Icon(
                _article.categoryId == null
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: _article.categoryId == null ? _accent : Colors.black26,
              ),
              title: const Text('未分类'),
              onTap: () => Navigator.of(context).pop(uncategorizedValue),
            ),
            ...categories.map(
              (category) => ListTile(
                leading: Icon(
                  Icons.folder_rounded,
                  color: Color(category.color),
                ),
                title: Text(category.name),
                trailing: _article.categoryId == category.id
                    ? const Icon(Icons.check_rounded, color: _accent)
                    : null,
                onTap: () => Navigator.of(context).pop(category.id),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null) {
      return;
    }
    final categoryId = selected == uncategorizedValue ? null : selected;
    if (categoryId == _article.categoryId) {
      return;
    }
    await widget.store.assignArticleCategory(_article.id, categoryId);
    setState(() => _article = _article.copyWith(categoryId: categoryId));
    widget.onChanged();
  }

  Future<void> _copyHtmlToClipboard() async {
    try {
      final html = await File(_article.htmlPath).readAsString();
      await Clipboard.setData(ClipboardData(text: html));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已复制 HTML：${html.length} 字符')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('复制失败：$error')));
    }
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: const _EmptyMessage(
        icon: Icons.lock_outline_rounded,
        text: '数据仅保存在本地',
      ),
    );
  }
}

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({
    required this.article,
    required this.onTap,
    this.onDelete,
  });

  final SavedArticle article;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final coverPath = article.coverPath;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 86,
                  height: 76,
                  child: coverPath == null
                      ? const ColoredBox(
                          color: _accentSoft,
                          child: Icon(Icons.article_outlined, color: _accent),
                        )
                      : Image.file(File(coverPath), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _dateLabel(article.createdAt),
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  tooltip: '删除',
                  icon: const Icon(Icons.delete_outline_rounded),
                  color: Colors.black38,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  final SavedCategory category;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            if (value == 'rename') {
              onRename();
            } else if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'rename', child: Text('重命名')),
            PopupMenuItem(value: 'delete', child: Text('删除')),
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
    final icon = switch (step.state) {
      _StepState.waiting => Icons.radio_button_unchecked_rounded,
      _StepState.running => Icons.downloading_rounded,
      _StepState.done => Icons.check_circle_rounded,
    };
    final color = switch (step.state) {
      _StepState.waiting => Colors.black26,
      _StepState.running => _accent,
      _StepState.done => _accent,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            step.label,
            style: TextStyle(color: color == _accent ? _ink : _muted),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 54,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: selected ? _accent : _muted),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected ? _accent : _muted,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return const _EmptyMessage(icon: Icons.archive_outlined, text: '还没有离线文章');
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: Colors.black38),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
            ),
          ],
        ),
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

String _dateLabel(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
