import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_provider.dart';
import '../core/theme.dart';
import '../core/toast.dart';

/// 修改密码（`PUT /user/password`）。
///
/// 后端成功后撤销 refresh token，因此本地必须同步登出并回登录页，
/// 否则用户会带着失效会话继续操作。
class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key});

  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final oldPwd = _oldCtrl.text.trim();
    final newPwd = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (oldPwd.isEmpty) {
      showToast(context, '请输入原密码');
      return;
    }
    if (newPwd.length < 8) {
      showToast(context, '新密码至少 8 位');
      return;
    }
    if (newPwd != confirm) {
      showToast(context, '两次输入的新密码不一致');
      return;
    }
    if (newPwd == oldPwd) {
      showToast(context, '新密码不能与原密码相同');
      return;
    }

    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    try {
      await auth.changePassword(oldPwd, newPwd);
      if (!mounted) return;
      showToast(context, '密码已修改，请用新密码重新登录');
      await auth.logout();
      if (!mounted) return;
      context.go('/login');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('修改密码')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _field(_oldCtrl, '原密码'),
                  const SizedBox(height: 14),
                  _field(_newCtrl, '新密码（至少 8 位）'),
                  const SizedBox(height: 14),
                  _field(_confirmCtrl, '确认新密码'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '修改成功后当前登录态会失效，需要用新密码重新登录。',
              style: TextStyle(fontSize: 12, color: kqwTextSecondary),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: kqwPrimary,
              minimumSize: const Size(0, 46),
            ),
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? '提交中…' : '确认修改'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
