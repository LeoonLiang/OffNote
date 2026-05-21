import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'article_snapshot_store.dart';
import 'js_result_decoder.dart';
import 'link_parser.dart';
import 'saved_article.dart';
import 'web_navigation_policy.dart';

void main() {
  runApp(const OffNoteApp());
}

const _ink = Color(0xff17201a);
const _paper = Color(0xfff7f6f0);
const _line = Color(0xffddd8cc);
const _accent = Color(0xff1f7a5a);
const _accentSoft = Color(0xffdcefe6);
const _warning = Color(0xffa35c17);

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
          centerTitle: false,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _line),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _ink,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            side: const BorderSide(color: _line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OffNote',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0),
            ),
            Text(
              '保存网页快照，离线也能看',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black54,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          CapturePage(store: _store),
          LibraryPage(store: _store),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: Colors.white,
        indicatorColor: _accentSoft,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_link), label: '保存'),
          NavigationDestination(
            icon: Icon(Icons.archive_outlined),
            label: '离线',
          ),
        ],
        onDestinationSelected: (index) => setState(() => _index = index),
      ),
    );
  }
}

class CapturePage extends StatefulWidget {
  const CapturePage({super.key, required this.store});

  final ArticleSnapshotStore store;

  @override
  State<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends State<CapturePage> {
  final TextEditingController _textController = TextEditingController(
    text:
        '格木村，让我来帮你宣传好了！ 徒步格聂扎营格木村 意... http://xhslink.com/o/5ZfJTdyoUMS \n'
        '小伙伴复制一下，打开【小红书】就能看到内容。',
  );

  WebViewController? _webViewController;
  String? _parsedUrl;
  String? _message;
  _NoticeKind _messageKind = _NoticeKind.neutral;
  int _loadingProgress = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _parseOnly();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _parseOnly() {
    setState(() {
      _parsedUrl = extractFirstUrl(_textController.text);
      if (_parsedUrl == null) {
        _message = '粘贴分享文本后会自动识别链接';
        _messageKind = _NoticeKind.warning;
      } else {
        _message = null;
        _messageKind = _NoticeKind.neutral;
      }
    });
  }

  Future<void> _loadParsedUrl() async {
    final url = extractFirstUrl(_textController.text);
    if (url == null) {
      setState(() {
        _parsedUrl = null;
        _webViewController = null;
        _message = '没有识别到链接';
        _messageKind = _NoticeKind.error;
      });
      return;
    }

    setState(() {
      _message = '正在加载网页...';
      _messageKind = _NoticeKind.neutral;
      _loadingProgress = 0;
    });

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            setState(() => _loadingProgress = progress);
          },
          onPageFinished: (_) {
            setState(() {
              _loadingProgress = 100;
              _message = '网页已加载，可以保存快照';
              _messageKind = _NoticeKind.success;
            });
          },
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);
            if (shouldLoadInWebView(uri)) {
              return NavigationDecision.navigate;
            }

