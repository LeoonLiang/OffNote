import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/offnote_video_player.dart';

void main() {
  group('calculateContainedVideoSize', () {
    test('fills available width when proportional height fits', () {
      final size = calculateContainedVideoSize(
        maxSize: const Size(390, 800),
        aspectRatio: 16 / 9,
      );

      expect(size.width, 390);
      expect(size.height, closeTo(219.375, 0.001));
    });

    test('prioritizes height when width-based height would overflow', () {
      final size = calculateContainedVideoSize(
        maxSize: const Size(390, 500),
        aspectRatio: 9 / 16,
      );

      expect(size.height, 500);
      expect(size.width, closeTo(281.25, 0.001));
    });
  });

  group('video layout helpers', () {
    test('opens video articles in autoplay mode', () {
      expect(offNoteVideoAutoPlayOnOpen, isTrue);
    });

    test('compresses player height when content is expanded', () {
      expect(
        calculateVideoPlayerHeight(
          availableHeight: 800,
          isContentExpanded: false,
        ),
        800,
      );
      expect(
        calculateVideoPlayerHeight(
          availableHeight: 800,
          isContentExpanded: true,
        ),
        424,
      );
    });

    test('keeps title preview padding independent from marker entry', () {
      expect(calculateCollapsedContentLeadingPadding(false), 16);
      expect(calculateCollapsedContentLeadingPadding(true), 16);
    });

    test('places marker entry at the right center of the video', () {
      expect(calculateVideoMarkerEntryAlignment(), Alignment.centerRight);
    });
  });

  group('video marker helpers', () {
    test('formats marker positions under one hour', () {
      expect(formatVideoMarkerPosition(Duration.zero), '00:00');
      expect(
        formatVideoMarkerPosition(const Duration(minutes: 1, seconds: 5)),
        '01:05',
      );
      expect(
        formatVideoMarkerPosition(
          const Duration(minutes: 59, seconds: 59, milliseconds: 900),
        ),
        '59:59',
      );
    });

    test('formats marker positions at one hour or longer', () {
      expect(
        formatVideoMarkerPosition(
          const Duration(hours: 1, minutes: 2, seconds: 3),
        ),
        '1:02:03',
      );
    });

    test('clamps marker seek positions to valid duration', () {
      const duration = Duration(minutes: 2);

      expect(
        clampVideoMarkerSeekPosition(
          const Duration(seconds: -3),
          duration: duration,
        ),
        Duration.zero,
      );
      expect(
        clampVideoMarkerSeekPosition(
          const Duration(seconds: 30),
          duration: duration,
        ),
        const Duration(seconds: 30),
      );
      expect(
        clampVideoMarkerSeekPosition(
          const Duration(minutes: 3),
          duration: duration,
        ),
        duration,
      );
    });

    test('does not clamp upper bound when duration is unknown', () {
      expect(
        clampVideoMarkerSeekPosition(
          const Duration(minutes: 3),
          duration: Duration.zero,
        ),
        const Duration(minutes: 3),
      );
    });

    test('shows hour field only for videos at one hour or longer', () {
      expect(
        shouldShowVideoMarkerHourField(
          const Duration(minutes: 59, seconds: 59),
        ),
        isFalse,
      );
      expect(shouldShowVideoMarkerHourField(const Duration(hours: 1)), isTrue);
    });

    test('parses marker position fields into duration', () {
      expect(
        parseVideoMarkerPositionFields(minutes: '02', seconds: '03'),
        const Duration(minutes: 2, seconds: 3),
      );
      expect(
        parseVideoMarkerPositionFields(
          hours: '1',
          minutes: '02',
          seconds: '03',
        ),
        const Duration(hours: 1, minutes: 2, seconds: 3),
      );
    });

    test('rejects invalid marker position fields', () {
      expect(
        parseVideoMarkerPositionFields(minutes: '', seconds: '03'),
        isNull,
      );
      expect(
        parseVideoMarkerPositionFields(minutes: '02', seconds: '60'),
        isNull,
      );
      expect(
        parseVideoMarkerPositionFields(
          hours: '-1',
          minutes: '02',
          seconds: '03',
        ),
        isNull,
      );
    });
  });

  group('OffNoteVideoSource', () {
    test('extracts local video and poster uris from offline html', () {
      final source = OffNoteVideoSource.fromHtml('''
        <section class="gallery">
          <video class="video-player" controls poster="file:///tmp/poster.jpg">
            <source src="file:///tmp/video.mp4" type="video/mp4">
          </video>
        </section>
      ''');

      expect(source?.videoUri, 'file:///tmp/video.mp4');
      expect(source?.posterUri, 'file:///tmp/poster.jpg');
    });
  });
}
