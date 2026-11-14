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

/// 交易密码（6 位数字，与登录密码互相独立）三态页：
/// - 未设置：短信验证码 + 新交易密码 → `POST /user/trade-password`
/// - 已设置：默认「修改」，旧交易密码 + 新交易密码 → `PUT /user/trade-password`
/// - 忘记：切到短信验证码重置 → `POST /user/trade-password/reset`
///
/// 交易密码用于积分转赠/商城兑换的二次确认，连续输错 5 次锁 30 分钟（服务端 20009）。
/// 成功后回读 `GET /user/me`，让设置页与业务页拿到最新 [UserInfo.tradePasswordSet]。
class TradePasswordPage extends StatefulWidget {
  const TradePasswordPage({super.key, this.smsApi, this.userApi});

  /// 测试注入点；生产走全局单例（见 [commonApi] / [userApi]）
  final CommonApi? smsApi;
  final UserApi? userApi;

  @override
  State<TradePasswordPage> createState() => _TradePasswordPageState();
}

enum _Mode { setup, change, reset }

class _TradePasswordPageState extends State<TradePasswordPage> {
  late final CommonApi _sms = widget.smsApi ?? commonApi;
  late final UserApi _users = widget.userApi ?? userApi;

  final _codeCtrl = TextEditingController();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  late _Mode _mode;
  bool _obscure = true;
  bool _sending = false;
  bool _submitting = false;
  int _countdown = 0;
  Timer? _timer;

  /// 服务端验证码冷却 60s，前端倒计时与之对齐
  static const int _resendSeconds = 60;

  /// 与服务端 TRADE_PASSWORD_RE 对齐
  static final RegExp _tradeRe = RegExp(r'^\d{6}$');

  @override
  void initState() {
    super.initState();
    final set = context.read<AuthProvider>().user?.tradePasswordSet ?? false;
    _mode = set ? _Mode.change : _Mode.setup;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeCtrl.dispose();
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _needCode => _mode != _Mode.change;

  String get _submitLabel => switch (_mode) {
        _Mode.setup => '设置交易密码',
        _Mode.change => '确认修改',
        _Mode.reset => '重置交易密码',
      };

  String get _title => switch (_mode) {
        _Mode.setup => '设置交易密码',
        _Mode.change => '交易密码',
        _Mode.reset => '重置交易密码',
      };

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

  /// 发送验证码到本人当前手机号：先过拼图滑块，再起 60s 倒计时
  Future<void> _sendCode() async {
    if (_sending || _countdown > 0) return;
    final phone = context.read<AuthProvider>().user?.phone ?? '';
    if (phone.isEmpty) {
      showToast(context, '账号资料异常，请重新登录');
      return;
    }
    final passed = await _verifySlider();
    if (passed != true || !mounted) return;
    setState(() => _sending = true);
    try {
      await _sms.sendSms(phone);
      if (!mounted) return;
      showToast(context, '验证码已发送，5 分钟内有效');
      _startCountdown();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _sending = false);
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
    final newPwd = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (_mode == _Mode.change) {
      final oldPwd = _oldCtrl.text.trim();
      if (!_tradeRe.hasMatch(oldPwd)) {
        showToast(context, '请输入 6 位旧交易密码');
        return;
      }
      if (!_tradeRe.hasMatch(newPwd)) {
        showToast(context, '新交易密码必须为 6 位数字');
        return;
      }
      if (oldPwd == newPwd) {
        showToast(context, '新交易密码不能与旧交易密码相同');
        return;
      }
      if (newPwd != confirm) {
        showToast(context, '两次输入的新交易密码不一致');
        return;
      }
    } else {
      if (!_tradeRe.hasMatch(_codeCtrl.text.trim())) {
        showToast(context, '请输入 6 位验证码');
        return;
      }
      if (!_tradeRe.hasMatch(newPwd)) {
        showToast(context, '交易密码必须为 6 位数字');
        return;
      }
      if (newPwd != confirm) {
        showToast(context, '两次输入的交易密码不一致');
        return;
      }
    }

    setState(() => _submitting = true);
    final auth = context.read<AuthProvider>();
    try {
      if (_mode == _Mode.setup) {
        await _users.setupTradePassword(
          code: _codeCtrl.text.trim(),
          tradePassword: newPwd,
        );
      } else if (_mode == _Mode.change) {
        await _users.changeTradePassword(
          oldTradePassword: _oldCtrl.text.trim(),
          newTradePassword: newPwd,
        );
      } else {
        await _users.resetTradePassword(
          code: _codeCtrl.text.trim(),
          tradePassword: newPwd,
        );
      }
      // 让设置页的「已设置/未设置」与业务页的验证门槛拿到最新状态
      await auth.loadProfile();
      if (!mounted) return;
      showToast(
          context, _mode == _Mode.change ? '交易密码已修改' : '交易密码已设置');
      context.pop();
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<AuthProvider>().user?.maskedPhone ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _mode == _Mode.change
                ? '交易密码用于积分转赠、商城兑换的二次确认'
                : '验证码将发送到本人手机号 $phone',
            style: const TextStyle(fontSize: 13, color: kqwTextSecondary),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_needCode) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _digitField(_codeCtrl, '验证码')),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 108,
                          height: 56,
                          child: OutlinedButton(
                            onPressed:
                                (_sending || _countdown > 0) ? null : _sendCode,
                            child: Text(
                              _sending
                                  ? '发送中'
                                  : (_countdown > 0
                                      ? '${_countdown}s 后重发'
                                      : '获取验证码'),
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (_mode == _Mode.change) ...[
                    _digitField(_oldCtrl, '旧交易密码'),
                    const SizedBox(height: 14),
                  ],
                  _digitField(_newCtrl, '新交易密码'),
                  const SizedBox(height: 14),
                  _digitField(_confirmCtrl, '确认新交易密码'),
                ],
              ),
            ),
          ),
          if (_mode == _Mode.change)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() => _mode = _Mode.reset),
                child: const Text('忘记交易密码？'),
              ),
            ),
          if (_mode == _Mode.reset)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() => _mode = _Mode.change),
                child: const Text('用旧交易密码修改'),
              ),
            ),
          const SizedBox(height: 8),
          const Text(
            '交易密码为 6 位数字，连续输错 5 次将锁定 30 分钟。',
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
                : Text(_submitLabel),
          ),
        ),
      ),
    );
  }

  /// 6 位数字输入框：只收数字、只能 6 位、默认掩码
  Widget _digitField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: _obscure,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      style: const TextStyle(fontSize: 15, letterSpacing: 4),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(
              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
