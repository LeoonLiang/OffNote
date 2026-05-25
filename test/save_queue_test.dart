import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/media_download_failure.dart';
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
      worker: (request) async {
        completed.add(request.url);
        return article(request.url);
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
      worker: (request) async {
        if (request.url.endsWith('/bad')) {
          throw Exception('保存失败');
        }
        return article(request.url);
      },
    );

    final bad = queue.enqueue('https://example.com/bad');
    final good = queue.enqueue('https://example.com/good');

    await queue.idle;

    expect(bad.status, SaveQueueTaskStatus.failed);
    expect(bad.errorMessage, contains('保存失败'));
    expect(good.status, SaveQueueTaskStatus.success);
  });

  test('waits for user action after three incomplete image attempts', () async {
    var attempts = 0;
    final queue = SaveQueueController(
      worker: (request) async {
        attempts++;
        throw const MediaDownloadIncompleteException.images(
          failedCount: 1,
          totalCount: 15,
          reasons: ['第 3 张图片下载超时'],
        );
      },
    );

    final task = queue.enqueue('https://example.com/images');

    await queue.idle;

    expect(attempts, 3);
    expect(task.status, SaveQueueTaskStatus.needsAction);
    expect(task.errorMessage, contains('1/15 张图片保存失败'));
    expect(task.errorDetail, contains('第 3 张图片下载超时'));
    expect(task.canConfirmPartial, isTrue);
  });

  test(
    'confirming incomplete images saves with partial media allowed',
    () async {
      final allowPartialValues = <bool>[];
      final queue = SaveQueueController(
        worker: (request) async {
          allowPartialValues.add(request.allowPartialMedia);
          if (!request.allowPartialMedia) {
            throw const MediaDownloadIncompleteException.images(
              failedCount: 1,
              totalCount: 15,
            );
          }
          return article('partial');
        },
      );

      final task = queue.enqueue('https://example.com/images');
      await queue.idle;

      queue.confirmPartial(task.id);
      await queue.idle;

      expect(allowPartialValues, [false, false, false, true]);
      expect(task.status, SaveQueueTaskStatus.success);
      expect(task.article?.id, 'partial');
    },
  );

  test(
    'incomplete videos can be retried or cancelled but not confirmed',
    () async {
      final queue = SaveQueueController(
        worker: (_) async {
          throw const MediaDownloadIncompleteException.video(reason: '视频下载超时');
        },
      );

      final task = queue.enqueue('https://example.com/video');
      await queue.idle;

      expect(task.status, SaveQueueTaskStatus.needsAction);
      expect(task.errorMessage, contains('视频保存失败'));
      expect(task.errorDetail, contains('视频下载超时'));
      expect(task.canConfirmPartial, isFalse);

      queue.cancel(task.id);

      expect(task.status, SaveQueueTaskStatus.cancelled);
    },
  );
}
