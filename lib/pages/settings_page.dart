part of '../main.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.queue,
    required this.onChanged,
  });

  final ArticleSnapshotStore store;
  final SaveQueueController queue;
  final VoidCallback onChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _updateService = AppUpdateService();
  late final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();
  bool _checkingUpdate = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: FutureBuilder<PackageInfo>(
          future: _packageInfoFuture,
          builder: (context, snapshot) {
            final packageInfo = snapshot.data;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                _SettingsSection(
                  children: [
                    _SettingsTile(
                      icon: Icons.storage_rounded,
                      title: '使用统计',
                      subtitle: '查看文章数量和本地空间占用',
                      onTap: _openStorageStats,
                    ),
                    _SettingsTile(
                      icon: Icons.system_update_alt_rounded,
                      title: '检查更新',
                      subtitle: _checkingUpdate
                          ? '正在检查 GitHub Release'
                          : '支持 GitHub 下载和加速下载',
                      trailing: _checkingUpdate
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: _checkingUpdate
                          ? null
                          : () => _checkUpdate(packageInfo),
                    ),
                    _SettingsTile(
                      icon: Icons.playlist_add_check_rounded,
                      title: '收录队列',
                      subtitle: '查看正在处理或需要确认的任务',
                      onTap: _openSaveQueueFromSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  children: [
                    _SettingsTile(
                      icon: Icons.code_rounded,
                      title: 'GitHub',
                      subtitle: offNoteGithubRepoUrl,
                      onTap: () => _launchExternal(offNoteGithubRepoUrl),
                    ),
                    _SettingsInfoTile(
                      icon: Icons.person_outline_rounded,
                      title: '作者',
                      value: offNoteAuthor,
                    ),
                    _SettingsInfoTile(
                      icon: Icons.info_outline_rounded,
                      title: '版本',
                      value: packageInfo == null
                          ? '读取中'
                          : '${packageInfo.version}+${packageInfo.buildNumber}',
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openStorageStats() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StorageStatsPage(store: widget.store),
      ),
    );
  }

  Future<void> _openSaveQueueFromSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SaveQueuePage(queue: widget.queue),
      ),
    );
  }

  Future<void> _checkUpdate(PackageInfo? packageInfo) async {
    if (packageInfo == null) {
      return;
    }
    setState(() => _checkingUpdate = true);
    try {
      final release = await _updateService.fetchLatestRelease();
      if (!mounted) {
        return;
      }
      final apk = release.apkAsset;
      if (!isReleaseNewer(
        currentVersion: packageInfo.version,
        releaseTag: release.tagName,
      )) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('已经是最新版本'),
            content: Text(
              '当前版本：${packageInfo.version}+${packageInfo.buildNumber}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('好'),
              ),
            ],
          ),
        );
        return;
      }
      await _showUpdateDialog(release, apk);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('检查更新失败：$error')));
    } finally {
      if (mounted) {
        setState(() => _checkingUpdate = false);
      }
    }
  }

  Future<void> _showUpdateDialog(
    GithubRelease release,
    GithubReleaseAsset? apk,
  ) {
    return showAppUpdateDialog(
      context: context,
      release: release,
      apk: apk,
      onOpenRelease: () => _launchExternal(release.htmlUrl),
      onDownload: (downloadUrl) {
        final asset = apk;
        if (asset == null) {
          return;
        }
        _downloadAndInstall(asset, downloadUrl);
      },
    );
  }

  Future<void> _downloadAndInstall(
    GithubReleaseAsset asset,
    String downloadUrl,
  ) async {
    var progress = 0.0;
    var progressText = '准备下载';
    StateSetter? updateDialog;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            updateDialog = setState;
            return AlertDialog(
              title: const Text('下载更新'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: progress == 0 ? null : progress,
                  ),
                  const SizedBox(height: 12),
                  Text(progressText),
                ],
              ),
            );
          },
        ),
      ),
    );

    try {
      final file = await _updateService.downloadApk(
        url: downloadUrl,
        fileName: asset.name,
        onProgress: (received, total) {
          updateDialog?.call(() {
            progress = total <= 0 ? 0 : received / total;
            progressText = total <= 0
                ? '已下载 ${_formatBytes(received)}'
                : '${_formatBytes(received)} / ${_formatBytes(total)}';
          });
        },
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      await _updateService.installApk(file);
    } catch (error) {
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('下载更新失败：$error')));
    }
  }

  Future<void> _launchExternal(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('无法打开 $url');
    }
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xffdedfd7)),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing = const Icon(Icons.chevron_right_rounded),
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _accent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _SettingsInfoTile extends StatelessWidget {
  const _SettingsInfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: _accent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: Text(
        value,
        style: const TextStyle(color: _muted, fontWeight: FontWeight.w700),
      ),
    );
  }
}
