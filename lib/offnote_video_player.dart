import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'video_marker.dart';

const offNoteVideoAutoPlayOnOpen = true;

typedef VideoMarkerCreateCallback =
    Future<void> Function(Duration position, String note);
typedef VideoMarkerUpdateCallback =
    Future<void> Function(VideoMarker marker, Duration position, String note);
typedef VideoMarkerDeleteCallback = Future<void> Function(VideoMarker marker);

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

double calculateVideoPlayerHeight({
  required double availableHeight,
  required bool isContentExpanded,
}) {
  if (!isContentExpanded) {
    return availableHeight;
  }
  return availableHeight * 0.53;
}

double calculateCollapsedContentLeadingPadding(bool hasMarkerEntry) {
  return 16;
}

Alignment calculateVideoMarkerEntryAlignment() {
  return Alignment.centerRight;
}

String formatVideoMarkerPosition(Duration position) {
  final totalSeconds = position.inSeconds < 0 ? 0 : position.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final minuteText = minutes.toString().padLeft(2, '0');
  final secondText = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minuteText:$secondText';
  }
  return '$minuteText:$secondText';
}

bool shouldShowVideoMarkerHourField(Duration videoDuration) {
  return videoDuration.inHours > 0;
}

Duration? parseVideoMarkerPositionFields({
  String? hours,
  required String minutes,
  required String seconds,
}) {
  final hourText = hours?.trim();
  final minuteText = minutes.trim();
  final secondText = seconds.trim();
  final parsedHours = hourText == null || hourText.isEmpty
      ? 0
      : int.tryParse(hourText);
  final parsedMinutes = int.tryParse(minuteText);
  final parsedSeconds = int.tryParse(secondText);
  if (parsedHours == null || parsedMinutes == null || parsedSeconds == null) {
    return null;
  }
  if (parsedHours < 0 ||
      parsedMinutes < 0 ||
      parsedMinutes > 59 ||
      parsedSeconds < 0 ||
      parsedSeconds > 59) {
    return null;
  }
  return Duration(
    hours: parsedHours,
    minutes: parsedMinutes,
    seconds: parsedSeconds,
  );
}

Duration clampVideoMarkerSeekPosition(
  Duration position, {
  required Duration duration,
}) {
  if (position < Duration.zero) {
    return Duration.zero;
  }
  if (duration > Duration.zero && position > duration) {
    return duration;
  }
  return position;
}

class OffNoteVideoPlayer extends StatefulWidget {
  const OffNoteVideoPlayer({
    super.key,
    required this.source,
    this.markers = const [],
    this.hasCollapsedContentPreview = false,
    this.onCreateMarker,
    this.onUpdateMarker,
    this.onDeleteMarker,
  });

  final OffNoteVideoSource source;
  final List<VideoMarker> markers;
  final bool hasCollapsedContentPreview;
  final VideoMarkerCreateCallback? onCreateMarker;
  final VideoMarkerUpdateCallback? onUpdateMarker;
  final VideoMarkerDeleteCallback? onDeleteMarker;

  @override
  State<OffNoteVideoPlayer> createState() => _OffNoteVideoPlayerState();
}

class _OffNoteVideoPlayerState extends State<OffNoteVideoPlayer> {
  late final Player _player;
  late final VideoController _controller;
  final _subscriptions = <StreamSubscription<Object?>>[];
  final _markerOverlayRevision = ValueNotifier(0);
  double _restoreRate = 1;
  bool _isFastForwarding = false;
  bool _isMarkerPanelOpen = false;
  bool _isSavingMarker = false;
  VideoMarker? _editingMarker;
  Duration? _editingPosition;
  TextEditingController? _markerEditorController;
  Duration? _seekStartPosition;
  double? _seekOffset;

