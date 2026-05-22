import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/save_queue.dart';
import 'package:offnote/saved_article.dart';

void main() {
  SavedArticle article(String id) {
    return SavedArticle(
      id: id,
      title: '标题$id',
      content: '正文',
      htmlPath: '/tmp/$id/index.html',
      coverPath: null,
      sourceUrl: 'https://example.com/$id',
      publishedAt: DateTime.fromMillisecondsSinceEpoch(1),
      savedAt: DateTime.fromMillisecondsSinceEpoch(2),
    );
  }

  test('processes queued save tasks one by one', () async {
    final completed = <String>[];
    final queue = SaveQueueController(
      worker: (url) async {
        completed.add(url);
        return article(url);
      },
    );

    final first = queue.enqueue('https://example.com/1');
    final second = queue.enqueue('https://example.com/2');

    await queue.idle;

    expect(completed, ['https://example.com/1', 'https://example.com/2']);
    expect(first.status, SaveQueueTaskStatus.success);
    expect(second.status, SaveQueueTaskStatus.success);
    expect(first.article?.id, 'https://example.com/1');
  });

  test('marks failed tasks and continues with the next task', () async {
    final queue = SaveQueueController(
      worker: (url) async {
        if (url.endsWith('/bad')) {
          throw Exception('保存失败');
        }
        return article(url);
      },
    );

    final bad = queue.enqueue('https://example.com/bad');
    final good = queue.enqueue('https://example.com/good');

    await queue.idle;

    expect(bad.status, SaveQueueTaskStatus.failed);
    expect(bad.errorMessage, contains('保存失败'));
    expect(good.status, SaveQueueTaskStatus.success);
  });
}
