import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:offnote/app_update.dart';
import 'package:offnote/app_update_dialog.dart';

void main() {
  testWidgets('update dialog requires explicit confirmed cancellation', (
    tester,
  ) async {
    final release = GithubRelease(
      tagName: 'v1.2.0',
      name: 'OffNote 1.2.0',
      htmlUrl: 'https://example.com/release',
      body: '更新内容',
      assets: const [
        GithubReleaseAsset(
          name: 'OffNote.apk',
          downloadUrl: 'https://example.com/app.apk',
          size: 123,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppUpdateDialog(
              context: context,
              release: release,
              apk: release.apkAsset,
              onOpenRelease: () {},
              onDownload: (_) {},
            ),
            child: const Text('打开更新'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开更新'));
    await tester.pumpAndSettle();
    expect(find.text('OffNote 1.2.0'), findsOneWidget);

    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(find.text('OffNote 1.2.0'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('取消更新？'), findsOneWidget);
    expect(find.text('OffNote 1.2.0'), findsOneWidget);

    await tester.tap(find.text('继续更新'));
    await tester.pumpAndSettle();
    expect(find.text('取消更新？'), findsNothing);
    expect(find.text('OffNote 1.2.0'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认取消'));
    await tester.pumpAndSettle();
    expect(find.text('OffNote 1.2.0'), findsNothing);
  });
}
