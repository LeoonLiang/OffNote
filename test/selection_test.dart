import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/selection.dart';

void main() {
  test('selects all visible ids when not all are selected', () {
    expect(
      toggleVisibleSelection(selectedIds: {'a'}, visibleIds: ['a', 'b', 'c']),
      {'a', 'b', 'c'},
    );
  });

  test('clears visible ids when all visible ids are selected', () {
    expect(
      toggleVisibleSelection(
        selectedIds: {'a', 'b', 'c', 'hidden'},
        visibleIds: ['a', 'b', 'c'],
      ),
      {'hidden'},
    );
  });
}
