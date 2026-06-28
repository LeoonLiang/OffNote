import 'dart:async';

import 'package:flutter/foundation.dart';

import 'article_snapshot_store.dart';
import 'saved_resource.dart';

typedef ResourceQueueChanged = void Function();

enum ResourceQueueTaskStatus { waiting, running, success, failed }

class VideoClipQueueRequest {
  const VideoClipQueueRequest({
    required this.articleId,
    required this.videoPath,
    required this.previewPath,
    required this.title,
    required this.note,
    required this.start,
    required this.end,
    required this.tagIds,
  });

  final String articleId;
  final String videoPath;
  final String? previewPath;
  final String title;
  final String note;
  final Duration start;
  final Duration end;
  final Set<String> tagIds;
}

class ResourceQueueTask {
  ResourceQueueTask({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.request,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final VideoClipQueueRequest request;
  ResourceQueueTaskStatus status = ResourceQueueTaskStatus.waiting;
  SavedResource? resource;
  String? errorMessage;
  int attemptCount = 0;
}

class ResourceProcessingQueueController extends ChangeNotifier {
  ResourceProcessingQueueController({
    required ArticleSnapshotStore store,
    ResourceQueueChanged? onChanged,
  }) : _store = store,
       _onChanged = onChanged;

  final ArticleSnapshotStore _store;
  final ResourceQueueChanged? _onChanged;
  final _tasks = <ResourceQueueTask>[];
  bool _isProcessing = false;

  List<ResourceQueueTask> get tasks => List.unmodifiable(_tasks);

  int get activeCount => _tasks
      .where(
        (task) =>
            task.status == ResourceQueueTaskStatus.waiting ||
            task.status == ResourceQueueTaskStatus.running,
      )
      .length;

  bool get hasFailed =>
      _tasks.any((task) => task.status == ResourceQueueTaskStatus.failed);

  ResourceQueueTask enqueueVideoClip(VideoClipQueueRequest request) {
    final task = ResourceQueueTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: request.title,
      createdAt: DateTime.now(),
      request: request,
    );
    _tasks.insert(0, task);
    notifyListeners();
    _onChanged?.call();
    unawaited(_process());
    return task;
  }

  ResourceQueueTask retryResource(SavedResource resource, Set<String> tagIds) {
    final originalSourcePath = resource.originalSourcePath;
    final start = resource.start;
    final end = resource.end;
    if (originalSourcePath == null || start == null || end == null) {
      throw ArgumentError('Resource is missing source information.');
    }
    final task = ResourceQueueTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: resource.title,
      createdAt: DateTime.now(),
      request: VideoClipQueueRequest(
        articleId: resource.articleId,
        videoPath: originalSourcePath,
        previewPath: resource.previewPath,
        title: resource.title,
        note: resource.note,
        start: start,
        end: end,
        tagIds: tagIds,
      ),
    )..resource = resource;
    _tasks.insert(0, task);
    notifyListeners();
    _onChanged?.call();
    unawaited(_process());
    return task;
  }

  void retry(String taskId) {
    final task = _findTask(taskId);
    if (task == null) {
      return;
    }
    _resetForRetry(task);
    notifyListeners();
    _onChanged?.call();
    unawaited(_process());
  }

  void retryFailed() {
    var changed = false;
    for (final task in _tasks) {
      if (task.status != ResourceQueueTaskStatus.failed) {
        continue;
      }
      _resetForRetry(task);
      changed = true;
    }
    if (!changed) {
      return;
    }
    notifyListeners();
    _onChanged?.call();
    unawaited(_process());
  }

  void clearFinished() {
    final before = _tasks.length;
    _tasks.removeWhere(
      (task) =>
          task.status == ResourceQueueTaskStatus.success ||
          task.status == ResourceQueueTaskStatus.failed,
    );
    if (_tasks.length == before) {
      return;
    }
    notifyListeners();
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
          return;
        }
        task.status = ResourceQueueTaskStatus.running;
        task.errorMessage = null;
        task.attemptCount += 1;
        notifyListeners();
        _onChanged?.call();
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 200),
            () => _onChanged?.call(),
          ),
        );
        try {
          final existingResource = task.resource;
          task.resource = existingResource == null
              ? await _store.createVideoClipResource(
                  articleId: task.request.articleId,
                  videoPath: task.request.videoPath,
                  previewPath: task.request.previewPath,
                  title: task.request.title,
                  note: task.request.note,
                  start: task.request.start,
                  end: task.request.end,
                  tagIds: task.request.tagIds,
                )
              : await _store.retryVideoClipResource(existingResource);
          task.status = ResourceQueueTaskStatus.success;
        } on VideoClipProcessingException catch (error) {
          task.resource = error.resource;
          task.status = ResourceQueueTaskStatus.failed;
          task.errorMessage = error.message;
        } catch (error) {
          task.status = ResourceQueueTaskStatus.failed;
          task.errorMessage = error.toString();
        }
        notifyListeners();
        _onChanged?.call();
      }
    } finally {
      _isProcessing = false;
    }
  }

  ResourceQueueTask? _nextWaitingTask() {
    for (final task in _tasks.reversed) {
      if (task.status == ResourceQueueTaskStatus.waiting) {
        return task;
      }
    }
    return null;
  }

  ResourceQueueTask? _findTask(String taskId) {
    for (final task in _tasks) {
      if (task.id == taskId) {
        return task;
      }
    }
    return null;
  }

  void _resetForRetry(ResourceQueueTask task) {
    task.status = ResourceQueueTaskStatus.waiting;
    task.errorMessage = null;
    task.resource = null;
    task.attemptCount = 0;
  }
}
