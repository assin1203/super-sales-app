import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_provider.dart';
import '../core/theme.dart';

/// 登录页：手机号 + 短信验证码（FR-1.1）
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _sending = false;
  bool _logging = false;
  int _countdown = 0;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入 11 位手机号')));
      return;
    }
    setState(() => _sending = true);
    // TODO: api.post('/auth/sms-code', body: {phone})
    await api.post('/auth/sms-code', body: {'phone': phone});
    if (!mounted) return;
    setState(() {
      _sending = false;
      _countdown = 60;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('验证码已发送（mock）')));
    _startCountdown();
  }

  Future<void> _startCountdown() async {
    while (_countdown > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _countdown--);
    }
  }

  Future<void> _login() async {
    final phone = _phoneCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (phone.length < 11 || code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入手机号和验证码')));
      return;
    }
    setState(() => _logging = true);
    final ok = await context.read<AuthProvider>().loginSms(phone, code);
    if (!mounted) return;
    setState(() => _logging = false);
    if (ok) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('超级展业', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: kqwPrimary)),
                const SizedBox(height: 8),
                const Text('零收费 · 积分展业 · 团队分红', style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 48),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                  decoration: const InputDecoration(
                    labelText: '手机号',
                    prefixIcon: Icon(Icons.phone_outlined),
                    counter: SizedBox.shrink(),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: '验证码',
                          prefixIcon: Icon(Icons.lock_outline),
                          counter: SizedBox.shrink(),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: (_sending || _countdown > 0) ? null : _sendCode,
                      child: _countdown > 0 ? Text('${_countdown}s 后重发') : const Text('获取验证码'),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _logging ? null : _login,
                    child: _logging
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('登录 / 注册'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(onPressed: () {}, child: const Text('用户协议')),
                    Text(' · '),
                    TextButton(onPressed: () {}, child: const Text('隐私政策')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
