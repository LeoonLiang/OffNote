import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/article_database.dart';
import 'package:offnote/article_filter_panel.dart';
import 'package:offnote/saved_tag.dart';

void main() {
  testWidgets('filter panel uses grouped button options', (tester) async {
    var settings = const ArticleFilterSettings(
      sort: ArticleSort.publishedNewest,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ArticleFilterPanel(
                settings: settings,
                categories: const [],
                onChanged: (value) {
                  setState(() => settings = value);
                },
                onReset: () {},
                onCollapse: () {},
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('排序依据'), findsOneWidget);
    expect(find.text('笔记类型'), findsOneWidget);
    expect(find.text('最近保存'), findsOneWidget);
    expect(find.text('视频'), findsOneWidget);

    await tester.tap(find.text('视频'));
    await tester.pump();

    final selected = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, '视频'),
    );
    expect(selected.selected, isTrue);
  });

  testWidgets('filter panel supports multi-select tags', (tester) async {
    var settings = const ArticleFilterSettings(
      sort: ArticleSort.publishedNewest,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ArticleFilterPanel(
                settings: settings,
                categories: const [],
                tags: [
                  SavedTag(
                    id: 't1',
                    name: '攻略',
                    color: 0xffd83f5f,
                    createdAt: DateTime(2026, 5, 1),
                  ),
                  SavedTag(
                    id: 't2',
                    name: '咖啡',
                    color: 0xff51b96b,
                    createdAt: DateTime(2026, 5, 2),
                  ),
                ],
                onChanged: (value) {
                  setState(() => settings = value);
                },
                onReset: () {},
                onCollapse: () {},
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('标签'), findsOneWidget);

    await tester.tap(find.text('攻略'));
    await tester.pump();
    await tester.tap(find.text('咖啡'));
    await tester.pump();

    expect(settings.tagIds, {'t1', 't2'});
  });
}
