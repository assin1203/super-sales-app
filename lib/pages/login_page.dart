import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api/common_api.dart';
import '../core/api_client.dart';
import '../core/auth_provider.dart';
import '../core/slider_captcha.dart';
import '../core/theme.dart';
import '../core/toast.dart';

/// 登录页：手机号 + 密码 / 短信验证码两种形态，滑块验证码防刷（FR-1.1）
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

/// 登录形态：密码 / 短信验证码
enum _LoginMode { password, code }

class _LoginPageState extends State<LoginPage> {
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _LoginMode _mode = _LoginMode.password;
  bool _obscure = true;
  bool _verified = false; // 滑块是否已通过
  bool _logging = false;
  bool _sending = false; // 正在请求发送验证码
  int _countdown = 0; // 重发倒计时（与服务端 60s 冷却对齐）
  Timer? _timer;
  int _captchaNonce = 0; // 递增以重建滑块（刷新）

  /// 服务端验证码冷却 60s，前端倒计时与之对齐
  static const int _resendSeconds = 60;

  /// 大陆手机号：11 位，1[3-9] 开头
  static final RegExp _phoneRe = RegExp(r'^1[3-9]\d{9}$');

  bool get _codeMode => _mode == _LoginMode.code;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
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

  /// 密码登录：滑块通过才允许提交
  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_verified) {
      showToast(context, '请先完成滑块验证');
      return;
    }
    setState(() => _logging = true);
    try {
      await context.read<AuthProvider>().loginPassword(
            _phoneCtrl.text.trim(),
            _passwordCtrl.text,
          );
      if (!mounted) return;
      context.go('/');
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(context, e.displayMessage);
      // 凭证错误后让用户重新过滑块，避免脚本直接刷登录
      _resetCaptcha();
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  /// 验证码登录：滑块已在发送阶段拦过一次，这里只校验验证码格式
  Future<void> _loginByCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _logging = true);
    try {
      await context.read<AuthProvider>().loginCode(
            _phoneCtrl.text.trim(),
            _codeCtrl.text.trim(),
          );
      if (!mounted) return;
      context.go('/');
    } on ApiException catch (e) {
      if (!mounted) return;
      // 未注册 → 服务端 20001「该手机号未注册，请先注册」
      showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  /// 发送验证码：先过滑块，再起 60s 倒计时
  Future<void> _sendCode() async {
    if (_sending || _countdown > 0) return;
    final phoneError = _validatePhone(_phoneCtrl.text);
    if (phoneError != null) {
      showToast(context, phoneError);
      return;
    }
    if (!_verified) {
      showToast(context, '请先完成滑块验证');
      return;
    }
    setState(() => _sending = true);
    try {
      await commonApi.sendSms(_phoneCtrl.text.trim());
      if (!mounted) return;
      showToast(context, '验证码已发送，5 分钟内有效');
      _startCountdown();
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(context, e.displayMessage);
      // 限流/发送失败让用户重新过滑块，避免反复点
      _resetCaptcha();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) t.cancel();
    });
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
                  const SizedBox(height: 24),
                  _modeTabs(),
                  const SizedBox(height: 20),
                  // 手机号（两种形态共用）
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
                  if (_codeMode) _codeField() else _passwordField(),
                  const SizedBox(height: 12),
                  _captchaSection(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_logging || (!_codeMode && !_verified)) ? null : (_codeMode ? _loginByCode : _login),
                      child: _logging
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_codeMode ? '登录 / 注册' : '登录'),
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

  /// 形态切换（密码 / 验证码）
  Widget _modeTabs() {
    Widget tab(String label, _LoginMode mode) {
      final active = _mode == mode;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _mode = mode),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? kqwPrimary : kqwTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 2,
                  width: 28,
                  decoration: BoxDecoration(
                    color: active ? kqwPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(children: [tab('密码登录', _LoginMode.password), tab('验证码登录', _LoginMode.code)]);
  }

  Widget _passwordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _passwordCtrl,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _login(),
          style: const TextStyle(fontSize: 15),
          validator: (v) => (v == null || v.length < 8) ? '密码至少 8 位' : null,
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
      ],
    );
  }

  /// 验证码输入 + 获取验证码（60s 倒计时）
  Widget _codeField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            onFieldSubmitted: (_) => _loginByCode(),
            style: const TextStyle(fontSize: 15),
            validator: (v) {
              final code = v?.trim() ?? '';
              if (!RegExp(r'^\d{6}$').hasMatch(code)) return '请输入 6 位验证码';
              return null;
            },
            decoration: const InputDecoration(
              labelText: '验证码',
              prefixIcon: Icon(Icons.sms_outlined),
              counter: SizedBox.shrink(),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 108,
          height: 56,
          child: OutlinedButton(
            onPressed: (_sending || _countdown > 0) ? null : _sendCode,
            child: Text(
              _sending ? '发送中' : (_countdown > 0 ? '${_countdown}s 后重发' : '获取验证码'),
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
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
            Text(
                _verified
                    ? '安全验证'
                    : (_codeMode ? '安全验证（获取验证码前完成拼图）' : '安全验证（滑动完成拼图）'),
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
