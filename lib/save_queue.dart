import 'dart:async';

import 'package:flutter/foundation.dart';

import 'saved_article.dart';

typedef SaveQueueWorker = Future<SavedArticle> Function(String url);

enum SaveQueueTaskStatus { waiting, running, success, failed }

class SaveQueueTask {
  SaveQueueTask({required this.id, required this.url, required this.createdAt});

  final String id;
  final String url;
  final DateTime createdAt;
  SaveQueueTaskStatus status = SaveQueueTaskStatus.waiting;
  SavedArticle? article;
  String? errorMessage;
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
        notifyListeners();
        try {
          task.article = await _worker(task.url);
          task.status = SaveQueueTaskStatus.success;
        } catch (error) {
          task.status = SaveQueueTaskStatus.failed;
          task.errorMessage = error.toString();
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

  SaveQueueTask? _nextWaitingTask() {
    for (final task in _tasks.reversed) {
      if (task.status == SaveQueueTaskStatus.waiting) {
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
