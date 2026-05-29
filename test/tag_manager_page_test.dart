import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/article_snapshot_store.dart';
import 'package:offnote/main.dart';
import 'package:offnote/saved_tag.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('renames and deletes tags from settings manager', (tester) async {
    final store = _FakeTagStore([
      SavedTag(
        id: 't1',
        name: '待整理',
        color: 0xff4f8df7,
        createdAt: DateTime(2026, 5, 1),
      ),
    ]);
    var changedCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: TagManagerPage(store: store, onChanged: () => changedCount += 1),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('待整理'), findsOneWidget);

    await tester.tap(find.byTooltip('编辑标签').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), '已整理');
    await tester.tap(find.text('保存'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('已整理'), findsOneWidget);
    expect((await store.listTags()).single.name, '已整理');

    await tester.tap(find.byTooltip('删除标签').first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('确定删除「已整理」吗？不会删除文章，只会移除文章上的这个标签。'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('已整理'), findsNothing);
    expect(await store.listTags(), isEmpty);
    expect(changedCount, 2);
  });

  testWidgets('deletes tags under ShadApp without a ScaffoldMessenger', (
    tester,
  ) async {
    final store = _FakeTagStore([
      SavedTag(
        id: 't1',
        name: '临时',
        color: 0xff4f8df7,
        createdAt: DateTime(2026, 5, 1),
      ),
    ]);

    await tester.pumpWidget(
      ShadApp(
        home: TagManagerPage(store: store, onChanged: () {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('删除标签').first);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('删除'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(await store.listTags(), isEmpty);
    expect(find.text('临时'), findsNothing);
  });
}

class _FakeTagStore extends ArticleSnapshotStore {
  _FakeTagStore(this._tags);

  final List<SavedTag> _tags;

  @override
  Future<List<SavedTag>> listTags() async {
    return List<SavedTag>.of(_tags);
  }

  @override
  Future<void> renameTag(String id, String name) async {
    final index = _tags.indexWhere((tag) => tag.id == id);
    if (index < 0) {
      return;
    }
    final current = _tags[index];
    _tags[index] = SavedTag(
      id: current.id,
      name: name,
      color: current.color,
      createdAt: current.createdAt,
    );
  }

  @override
  Future<void> deleteTag(String id) async {
    _tags.removeWhere((tag) => tag.id == id);
  }
}
