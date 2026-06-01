import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/video_marker.dart';

void main() {
  test('serializes video marker to database map', () {
    final marker = VideoMarker(
      id: 'm1',
      articleId: 'a1',
      position: const Duration(minutes: 1, seconds: 23),
      note: '观察这里的剪辑节奏',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(2000),
    );

    expect(marker.toMap(), {
      'id': 'm1',
      'article_id': 'a1',
      'position_ms': 83000,
      'note': '观察这里的剪辑节奏',
      'created_at': 1000,
      'updated_at': 2000,
    });
  });

  test('deserializes video marker from database map', () {
    final marker = VideoMarker.fromMap({
      'id': 'm1',
      'article_id': 'a1',
      'position_ms': 83000,
      'note': '观察这里的剪辑节奏',
      'created_at': 1000,
      'updated_at': 2000,
    });

    expect(marker.id, 'm1');
    expect(marker.articleId, 'a1');
    expect(marker.position, const Duration(minutes: 1, seconds: 23));
    expect(marker.note, '观察这里的剪辑节奏');
    expect(marker.createdAt, DateTime.fromMillisecondsSinceEpoch(1000));
    expect(marker.updatedAt, DateTime.fromMillisecondsSinceEpoch(2000));
  });

  test('copyWith updates editable fields', () {
    final marker = VideoMarker(
      id: 'm1',
      articleId: 'a1',
      position: const Duration(seconds: 10),
      note: '旧记录',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(3000);

    final updated = marker.copyWith(
      position: const Duration(seconds: 12),
      note: '新记录',
      updatedAt: updatedAt,
    );

    expect(updated.id, 'm1');
    expect(updated.articleId, 'a1');
    expect(updated.position, const Duration(seconds: 12));
    expect(updated.note, '新记录');
    expect(updated.createdAt, marker.createdAt);
    expect(updated.updatedAt, updatedAt);
  });
}
