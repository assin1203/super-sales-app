import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api/points_api.dart';
import '../core/api_client.dart';
import '../core/models/points_summary.dart';
import '../core/request_no.dart';
import '../core/theme.dart';
import '../core/toast.dart';

/// 送积分（FR-8.3 会员互赠）：把积分转给指定手机号的会员。
///
/// 数据源 `POST /points/transfers`：扣转出方 → 加接收方，双方各留一条
/// `GIFT_PEER` 流水。单次上限 100、每日 5 次由后端判定（60007 / 60008），
/// 这里只做输入前置校验，规则文案与后端常量保持一致。
class PointsTransferPage extends StatefulWidget {
  const PointsTransferPage({super.key, this.api});

  /// 测试注入用；生产走全局 [pointsApi]
  final PointsApi? api;

  @override
  State<PointsTransferPage> createState() => _PointsTransferPageState();
}

class _PointsTransferPageState extends State<PointsTransferPage> {
  /// 对齐后端 MAX_SINGLE_POINTS / MAX_DAILY_TRANSFERS，仅用于提示与前置校验
  static const int _maxSingle = 100;
  static const int _maxDaily = 5;

  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _pointsCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();

  PointsSummary _summary = PointsSummary.empty;
  bool _submitting = false;

  /// 同一笔转让意图复用同一个幂等键：超时重试不会重复扣分；
  /// 一旦改了手机号/积分/备注就作废，下次提交重新生成。
  String? _requestNo;

  /// 注入优先（测试用），生产落到全局单例
  PointsApi get _api => widget.api ?? pointsApi;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pointsCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await _api.summary();
      if (!mounted) return;
      setState(() => _summary = summary);
    } on ApiException {
      // 概览拉不到不拦着填写，提交时后端仍会校验余额
    }
  }

  void _invalidateRequestNo() => _requestNo = null;

  String? _validatePhone(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) return '请输入接收方手机号';
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) return '手机号格式不正确';
    return null;
  }

  String? _validatePoints(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return '请输入转让积分';
    final points = int.tryParse(text);
    if (points == null || points <= 0) return '积分必须是正整数';
    if (points > _maxSingle) return '单次最多转让 $_maxSingle 积分';
    if (points > _summary.balanceValue) {
      return '可用积分不足（当前 ${_summary.balance}）';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final phone = _phoneCtrl.text.trim();
    final points = int.parse(_pointsCtrl.text.trim());
    final remark = _remarkCtrl.text.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认赠送',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('接收方', _maskPhone(phone)),
            const SizedBox(height: 8),
            _confirmRow('赠送积分', '$points'),
            if (remark.isNotEmpty) ...[
              const SizedBox(height: 8),
              _confirmRow('备注', remark),
            ],
            const SizedBox(height: 12),
            const Text('积分转出后不可撤回，请确认手机号无误。',
                style: TextStyle(fontSize: 12, color: Colors.black45)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认赠送',
                style: TextStyle(color: kqwPrimary)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    _requestNo ??= newRequestNo();
    try {
      final result = await _api.transfer(
        toPhone: phone,
        points: points,
        remark: remark,
        requestNo: _requestNo,
      );
      _requestNo = null;
      if (!mounted) return;
      showToast(
        context,
        result.idempotent ? '该笔转让已处理过' : '已转赠 ${result.points} 积分',
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(context, e.displayMessage);
      // 保留 _requestNo：同参数的失败重试要复用幂等键，避免重复扣分
      setState(() => _submitting = false);
      // 余额可能已变（如刚被其他端消耗），刷新一次可用积分
      _loadSummary();
    }
  }

  Widget _confirmRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, color: Color(0xFF1F2430))),
          ),
        ],
      );

  static String _maskPhone(String phone) =>
      phone.length == 11 ? '${phone.substring(0, 3)}****${phone.substring(7)}' : phone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kqwPageBg,
      appBar: AppBar(title: const Text('送积分')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _balanceCard(),
              const SizedBox(height: 16),
              _formCard(),
              const SizedBox(height: 12),
              const Text(
                '· 单次最多 $_maxSingle 积分，每日最多 $_maxDaily 次\n'
                '· 接收方须为已注册会员，按手机号转入\n'
                '· 转出后不可撤回，双方可在积分流水中查看',
                style: TextStyle(
                    fontSize: 12, height: 1.7, color: kqwTextSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: kqwPrimary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('确认赠送',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _balanceCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: kqwHeaderGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('可用积分',
                  style: TextStyle(fontSize: 12, color: Color(0xCCFFFFFF))),
              const SizedBox(height: 6),
              Text(_summary.balance,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.card_giftcard,
              size: 34, color: Color(0x66FFFFFF)),
        ],
      ),
    );
  }

  Widget _formCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(
          children: [
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              onChanged: (_) => _invalidateRequestNo(),
              validator: _validatePhone,
              decoration: const InputDecoration(
                labelText: '接收方手机号',
                hintText: '请输入 11 位手机号',
                border: InputBorder.none,
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEF1F6)),
            TextFormField(
              controller: _pointsCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => _invalidateRequestNo(),
              validator: _validatePoints,
              decoration: const InputDecoration(
                labelText: '赠送积分',
                hintText: '最多 $_maxSingle',
                border: InputBorder.none,
                suffixText: '积分',
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEF1F6)),
            TextFormField(
              controller: _remarkCtrl,
              maxLength: 100,
              onChanged: (_) => _invalidateRequestNo(),
              decoration: const InputDecoration(
                labelText: '备注（选填）',
                hintText: '会显示在双方的积分流水里',
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
