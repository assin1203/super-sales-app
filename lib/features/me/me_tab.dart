import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/auth_provider.dart';

/// 我的（账户/等级/设置）
class MeTab extends StatelessWidget {
  const MeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 用户信息卡
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 32)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('138****0001', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('L1 基础会员 · 推荐码 KQW888', style: TextStyle(color: Colors.black54, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _tile(context, Icons.account_balance_wallet_outlined, '积分流水', () => context.go('/points-flow')),
              const Divider(height: 1),
              _tile(context, Icons.qr_code_outlined, '我的推荐码（邀请好友）', () {}),
              const Divider(height: 1),
              _tile(context, Icons.devices_other, '我的机器', () {}),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              _tile(context, Icons.notifications_outlined, '消息通知', () {}),
              const Divider(height: 1),
              _tile(context, Icons.help_outline, '帮助与客服', () {}),
              const Divider(height: 1),
              _tile(context, Icons.settings_outlined, '设置', () {}),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            foregroundColor: Colors.red,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: () async {
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('确认退出登录？'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                  FilledButton(
                    onPressed: () {
                      context.read<AuthProvider>().logout();
                      context.go('/login');
                    },
                    child: const Text('退出'),
                  ),
                ],
              ),
            );
          },
          child: const Text('退出登录'),
        ),
        const SizedBox(height: 8),
        Center(child: Text('v0.1.0 · 用户 ${auth.userId ?? '-'}', style: TextStyle(color: Colors.black26, fontSize: 12))),
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
