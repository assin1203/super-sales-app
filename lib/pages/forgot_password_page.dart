import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api/common_api.dart';
import '../core/api/user_api.dart';
import '../core/api_client.dart';
import '../core/slider_captcha.dart';
import '../core/theme.dart';
import '../core/toast.dart';

/// 忘记密码（`POST /user/password/reset`，公开端点）：
/// 手机号 + 短信验证码 + 新密码，无需登录即可访问。
///
/// 验证码走与登录同一份 `/common/sms/*`（5 分钟有效、校验通过即消费），
/// 服务端重置成功后撤销该账号旧 refresh，因此提示用户用新密码重新登录。
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, this.smsApi, this.userApi});

  /// 测试注入点；生产走全局单例（见 [commonApi] / [userApi]）
  final CommonApi? smsApi;
  final UserApi? userApi;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  late final CommonApi _sms = widget.smsApi ?? commonApi;
  late final UserApi _users = widget.userApi ?? userApi;

  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _verified = false; // 滑块是否已通过
  bool _sending = false; // 正在请求发送验证码
  bool _submitting = false;
  int _countdown = 0; // 重发倒计时（与服务端 60s 冷却对齐）
  Timer? _timer;
  int _captchaNonce = 0; // 递增以重建滑块（刷新）

  /// 服务端验证码冷却 60s，前端倒计时与之对齐
  static const int _resendSeconds = 60;

  /// 大陆手机号：11 位，1[3-9] 开头
  static final RegExp _phoneRe = RegExp(r'^1[3-9]\d{9}$');

  /// 与服务端 PASSWORD_PATTERN 对齐：8~64 位、须同时含字母与数字、不允许空白
  static final RegExp _passwordRe = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)\S{8,64}$');

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
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

  String? _validatePassword(String? v) {
    final pwd = v ?? '';
    if (pwd.isEmpty) return '请输入新密码';
    if (!_passwordRe.hasMatch(pwd)) return '8~64 位，须同时包含字母和数字';
    return null;
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
      await _sms.sendSms(_phoneCtrl.text.trim());
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

  /// 提交重置：手机号 + 验证码 + 新密码，成功后回登录页
  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final newPwd = _newCtrl.text.trim();
    if (newPwd != _confirmCtrl.text.trim()) {
      showToast(context, '两次输入的新密码不一致');
      return;
    }

    setState(() => _submitting = true);
    try {
      await _users.resetPassword(
        phone: _phoneCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
        newPassword: newPwd,
      );
      if (!mounted) return;
      showToast(context, '密码已重置，请用新密码登录');
      context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(context, e.displayMessage);
      // 未注册（20001）等业务失败：让用户改号后重新过滑块
      _resetCaptcha();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('重置密码')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '验证手机号后设置新密码，重置成功需用新密码重新登录',
            style: TextStyle(fontSize: 13, color: kqwTextSecondary),
          ),
          const SizedBox(height: 16),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        maxLength: 6,
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
                ),
                const SizedBox(height: 8),
                _captchaSection(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newCtrl,
                  obscureText: _obscureNew,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 15),
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    labelText: '新密码',
                    helperText: '8~64 位，须同时包含字母和数字',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscureNew = !_obscureNew),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  style: const TextStyle(fontSize: 15),
                  validator: (v) {
                    if ((v ?? '').isEmpty) return '请再次输入新密码';
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: '确认新密码',
                    prefixIcon: const Icon(Icons.lock_reset_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      // 提交按钮常驻底部：长表单滚动到底才见按钮容易漏，键盘弹起也会被顶上来
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('重置密码'),
          ),
        ),
      ),
    );
  }

  /// 滑块验证码区块 + 刷新按钮（与登录页同一套防刷交互）
  Widget _captchaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
                _verified ? '安全验证' : '安全验证（获取验证码前完成拼图）',
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
