import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api/pos_api.dart';
import '../core/api_client.dart';
import '../core/models/machine.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import 'scan_page.dart';

/// 新增机器（绑定 POS 设备）。
///
/// 品牌 / 类型取自后端字典（`GET /pos/brands`、`GET /pos/types`，后台可配、仅启用项）；
/// 提交走 `POST /pos/machines`：机号全局唯一（重复返回 41009），
/// 机号能在后端查到归属用户则自动绑定客户，查不到就留空。
class AddMachinePage extends StatefulWidget {
  const AddMachinePage({super.key, this.api});

  /// 测试可注入的接口实现，缺省用全局 [posApi]
  final PosApi? api;

  @override
  State<AddMachinePage> createState() => _AddMachinePageState();
}

class _AddMachinePageState extends State<AddMachinePage> {
  late final PosApi _api = widget.api ?? posApi;

  final _formKey = GlobalKey<FormState>();
  final _snCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _trafficFeeCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();

  List<PosBrandOption> _brands = const [];
  List<PosTypeOption> _types = const [];
  bool _optionsLoading = true;
  String? _optionsError;

  String? _brandId;
  String? _typeId;
  DateTime? _bootDate;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _snCtrl.dispose();
    _phoneCtrl.dispose();
    _trafficFeeCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  /// 品牌 / 类型字典（后台维护，改完即时生效）
  Future<void> _loadOptions() async {
    setState(() {
      _optionsLoading = true;
      _optionsError = null;
    });
    try {
      final brands = await _api.brands();
      final types = await _api.types();
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _types = types;
        // 重新加载后原来的选中项可能已停用，清掉避免下拉断言
        if (!brands.any((b) => b.id == _brandId)) _brandId = null;
        if (!types.any((t) => t.id == _typeId)) _typeId = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _optionsError = e.displayMessage);
    } finally {
      if (mounted) setState(() => _optionsLoading = false);
    }
  }

  String? _validateSn(String? value) {
    final sn = (value ?? '').trim();
    if (sn.isEmpty) return '请输入机器序列号';
    if (sn.length < 6) return '机器号至少 6 位';
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) return '请输入客户手机号';
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) return '手机号格式不正确';
    return null;
  }

  /// 扫码录入机器号：识别成功后回填输入框并把光标放末尾
  Future<void> _scanToFillSn() async {
    FocusScope.of(context).unfocus();
    final scanned = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanPage(title: '扫描机器号')),
    );
    if (!mounted || scanned == null) return;
    final sn = scanned.trim();
    if (sn.isEmpty) return;
    _snCtrl.text = sn;
    _snCtrl.selection = TextSelection.collapsed(offset: sn.length);
    setState(() {});
  }

  Future<void> _pickBootDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _bootDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: '选择开机日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) setState(() => _bootDate = picked);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final result = await _api.addMachine(
        machineNo: _snCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim(),
        brandId: _brandId,
        typeId: _typeId,
        trafficFeeRemark: _trafficFeeCtrl.text.trim(),
        bootTime: _bootDate,
        remark: _remarkCtrl.text.trim(),
      );
      if (!mounted) return;
      showToast(
        context,
        result.bound ? '添加成功，机号已绑定到该客户' : '添加成功，机号暂未对上客户，等待后台处理',
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('新增机器'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '关闭',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _labeled(
                '机器号',
                required: true,
                child: TextFormField(
                  controller: _snCtrl,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z_-]')),
                    LengthLimitingTextInputFormatter(64),
                  ],
                  validator: _validateSn,
                  decoration: InputDecoration(
                    hintText: '请输入机器序列号',
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: _border(),
                    enabledBorder: _border(),
                    focusedBorder: _focusedBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner,
                          size: 20, color: Color(0xFF8A93A6)),
                      tooltip: '扫码录入',
                      onPressed: _scanToFillSn,
                    ),
                  ),
                ),
              ),
              _labeled(
                '客户手机号',
                required: true,
                child: TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  validator: _validatePhone,
                  decoration: _inputDecoration('请输入客户手机号'),
                ),
              ),
              _labeled('品牌', child: _brandField()),
              _labeled('类型', child: _typeField()),
              _labeled(
                '流量费备注',
                child: TextFormField(
                  controller: _trafficFeeCtrl,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
                  decoration: _inputDecoration('如：流量费孔出、月租 5 元'),
                ),
              ),
              _labeled(
                '开机时间',
                child: _dateField(),
              ),
              _labeled(
                '备注',
                child: TextFormField(
                  controller: _remarkCtrl,
                  maxLines: 3,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  decoration: _inputDecoration('其他备注'),
                ),
              ),
              const SizedBox(height: 12),
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
                      : const Text('确认添加',
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

  // ---------- 品牌 / 类型下拉 ----------

  Widget _brandField() {
    if (_optionsLoading) return _optionPlaceholder('品牌加载中…');
    if (_optionsError != null) return _optionFailed();
    return DropdownButtonFormField<String>(
      initialValue: _brandId,
      isExpanded: true,
      decoration: _dropdownDecoration(_brands.isEmpty ? '暂无可选品牌' : '请选择品牌'),
      items: [
        for (final brand in _brands)
          DropdownMenuItem(value: brand.id, child: Text(brand.name)),
      ],
      onChanged: (v) => setState(() => _brandId = v),
    );
  }

  Widget _typeField() {
    if (_optionsLoading) return _optionPlaceholder('类型加载中…');
    if (_optionsError != null) return _optionFailed();
    return DropdownButtonFormField<String>(
      initialValue: _typeId,
      isExpanded: true,
      decoration: _dropdownDecoration(_types.isEmpty ? '暂无可选类型' : '请选择类型'),
      items: [
        for (final type in _types)
          DropdownMenuItem(value: type.id, child: Text(type.name)),
      ],
      onChanged: (v) => setState(() => _typeId = v),
    );
  }

  Widget _optionPlaceholder(String text) => Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDDE2EA)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const SizedBox(
                width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Text(text,
                style: const TextStyle(fontSize: 14, color: Color(0xFF9AA3B2))),
          ],
        ),
      );

  /// 字典加载失败：点一下重试（不打断已填写的机器号 / 手机号）
  Widget _optionFailed() => InkWell(
        onTap: _loadOptions,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDDE2EA)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _optionsError ?? '选项加载失败，点击重试',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF9AA3B2)),
                ),
              ),
              const Icon(Icons.refresh, size: 18, color: Color(0xFF8A93A6)),
            ],
          ),
        ),
      );

  // ---------- 字段容器与样式 ----------

  /// 标签在上、输入框在下的登录风格，与截图一致；[required] 时标签前加红星
  Widget _labeled(String label, {required Widget child, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (required)
                const Text('*',
                    style: TextStyle(fontSize: 13, color: Color(0xFFE53935))),
              if (required) const SizedBox(width: 2),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF4A5160))),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _dateField() {
    final text = _bootDate == null
        ? '选择开机日期'
        : '${_bootDate!.year}-${_two(_bootDate!.month)}-${_two(_bootDate!.day)}';
    return InkWell(
      onTap: _pickBootDate,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFDDE2EA)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                    fontSize: 14,
                    color: _bootDate == null
                        ? const Color(0xFF9AA3B2)
                        : const Color(0xFF1F2430)),
              ),
            ),
            const Icon(Icons.calendar_today_outlined,
                size: 18, color: Color(0xFF8A93A6)),
          ],
        ),
      ),
    );
  }

  OutlineInputBorder _border() => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDE2EA)),
      );

  OutlineInputBorder _focusedBorder() => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2E7BFF), width: 1.4),
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _focusedBorder(),
      );

  InputDecoration _dropdownDecoration(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _focusedBorder(),
        suffixIcon: const Icon(Icons.keyboard_arrow_down,
            size: 20, color: Color(0xFF8A93A6)),
      );

  static String _two(int v) => v.toString().padLeft(2, '0');
}
