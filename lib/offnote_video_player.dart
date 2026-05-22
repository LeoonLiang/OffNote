import 'dart:async';

import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class OffNoteVideoSource {
  const OffNoteVideoSource({required this.videoUri, this.posterUri});

  final String videoUri;
  final String? posterUri;

  static OffNoteVideoSource? fromHtml(String html) {
    final document = html_parser.parse(html);
    final video = document.querySelector('video.video-player, video');
    final videoUri =
        video?.querySelector('source[src]')?.attributes['src'] ??
        video?.attributes['src'];
    if (videoUri == null || videoUri.trim().isEmpty) {
      return null;
    }

    final posterUri = video?.attributes['poster'];
    return OffNoteVideoSource(
      videoUri: videoUri.trim(),
      posterUri: posterUri == null || posterUri.trim().isEmpty
          ? null
          : posterUri.trim(),
    );
  }
}

Size calculateContainedVideoSize({
  required Size maxSize,
  required double aspectRatio,
}) {
  if (maxSize.width <= 0 || maxSize.height <= 0 || aspectRatio <= 0) {
    return Size.zero;
  }

  final widthFirstHeight = maxSize.width / aspectRatio;
  if (widthFirstHeight <= maxSize.height) {
    return Size(maxSize.width, widthFirstHeight);
  }
  return Size(maxSize.height * aspectRatio, maxSize.height);
}

class OffNoteVideoPlayer extends StatefulWidget {
  const OffNoteVideoPlayer({super.key, required this.source});

  final OffNoteVideoSource source;

  @override
  State<OffNoteVideoPlayer> createState() => _OffNoteVideoPlayerState();
}

class _OffNoteVideoPlayerState extends State<OffNoteVideoPlayer> {
  late final Player _player;
  late final VideoController _controller;
  final _subscriptions = <StreamSubscription<Object?>>[];
  int? _videoWidth;
  int? _videoHeight;
  double _restoreRate = 1;
  bool _isFastForwarding = false;
  Duration? _seekStartPosition;
  double? _seekOffset;

  double get _aspectRatio {
    final width = _videoWidth;
    final height = _videoHeight;
    if (width != null && height != null && width > 0 && height > 0) {
      return width / height;
    }
    return 9 / 16;
  }

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _videoWidth = _player.state.width;
    _videoHeight = _player.state.height;
    _subscriptions.addAll([
      _player.stream.width.listen((value) {
        if (mounted) {
          setState(() => _videoWidth = value);
        }
      }),
      _player.stream.height.listen((value) {
        if (mounted) {
          setState(() => _videoHeight = value);
        }
      }),
      _player.stream.rate.listen((value) {
        if (!_isFastForwarding) {
          _restoreRate = value;
        }
      }),
    ]);
    _player.open(Media(widget.source.videoUri), play: false);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        final targetSize = calculateContainedVideoSize(
          maxSize: Size(constraints.maxWidth, maxHeight),
          aspectRatio: _aspectRatio,
        );
        final playerHeight = targetSize.height == 0
            ? maxHeight
            : targetSize.height;

        return SizedBox(
          width: double.infinity,
          height: playerHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black,
                child: Video(
                  controller: _controller,
                  width: double.infinity,
                  height: playerHeight,
                  fit: BoxFit.contain,
                  fill: Colors.black,
                  controls: AdaptiveVideoControls,
                ),
              ),
              // 手势拦截层：只拦截水平拖拽和长按，点击穿透到视频控制栏
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onLongPressStart: (_) => _setFastForwarding(true),
                  onLongPressEnd: (_) => _setFastForwarding(false),
                  onLongPressCancel: () => _setFastForwarding(false),
                  onHorizontalDragStart: (details) {
                    _seekStartPosition = _player.state.position;
                    _seekOffset = 0;
                  },
                  onHorizontalDragUpdate: (details) {
                    if (_seekStartPosition == null) return;

                    setState(() {
                      _seekOffset = (_seekOffset ?? 0) + details.delta.dx;
                    });

                    // 每移动 10px = 1 秒
                    final seekSeconds = (_seekOffset ?? 0) / 10;
                    final newPosition = _seekStartPosition! + Duration(seconds: seekSeconds.round());
                    final duration = _player.state.duration;

                    // 限制在有效范围内
                    if (newPosition >= Duration.zero && newPosition <= duration) {
                      _player.seek(newPosition);
                    }
                  },
                  onHorizontalDragEnd: (_) {
                    setState(() {
                      _seekStartPosition = null;
                      _seekOffset = null;
                    });
                  },
                  onHorizontalDragCancel: () {
                    setState(() {
                      _seekStartPosition = null;
                      _seekOffset = null;
                    });
                  },
                ),
              ),
              if (_isFastForwarding)
                const Positioned(
                  top: 14,
                  right: 14,
                  child: _FastForwardBadge(),
                ),
              if (_seekOffset != null)
                Positioned(
                  top: 14,
                  left: 14,
                  child: _SeekIndicator(
                    offset: _seekOffset!,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _setFastForwarding(bool value) async {
    if (_isFastForwarding == value) {
      return;
    }
    setState(() => _isFastForwarding = value);
    if (value) {
      _restoreRate = _player.state.rate;
      await _player.setRate(3);
    } else {
      await _player.setRate(_restoreRate);
    }
  }
}

class _FastForwardBadge extends StatelessWidget {
  const _FastForwardBadge();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          '3x',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SeekIndicator extends StatelessWidget {
  const _SeekIndicator({required this.offset});

  final double offset;

  @override
  Widget build(BuildContext context) {
    final seconds = (offset / 10).round();
    final isForward = seconds > 0;
    final absSeconds = seconds.abs();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isForward ? Icons.fast_forward : Icons.fast_rewind,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '${isForward ? '+' : '-'}${absSeconds}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
