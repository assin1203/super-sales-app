import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/auth_provider.dart';
import '../core/slider_captcha.dart';
import '../core/theme.dart';
import '../core/toast.dart';

/// 登录页：手机号 + 密码 + 拼图滑块验证码（FR-1.1）
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _verified = false; // 滑块是否已通过
  bool _logging = false;
  int _captchaNonce = 0; // 递增以重建滑块（刷新）

  /// 大陆手机号：11 位，1[3-9] 开头
  static final RegExp _phoneRe = RegExp(r'^1[3-9]\d{9}$');

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _resetCaptcha() {
    setState(() {
      _verified = false;
      _captchaNonce++;
    });
  }

  String? _validatePhone(String? v) {
    final phone = v?.trim() ?? '';
    if (phone.isEmpty) return '请输入手机号';
    if (!_phoneRe.hasMatch(phone)) return '手机号格式不正确';
    return null;
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_verified) {
      showToast(context, '请先完成滑块验证');
      return;
    }
    setState(() => _logging = true);
    final ok = await context.read<AuthProvider>().loginPassword(
          _phoneCtrl.text.trim(),
          _passwordCtrl.text,
        );
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('超级展业', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: kqwPrimary)),
                  const SizedBox(height: 8),
                  const Text('零收费 · 积分展业 · 团队分红', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 40),
                  // 手机号
                  TextFormField(
                    controller: _phoneCtrl,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.phone,
                    maxLength: 11,
                    style: const TextStyle(fontSize: 15),
                    validator: _validatePhone,
                    decoration: const InputDecoration(
                      labelText: '手机号',
                      prefixIcon: Icon(Icons.phone_outlined),
                      counter: SizedBox.shrink(),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 密码
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                    style: const TextStyle(fontSize: 15),
                    validator: (v) => (v == null || v.length < 6) ? '密码至少 6 位' : null,
                    decoration: InputDecoration(
                      labelText: '密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => showToast(context, '请联系管理员重置密码'),
                      child: const Text('忘记密码？', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _captchaSection(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_logging || !_verified) ? null : _login,
                      child: _logging
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('登录'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(onPressed: null, child: Text('用户协议')),
                      Text(' · '),
                      TextButton(onPressed: null, child: Text('隐私政策')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 滑块验证码区块 + 刷新按钮
  Widget _captchaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_verified ? '安全验证' : '安全验证（滑动完成拼图）',
                style: const TextStyle(fontSize: 13, color: kqwTextSecondary)),
            InkWell(
              onTap: _resetCaptcha,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.refresh, size: 18, color: kqwTextSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderCaptcha(
          key: ValueKey(_captchaNonce),
          onComplete: () => setState(() => _verified = true),
        ),
      ],
    );
  }
}
