import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api/common_api.dart';
import '../core/api/user_api.dart';
import '../core/api_client.dart';
import '../core/auth_provider.dart';
import '../core/slider_captcha.dart';
import '../core/theme.dart';
import '../core/toast.dart';

/// 换绑手机号（`POST /user/phone/rebind`）：旧号 + 新号双验证码。
///
/// 手机号即登录标识，因此要求两个号码各收一条验证码：
/// 旧号证明操作人持有当前号（手机丢失 + 验证码登录场景下唯一的线下凭据），
/// 新号证明新号码可用且归本人。成功后服务端撤销全部 refresh token，
/// 本页必须登出并回登录页，让用户用新号重新登录。
class PhoneRebindPage extends StatefulWidget {
  const PhoneRebindPage({super.key, this.smsApi, this.userApi});

  /// 测试注入点；生产走全局单例（见 [commonApi] / [userApi]）
  final CommonApi? smsApi;
  final UserApi? userApi;

  @override
  State<PhoneRebindPage> createState() => _PhoneRebindPageState();
}

class _PhoneRebindPageState extends State<PhoneRebindPage> {
  late final CommonApi _sms = widget.smsApi ?? commonApi;
  late final UserApi _users = widget.userApi ?? userApi;

  final _oldCodeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  bool _sendingOld = false;
  bool _sendingNew = false;
  bool _submitting = false;
  int _oldCountdown = 0;
  int _newCountdown = 0;
  Timer? _oldTimer;
  Timer? _newTimer;

  /// 服务端验证码冷却 60s，前端倒计时与之对齐
  static const int _resendSeconds = 60;

  static final RegExp _phoneRe = RegExp(r'^1[3-9]\d{9}$');
  static final RegExp _codeRe = RegExp(r'^\d{6}$');

  @override
  void dispose() {
    _oldTimer?.cancel();
    _newTimer?.cancel();
    _oldCodeCtrl.dispose();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startCountdown({required bool old}) {
    setState(() => old ? _oldCountdown = _resendSeconds : _newCountdown = _resendSeconds);
    final timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (old) {
          _oldCountdown--;
        } else {
          _newCountdown--;
        }
      });
      if ((old ? _oldCountdown : _newCountdown) <= 0) t.cancel();
    });
    if (old) {
      _oldTimer?.cancel();
      _oldTimer = timer;
    } else {
      _newTimer?.cancel();
      _newTimer = timer;
    }
  }

  /// 发送旧号验证码：发到当前登录手机号
  Future<void> _sendOldCode() async {
    if (_sendingOld || _oldCountdown > 0) return;
    final phone = context.read<AuthProvider>().user?.phone ?? '';
    if (phone.isEmpty) {
      showToast(context, '账号资料异常，请重新登录');
      return;
    }
    final passed = await _verifySlider();
    if (passed != true || !mounted) return;
    setState(() => _sendingOld = true);
    try {
      await _sms.sendSms(phone);
      if (!mounted) return;
      showToast(context, '验证码已发送到当前手机号');
      _startCountdown(old: true);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _sendingOld = false);
    }
  }

  /// 发送新号验证码：发到输入框里的新手机号
  Future<void> _sendNewCode() async {
    if (_sendingNew || _newCountdown > 0) return;
    final phone = _phoneCtrl.text.trim();
    if (!_phoneRe.hasMatch(phone)) {
      showToast(context, '请先输入正确的新手机号');
      return;
    }
    final passed = await _verifySlider();
    if (passed != true || !mounted) return;
    setState(() => _sendingNew = true);
    try {
      await _sms.sendSms(phone);
      if (!mounted) return;
      showToast(context, '验证码已发送到新手机号');
      _startCountdown(old: false);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _sendingNew = false);
    }
  }

  /// 拼图滑块：通过返回 true，取消返回 null
  Future<bool?> _verifySlider() {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('安全验证（滑动完成拼图）',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              SliderCaptcha(
                onComplete: () {
                  Future<void>.delayed(const Duration(milliseconds: 260), () {
                    if (ctx.mounted) Navigator.of(ctx).pop(true);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final oldCode = _oldCodeCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final code = _codeCtrl.text.trim();

    if (!_codeRe.hasMatch(oldCode)) {
      showToast(context, '请输入当前手机号的验证码');
      return;
    }
    if (!_phoneRe.hasMatch(phone)) {
      showToast(context, '新手机号格式不正确');
      return;
    }
    if (context.read<AuthProvider>().user?.phone == phone) {
      showToast(context, '新手机号不能与当前手机号相同');
      return;
    }
    if (!_codeRe.hasMatch(code)) {
      showToast(context, '请输入新手机号的验证码');
      return;
    }

    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    try {
      await _users.rebindPhone(oldCode: oldCode, phone: phone, code: code);
      if (!mounted) return;
      showToast(context, '手机号已换绑，请用新号重新登录');
      await auth.logout();
      if (!mounted) return;
      context.go('/login');
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maskedPhone =
        context.watch<AuthProvider>().user?.maskedPhone ?? '当前手机号';

    return Scaffold(
      appBar: AppBar(title: const Text('换绑手机号')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '当前手机号 $maskedPhone，换绑需要新旧两个号码各收一条验证码；换绑成功后需重新登录。',
            style: const TextStyle(fontSize: 13, color: kqwTextSecondary),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('第一步：验证当前手机号',
                      style: TextStyle(fontSize: 13, color: kqwTextSecondary)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _codeField(_oldCodeCtrl, '当前手机号验证码')),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 108,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: (_sendingOld || _oldCountdown > 0)
                              ? null
                              : _sendOldCode,
                          child: Text(
                            _sendingOld
                                ? '发送中'
                                : (_oldCountdown > 0
                                    ? '${_oldCountdown}s 后重发'
                                    : '获取验证码'),
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('第二步：绑定新手机号',
                      style: TextStyle(fontSize: 13, color: kqwTextSecondary)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 11,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: '新手机号',
                      prefixIcon: Icon(Icons.phone_iphone),
                      counter: SizedBox.shrink(),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _codeField(_codeCtrl, '新手机号验证码')),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 108,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: (_sendingNew || _newCountdown > 0)
                              ? null
                              : _sendNewCode,
                          child: Text(
                            _sendingNew
                                ? '发送中'
                                : (_newCountdown > 0
                                    ? '${_newCountdown}s 后重发'
                                    : '获取验证码'),
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '新号码必须未被注册。为保障账号安全，换绑后当前登录状态会失效。',
            style: TextStyle(fontSize: 12, color: kqwTextSecondary),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('确认换绑'),
          ),
        ),
      ),
    );
  }

  Widget _codeField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.sms_outlined),
        counter: const SizedBox.shrink(),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
