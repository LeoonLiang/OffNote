import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/snapshot_readiness.dart';

void main() {
  test('decodes snapshot readiness from JavaScript result', () {
    expect(decodeSnapshotReadinessResult('true'), isTrue);
    expect(decodeSnapshotReadinessResult(true), isTrue);
    expect(decodeSnapshotReadinessResult('"false"'), isFalse);
    expect(decodeSnapshotReadinessResult(false), isFalse);
  });

  test('probe waits for xhs initial state or rendered note content', () {
    expect(snapshotReadyProbeScript, contains('window.__INITIAL_STATE__'));
    expect(snapshotReadyProbeScript, contains('.image-gallery-container'));
    expect(snapshotReadyProbeScript, contains('.note-content'));
  });
}
