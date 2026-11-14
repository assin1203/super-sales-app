import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_update.dart';
import '../core/auth_provider.dart';
import '../core/theme.dart';

/// 设置：分组列表（账号与安全 / 通用 / 关于 + 底部退出登录）。
///
/// 交易密码、换绑手机号在本页首次暴露入口；资料与登录密码复用已有页面。
/// 退出登录保留在页面底部（红色，需二次确认），与「我的」原入口一致。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.updater});

  /// 版本检查器（测试注入；生产用全局 appUpdateChecker）
  final AppUpdateChecker? updater;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final AppUpdateChecker _updater = widget.updater ?? appUpdateChecker;

  /// 本地安装版本（package_info 读取失败时留空，仅不展示）
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final installed = await loadInstalledVersion();
      if (!mounted) return;
      setState(() => _version = 'v${installed.versionName}');
    } catch (_) {
      // 读不到版本号不影响设置页使用
    }
  }

  /// 手动检查更新：已是最新/失败都会给一句提示
  Future<void> _checkUpdate() => _updater.check(context, manual: true);

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认退出登录？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: const Text('退出')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final tradePasswordSet = user?.tradePasswordSet ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _sectionTitle('账号与安全'),
          _card([
            _tile(
              Icons.person_outline,
              '头像与昵称',
              trailing: auth.name,
              onTap: () => context.push('/profile'),
            ),
            _divider(),
            _tile(
              Icons.phone_iphone,
              '手机号',
              trailing: user?.maskedPhone,
              onTap: () => context.push('/phone/rebind'),
            ),
            _divider(),
            _tile(
              Icons.lock_outline,
              '登录密码',
              onTap: () => context.push('/password'),
            ),
            _divider(),
            _tile(
              Icons.pin_outlined,
              '交易密码',
              trailing: tradePasswordSet ? '已设置' : '未设置',
              onTap: () => context.push('/trade-password'),
            ),
          ]),
          _sectionTitle('通用'),
          _card([
            _tile(
              Icons.system_update_alt,
              '检查更新',
              trailing: _version.isEmpty ? null : _version,
              onTap: _checkUpdate,
            ),
          ]),
          _sectionTitle('关于'),
          _card([
            _tile(Icons.info_outline, '版本信息', trailing: _version),
          ]),
          const SizedBox(height: 28),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 46),
              foregroundColor: const Color(0xFFE5484D),
              side: const BorderSide(color: Color(0x33E5484D)),
            ),
            onPressed: _logout,
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: kqwTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  Widget _card(List<Widget> children) => Card(
        margin: EdgeInsets.zero,
        child: Column(children: children),
      );

  Widget _divider() => const Divider(height: 1, indent: 52);

  Widget _tile(IconData icon, String title,
      {String? trailing, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF1F2430)),
      title: Text(title, style: const TextStyle(color: Color(0xFF1F2430))),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null && trailing.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                trailing,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: kqwTextSecondary),
              ),
            ),
          if (onTap != null)
            const Icon(Icons.chevron_right, size: 20, color: kqwTextSecondary),
        ],
      ),
      onTap: onTap,
    );
  }
}
