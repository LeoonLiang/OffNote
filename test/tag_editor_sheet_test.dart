import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/saved_tag.dart';
import 'package:offnote/tag_editor_sheet.dart';

void main() {
  testWidgets('creates a tag inline without opening a dialog', (tester) async {
    final created = SavedTag(
      id: 't1',
      name: '攻略',
      color: 0xffd83f5f,
      createdAt: DateTime(2026, 5, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TagEditorSheet(
            initialTags: const [],
            initialSelectedIds: const {},
            accentColor: const Color(0xff49b866),
            onCreateTag: (_) async => created,
          ),
        ),
      ),
    );

    await tester.tap(find.text('新建标签'));
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '攻略');
    await tester.tap(find.text('创建'));
    await tester.pumpAndSettle();

    expect(find.text('攻略'), findsOneWidget);
    final tile = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, '攻略'),
    );
    expect(tile.value, isTrue);
  });
}