            setState(() {
              _message = '已拦截 App 跳转：${uri.scheme}://';
              _messageKind = _NoticeKind.warning;
            });
            return NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            setState(() {
              _message = '${error.errorCode}: ${error.description}';
              _messageKind = _NoticeKind.error;
            });
          },
        ),
      );

    final platformController = controller.platform;
    if (platformController is AndroidWebViewController) {
      await platformController.setMixedContentMode(
        MixedContentMode.alwaysAllow,
      );
    }

    await controller.loadRequest(Uri.parse(url));

    setState(() {
      _parsedUrl = url;
      _webViewController = controller;
    });
  }

  Future<void> _saveSnapshot() async {
    final controller = _webViewController;
    final sourceUrl = await controller?.currentUrl();
    if (controller == null || sourceUrl == null) {
      setState(() {
        _message = '请先加载网页';
        _messageKind = _NoticeKind.warning;
      });
      return;
    }

    setState(() {
      _saving = true;
      _message = '正在保存网页快照和图片...';
      _messageKind = _NoticeKind.neutral;
    });

    try {
      final htmlResult = await controller.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      final article = await widget.store.save(
        rawHtml: decodeJavaScriptStringResult(htmlResult),
        sourceUrl: sourceUrl,
      );
      setState(() {
        _message = '已保存：${article.title}';
        _messageKind = _NoticeKind.success;
      });
    } catch (error) {
      setState(() {
        _message = '保存失败：$error';
        _messageKind = _NoticeKind.error;
      });
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _webViewController;

    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            decoration: const BoxDecoration(
              color: _paper,
              border: Border(bottom: BorderSide(color: _line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _textController,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 14, height: 1.35),
                  decoration: const InputDecoration(
                    labelText: '分享文本或链接',
                    prefixIcon: Icon(Icons.link),
                  ),
                  onChanged: (_) => _parseOnly(),
                ),
                const SizedBox(height: 10),
                _UrlChip(url: _parsedUrl),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loadParsedUrl,
                        icon: const Icon(Icons.travel_explore),
                        label: const Text('加载网页'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _saving ? null : _saveSnapshot,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.offline_pin_outlined),
                        label: const Text('保存快照'),
                      ),
                    ),
                  ],
                ),
                if (_message != null) ...[
                  const SizedBox(height: 10),
                  _Notice(text: _message!, kind: _messageKind),
                ],
              ],
            ),
          ),
          if (controller != null && _loadingProgress < 100)
            LinearProgressIndicator(value: _loadingProgress / 100),
          Expanded(
            child: controller == null
                ? const _EmptyPreview()
                : WebViewWidget(controller: controller),
          ),
        ],
      ),
    );
  }
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key, required this.store});

  final ArticleSnapshotStore store;

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _searchController = TextEditingController();
  late Future<List<SavedArticle>> _articlesFuture;

  @override
  void initState() {
    super.initState();
    _articlesFuture = widget.store.listArticles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _articlesFuture = widget.store.searchArticles(_searchController.text);
    });
    await _articlesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: '搜索标题或正文',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _refresh(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: _refresh,
                  tooltip: '刷新列表',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SavedArticle>>(
              future: _articlesFuture,
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
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: articles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final article = articles[index];
                      return _ArticleTile(
                        article: article,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ArticleDetailPage(article: article),
                            ),
                          );
                        },
                        onDelete: () => _confirmDelete(article),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已删除：${article.title}')));
    await _refresh();
  }
}

class ArticleDetailPage extends StatefulWidget {
  const ArticleDetailPage({super.key, required this.article});

  final SavedArticle article;

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  late final WebViewController _controller;

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
        title: Text(widget.article.title, maxLines: 1),
        actions: [
          IconButton(
            onPressed: _copyHtmlToClipboard,
            tooltip: '复制 HTML',
            icon: const Icon(Icons.code),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.cloud_off_outlined),
          ),
        ],
      ),
      body: SafeArea(child: WebViewWidget(controller: _controller)),
    );
  }

  Future<void> _copyHtmlToClipboard() async {
    try {
      final html = await File(widget.article.htmlPath).readAsString();
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

class _ArticleTile extends StatelessWidget {
  const _ArticleTile({
    required this.article,
    required this.onTap,
    required this.onDelete,
  });

  final SavedArticle article;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final coverPath = article.coverPath;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: coverPath == null
                    ? const ColoredBox(
                        color: _accentSoft,
                        child: Icon(Icons.article_outlined, color: _accent),
                      )
                    : Image.file(File(coverPath), fit: BoxFit.cover),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
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
                          color: Colors.black54,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: onDelete,
                      tooltip: '删除',
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.black45,
                    ),
                    const Icon(Icons.chevron_right, color: Colors.black26),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrlChip extends StatelessWidget {
  const _UrlChip({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: hasUrl ? _accentSoft : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hasUrl ? _accent : _line),
      ),
      child: Row(
        children: [
          Icon(
            hasUrl ? Icons.check_circle : Icons.info_outline,
            size: 18,
            color: hasUrl ? _accent : Colors.black45,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasUrl ? url! : '等待识别链接',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: hasUrl ? _accent : Colors.black54,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.kind});

  final String text;
  final _NoticeKind kind;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (kind) {
      _NoticeKind.success => (_accent, Icons.check_circle_outline),
      _NoticeKind.warning => (_warning, Icons.info_outline),
      _NoticeKind.error => (
        Theme.of(context).colorScheme.error,
        Icons.error_outline,
      ),
      _NoticeKind.neutral => (_ink, Icons.hourglass_empty),
    };
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 13, height: 1.3),
          ),
        ),
      ],
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.web_asset_off_outlined, size: 44, color: Colors.black38),
            SizedBox(height: 12),
            Text(
              '先加载网页，再保存离线快照',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.archive_outlined, size: 44, color: Colors.black38),
            SizedBox(height: 12),
            Text(
              '还没有离线文章',
              style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
            ),
            SizedBox(height: 6),
            Text(
              '保存快照后，文章和图片会出现在这里。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

enum _NoticeKind { neutral, success, warning, error }
