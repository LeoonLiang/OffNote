part of '../main.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: const _EmptyMessage(
        icon: Icons.lock_outline_rounded,
        text: '数据仅保存在本地',
      ),
    );
  }
}
