import 'package:flutter/material.dart';

import 'app_update.dart';

typedef UpdateDownloadCallback = void Function(String downloadUrl);

Future<void> showAppUpdateDialog({
  required BuildContext context,
  required GithubRelease release,
  required GithubReleaseAsset? apk,
  required VoidCallback onOpenRelease,
  required UpdateDownloadCallback onDownload,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(release.name.isEmpty ? release.tagName : release.name),
      content: SingleChildScrollView(
        child: Text(
          [
            if (release.body.trim().isNotEmpty) release.body.trim(),
            if (apk == null) '没有在这个 Release 里找到 APK 安装包。',
          ].join('\n\n'),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _confirmUpdateDialogCancel(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onOpenRelease();
          },
          child: const Text('Release 页面'),
        ),
        if (apk != null) ...[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDownload(apk.downloadUrl);
            },
            child: const Text('GitHub 下载'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDownload(acceleratedDownloadUrl(apk.downloadUrl));
            },
            child: const Text('加速下载'),
          ),
        ],
      ],
    ),
  );
}

Future<void> _confirmUpdateDialogCancel(BuildContext updateDialogContext) async {
  final confirmed = await showDialog<bool>(
    context: updateDialogContext,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('取消更新？'),
      content: const Text('确定先不安装这个版本吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('继续更新'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('确认取消'),
        ),
      ],
    ),
  );
  if (confirmed == true && updateDialogContext.mounted) {
    Navigator.of(updateDialogContext).pop();
  }
}
