import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/article_database.dart';
import 'package:offnote/article_filter_panel.dart';

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
}
