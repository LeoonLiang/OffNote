import 'dart:async';

import 'package:flutter/foundation.dart';

import 'media_download_failure.dart';
import 'saved_article.dart';

typedef SaveQueueWorker =
    Future<SavedArticle> Function(SaveQueueRequest request);

enum SaveQueueTaskStatus {
  waiting,
  running,
  needsAction,
  success,
  failed,
  cancelled,
}

class SaveQueueRequest {
  const SaveQueueRequest({required this.url, this.allowPartialMedia = false});

  final String url;
  final bool allowPartialMedia;
}

class SaveQueueTask {
  SaveQueueTask({required this.id, required this.url, required this.createdAt});

  final String id;
  final String url;
  final DateTime createdAt;
  SaveQueueTaskStatus status = SaveQueueTaskStatus.waiting;
  SavedArticle? article;
  String? errorMessage;
  String? errorDetail;
  bool canConfirmPartial = false;
  int attemptCount = 0;
  bool _allowPartialMedia = false;
}

class SaveQueueController extends ChangeNotifier {
  SaveQueueController({required SaveQueueWorker worker}) : _worker = worker;

  final SaveQueueWorker _worker;
  final _tasks = <SaveQueueTask>[];
  Completer<void>? _idleCompleter;
  bool _isProcessing = false;

  List<SaveQueueTask> get tasks => List.unmodifiable(_tasks);

  int get activeCount => _tasks
      .where(
        (task) =>
            task.status == SaveQueueTaskStatus.waiting ||
            task.status == SaveQueueTaskStatus.running,
      )
      .length;

  Future<void> get idle {
    if (!_isProcessing && activeCount == 0) {
      return Future<void>.value();
    }
    return (_idleCompleter ??= Completer<void>()).future;
  }

  SaveQueueTask enqueue(String url) {
    final task = SaveQueueTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      url: url,
      createdAt: DateTime.now(),
    );
    _tasks.insert(0, task);
    notifyListeners();
    unawaited(_process());
    return task;
  }

  void retry(String taskId) {
    final task = _findTask(taskId);
    if (task == null) {
      return;
    }
    task.status = SaveQueueTaskStatus.waiting;
    task.errorMessage = null;
    task.errorDetail = null;
    task.canConfirmPartial = false;
    task.attemptCount = 0;
    task._allowPartialMedia = false;
    notifyListeners();
    unawaited(_process());
  }

  void confirmPartial(String taskId) {
    final task = _findTask(taskId);
    if (task == null || !task.canConfirmPartial) {
      return;
    }
    task.status = SaveQueueTaskStatus.waiting;
    task.errorMessage = null;
    task.errorDetail = null;
    task.canConfirmPartial = false;
    task.attemptCount = 0;
    task._allowPartialMedia = true;
    notifyListeners();
    unawaited(_process());
  }

  void cancel(String taskId) {
    final task = _findTask(taskId);
    if (task == null) {
      return;
    }
    task.status = SaveQueueTaskStatus.cancelled;
    task.errorMessage = '已取消';
    task.errorDetail = null;
    task.canConfirmPartial = false;
    notifyListeners();
    if (activeCount == 0) {
      _completeIdle();
    }
  }

  Future<void> _process() async {
    if (_isProcessing) {
      return;
    }
    _isProcessing = true;
    try {
      while (true) {
        final task = _nextWaitingTask();
        if (task == null) {
          _completeIdle();
          return;
        }
        task.status = SaveQueueTaskStatus.running;
        task.errorMessage = null;
        task.errorDetail = null;
        task.canConfirmPartial = false;
        task.attemptCount += 1;
        notifyListeners();
        try {
          task.article = await _worker(
            SaveQueueRequest(
              url: task.url,
              allowPartialMedia: task._allowPartialMedia,
            ),
          );
          task.status = SaveQueueTaskStatus.success;
          task._allowPartialMedia = false;
        } catch (error) {
          _handleTaskError(task, error);
        }
        notifyListeners();
      }
    } finally {
      _isProcessing = false;
      if (activeCount == 0) {
        _completeIdle();
      }
    }
  }

  void _handleTaskError(SaveQueueTask task, Object error) {
    if (error is MediaDownloadIncompleteException) {
      task.errorMessage = error.summary;
      task.errorDetail = error.detail;
      if (!task._allowPartialMedia && task.attemptCount < 3) {
        task.status = SaveQueueTaskStatus.waiting;
        return;
      }
      task.status = SaveQueueTaskStatus.needsAction;
      task.canConfirmPartial = error.canConfirmPartial;
      return;
    }
    task.status = SaveQueueTaskStatus.failed;
    task.errorMessage = error.toString();
    task.errorDetail = null;
  }

  SaveQueueTask? _nextWaitingTask() {
    for (final task in _tasks.reversed) {
      if (task.status == SaveQueueTaskStatus.waiting) {
        return task;
      }
    }
    return null;
  }

  SaveQueueTask? _findTask(String taskId) {
    for (final task in _tasks) {
      if (task.id == taskId) {
        return task;
      }
    }
    return null;
  }

  void _completeIdle() {
    final completer = _idleCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _idleCompleter = null;
  }
}