  bool get _hasMarkerActions =>
      widget.onCreateMarker != null &&
      widget.onUpdateMarker != null &&
      widget.onDeleteMarker != null;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _subscriptions.addAll([
      _player.stream.rate.listen((value) {
        if (!_isFastForwarding) {
          _restoreRate = value;
        }
      }),
      _player.stream.duration.listen((_) => _bumpMarkerOverlay()),
    ]);
    _player.open(
      Media(widget.source.videoUri),
      play: offNoteVideoAutoPlayOnOpen,
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _markerEditorController?.dispose();
    _markerOverlayRevision.dispose();
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
        final playerHeight = maxHeight;

        return SizedBox(
          width: double.infinity,
          height: playerHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Colors.black,
                child: MaterialVideoControlsTheme(
                  normal: kDefaultMaterialVideoControlsThemeData.copyWith(
                    visibleOnMount: true,
                    controlsHoverDuration: const Duration(days: 365),
                    controlsTransitionDuration: Duration.zero,
                    backdropColor: Colors.transparent,
                    seekBarAlignment: Alignment.bottomCenter,
                    seekBarColor: const Color(0x55ffffff),
                    seekBarBufferColor: const Color(0x66ffffff),
                    seekBarPositionColor: Colors.white,
                    seekBarThumbColor: Colors.white,
                  ),
                  fullscreen: kDefaultMaterialVideoControlsThemeDataFullscreen
                      .copyWith(
                        visibleOnMount: true,
                        controlsHoverDuration: const Duration(days: 365),
                        controlsTransitionDuration: Duration.zero,
                        backdropColor: Colors.transparent,
                        seekBarAlignment: Alignment.bottomCenter,
                        seekBarColor: const Color(0x55ffffff),
                        seekBarBufferColor: const Color(0x66ffffff),
                        seekBarPositionColor: Colors.white,
                        seekBarThumbColor: Colors.white,
                      ),
                  child: Video(
                    controller: _controller,
                    width: double.infinity,
                    height: playerHeight,
                    fit: BoxFit.contain,
                    fill: Colors.black,
                    controls: _buildVideoControls,
                  ),
                ),
              ),
              // 手势层停在控制条上方，避免挡住底部进度条。
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 56,
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
                    final newPosition =
                        _seekStartPosition! +
                        Duration(seconds: seekSeconds.round());
                    final duration = _player.state.duration;

                    // 限制在有效范围内
                    if (newPosition >= Duration.zero &&
                        newPosition <= duration) {
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
                  child: _SeekIndicator(offset: _seekOffset!),
                ),
              if (_hasMarkerActions) _buildMarkerOverlayLayer(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoControls(VideoState state) {
    return Builder(
      builder: (context) {
        if (!isFullscreen(context)) {
          return AdaptiveVideoControls(state);
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            AdaptiveVideoControls(state),
            if (_hasMarkerActions) _buildMarkerOverlayLayer(context),
          ],
        );
      },
    );
  }

  Widget _buildMarkerOverlayLayer(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _markerOverlayRevision,
      builder: (context, _, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: calculateVideoMarkerEntryAlignment(),
              child: Padding(
                padding: const EdgeInsets.only(right: 14),
                child: _MarkerPanelButton(
                  isOpen: _isMarkerPanelOpen,
                  markerCount: widget.markers.length,
                  onTap: _toggleMarkerPanel,
                ),
              ),
            ),
            if (_isMarkerPanelOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _closeMarkerPanel,
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              top: 0,
              bottom: 0,
              right: _isMarkerPanelOpen ? 0 : -_markerPanelWidth(context),
              width: _markerPanelWidth(context),
              child: _MarkerTimelinePanel(
                markers: widget.markers,
                isSaving: _isSavingMarker,
                editorController: _markerEditorController,
                editingPosition: _editingPosition,
                editingMarker: _editingMarker,
                showHourField:
                    shouldShowVideoMarkerHourField(_player.state.duration) ||
                    ((_editingPosition?.inHours ?? 0) > 0),
                onAddCurrent: _addMarkerAtCurrentPosition,
                onSaveDraft: _saveMarkerDraft,
                onCancelDraft: _cancelMarkerDraft,
                onTapMarker: _seekToMarker,
                onEditMarker: _editMarker,
                onDeleteMarker: _deleteMarker,
                onClose: _closeMarkerPanel,
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleMarkerPanel() {
    setState(() => _isMarkerPanelOpen = !_isMarkerPanelOpen);
    _bumpMarkerOverlay();
  }

  void _closeMarkerPanel() {
    setState(() => _isMarkerPanelOpen = false);
    _bumpMarkerOverlay();
  }

  void _bumpMarkerOverlay() {
    _markerOverlayRevision.value++;
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

  double _markerPanelWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width < 520 ? width * 0.78 : 320;
  }

  void _addMarkerAtCurrentPosition() {
    _startMarkerDraft(position: _player.state.position);
  }

  void _editMarker(VideoMarker marker) {
    _startMarkerDraft(marker: marker, position: marker.position);
  }

  void _startMarkerDraft({VideoMarker? marker, required Duration position}) {
    _markerEditorController?.dispose();
    setState(() {
      _editingMarker = marker;
      _editingPosition = position;
      _markerEditorController = TextEditingController(text: marker?.note ?? '');
    });
    _bumpMarkerOverlay();
  }

  Future<void> _saveMarkerDraft(Duration position) async {
    final controller = _markerEditorController;
    final marker = _editingMarker;
    if (controller == null) {
      return;
    }
    final note = controller.text.trim();
    if (note.isEmpty) {
      return;
    }
    await _withMarkerSaving(() async {
      if (marker == null) {
        await widget.onCreateMarker!(position, note);
      } else {
        await widget.onUpdateMarker!(marker, position, note);
      }
    });
    _cancelMarkerDraft();
  }

  void _cancelMarkerDraft() {
    _markerEditorController?.dispose();
    setState(() {
      _editingMarker = null;
      _editingPosition = null;
      _markerEditorController = null;
    });
    _bumpMarkerOverlay();
  }

  Future<void> _deleteMarker(VideoMarker marker) async {
    if (widget.onDeleteMarker == null) {
      return;
    }
    await _withMarkerSaving(() async {
      await widget.onDeleteMarker!(marker);
    });
  }

  Future<void> _seekToMarker(VideoMarker marker) async {
    final target = clampVideoMarkerSeekPosition(
      marker.position,
      duration: _player.state.duration,
    );
    await _player.seek(target);
    await _player.play();
  }

  Future<void> _withMarkerSaving(Future<void> Function() action) async {
    if (_isSavingMarker) {
      return;
    }
    setState(() => _isSavingMarker = true);
    _bumpMarkerOverlay();
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _isSavingMarker = false);
        _bumpMarkerOverlay();
      }
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

class _MarkerPanelButton extends StatelessWidget {
  const _MarkerPanelButton({
    required this.isOpen,
    required this.markerCount,
    required this.onTap,
  });

  final bool isOpen;
  final int markerCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isOpen
                ? Colors.white.withValues(alpha: 0.94)
                : Colors.black.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.view_timeline_rounded,
                  color: isOpen ? Colors.black87 : Colors.white,
                  size: 18,
                ),
                if (markerCount > 0) ...[
                  const SizedBox(width: 5),
                  Text(
                    markerCount.toString(),
                    style: TextStyle(
                      color: isOpen ? Colors.black87 : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkerTimelinePanel extends StatelessWidget {
  const _MarkerTimelinePanel({
    required this.markers,
    required this.isSaving,
    required this.editorController,
    required this.editingPosition,
    required this.editingMarker,
    required this.showHourField,
    required this.onAddCurrent,
    required this.onSaveDraft,
    required this.onCancelDraft,
    required this.onTapMarker,
    required this.onEditMarker,
    required this.onDeleteMarker,
    required this.onClose,
  });

  final List<VideoMarker> markers;
  final bool isSaving;
  final TextEditingController? editorController;
  final Duration? editingPosition;
  final VideoMarker? editingMarker;
  final bool showHourField;
  final VoidCallback onAddCurrent;
  final ValueChanged<Duration> onSaveDraft;
  final VoidCallback onCancelDraft;
  final ValueChanged<VideoMarker> onTapMarker;
  final ValueChanged<VideoMarker> onEditMarker;
  final ValueChanged<VideoMarker> onDeleteMarker;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final sorted = [...markers]
      ..sort((a, b) {
        final byPosition = a.position.compareTo(b.position);
        if (byPosition != 0) {
          return byPosition;
        }
        return a.createdAt.compareTo(b.createdAt);
      });

    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(
        left: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '时间点',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: '关闭',
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: FilledButton.icon(
                onPressed: isSaving || editorController != null
                    ? null
                    : onAddCurrent,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(isSaving ? '保存中' : '标记当前时间'),
              ),
            ),
            if (editorController != null && editingPosition != null)
              _MarkerInlineEditor(
                key: ValueKey(
                  '${editingMarker?.id ?? 'new'}-${editingPosition!.inMilliseconds}-$showHourField',
                ),
                controller: editorController!,
                position: editingPosition!,
                showHourField: showHourField,
                isEditingExisting: editingMarker != null,
                isSaving: isSaving,
                onSave: onSaveDraft,
                onCancel: onCancelDraft,
              ),
            Expanded(
              child: sorted.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          '还没有时间点',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
                      itemCount: sorted.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final marker = sorted[index];
                        return _MarkerTimelineTile(
                          marker: marker,
                          onTap: () => onTapMarker(marker),
                          onEdit: () => onEditMarker(marker),
                          onDelete: () => onDeleteMarker(marker),
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

class _MarkerTimelineTile extends StatelessWidget {
  const _MarkerTimelineTile({
    required this.marker,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final VideoMarker marker;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 4, 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  formatVideoMarkerPosition(marker.position),
                  style: const TextStyle(
                    color: Color(0xff9ad8ff),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  marker.note,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '更多',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white70,
                  size: 19,
                ),
                color: Colors.white,
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkerInlineEditor extends StatefulWidget {
  const _MarkerInlineEditor({
    super.key,
    required this.controller,
    required this.position,
    required this.showHourField,
    required this.isEditingExisting,
    required this.isSaving,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController controller;
  final Duration position;
  final bool showHourField;
  final bool isEditingExisting;
  final bool isSaving;
  final ValueChanged<Duration> onSave;
  final VoidCallback onCancel;

  @override
  State<_MarkerInlineEditor> createState() => _MarkerInlineEditorState();
}

class _MarkerInlineEditorState extends State<_MarkerInlineEditor> {
  late final TextEditingController _hourController;
  late final TextEditingController _minuteController;
  late final TextEditingController _secondController;
  String? _positionError;

  @override
  void initState() {
    super.initState();
    final totalSeconds = widget.position.inSeconds < 0
        ? 0
        : widget.position.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    _hourController = TextEditingController(text: hours.toString());
    _minuteController = TextEditingController(
      text: minutes.toString().padLeft(2, '0'),
    );
    _secondController = TextEditingController(
      text: seconds.toString().padLeft(2, '0'),
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  void _save() {
    final position = parseVideoMarkerPositionFields(
      hours: widget.showHourField ? _hourController.text : null,
      minutes: _minuteController.text,
      seconds: _secondController.text,
    );
    if (position == null) {
      setState(() => _positionError = '请输入有效时间');
      return;
    }
    setState(() => _positionError = null);
    widget.onSave(position);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.isEditingExisting ? '编辑时间点' : '新增时间点',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showHourField) ...[
                    Expanded(
                      child: _MarkerPositionInput(
                        controller: _hourController,
                        label: '时',
                        enabled: !widget.isSaving,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: _MarkerPositionInput(
                      controller: _minuteController,
                      label: '分',
                      enabled: !widget.isSaving,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _MarkerPositionInput(
                      controller: _secondController,
                      label: '秒',
                      enabled: !widget.isSaving,
                    ),
                  ),
                ],
              ),
              if (_positionError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _positionError!,
                  style: const TextStyle(
                    color: Color(0xffffb4ab),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: widget.controller,
                minLines: 1,
                maxLines: 2,
                autofocus: true,
                enabled: !widget.isSaving,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: '写下这个时间点值得学习的地方',
                  hintStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.24),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xff9ad8ff)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.isSaving ? null : widget.onCancel,
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: widget.isSaving ? null : _save,
                    child: Text(widget.isSaving ? '保存中' : '保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkerPositionInput extends StatelessWidget {
  const _MarkerPositionInput({
    required this.controller,
    required this.label,
    required this.enabled,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 11),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.24),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xff9ad8ff)),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
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
