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
