import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api/pos_api.dart';
import '../core/api_client.dart';
import '../core/models/machine.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import '../core/widgets/async_view.dart';
import '../core/widgets/install_form_fields.dart';
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
  /// 安装方式：1 平台安装（业务员上门）/ 2 用户自装
  int _installMode = 1;
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
    // 申请记录已有机号时可不传，传了必须与记录一致
    if (sn.isEmpty) return null;
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

    // 一次装一台：先查号码名下待装申请，0 条提示、1 条直接装、多条让业务员选一条
    final phone = _phoneCtrl.text.trim();
    setState(() => _submitting = true);
    PendingInstallPreview preview;
    try {
      preview = await _api.pendingAppliesByPhone(phone);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
      return;
    } catch (_) {
      // 解析/类型类异常：给可读提示，别让按钮卡在「提交中」
      if (mounted) showToast(context, '查询待装申请失败，请重试');
      return;
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
    if (!mounted) return;

    if (!preview.found || preview.items.isEmpty) {
      showToast(
        context,
        preview.message.isNotEmpty
            ? preview.message
            : '该手机号没有待处理的装机申请，请先提交申请或核对号码',
      );
      return;
    }

    var target = preview.items.first;
    if (preview.items.length > 1) {
      final picked = await _showApplyPicker(preview.items);
      if (picked == null) return;
      target = picked;
    }
    if (!mounted) return;

    // 记录已带机号而输入框空着时回填，避免装机时与申请记录对不上
    final savedNo = target.machineNo?.trim() ?? '';
    if (_snCtrl.text.trim().isEmpty && savedNo.isNotEmpty) {
      _snCtrl.text = savedNo;
      _snCtrl.selection = TextSelection.collapsed(offset: savedNo.length);
    }

    setState(() => _submitting = true);
    try {
      final result = await _api.installApply(
        applyId: target.applyId,
        machineNo: _snCtrl.text.trim(),
        installMode: _installMode,
        brandId: _brandId,
        typeId: _typeId,
        trafficFeeRemark: _trafficFeeCtrl.text.trim(),
        bootTime: _bootDate,
        remark: _remarkCtrl.text.trim(),
      );
      if (!mounted) return;
      // 回显的申请单必须就是刚选的那台：对不上说明机号已被别的机器/申请占用，
      // 这一单并没有落库（没有安装人、没有机号），不能提示成功
      if (result.applyId != target.applyId) {
        showToast(context, '该机号已被其他机器占用，本次装机未生效，请换一个机号重试');
        return;
      }
      showToast(context, '装机成功，机号 ${result.machineNo} 已加入「我的机器」');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// 多台待装时选一条申请记录（返回 null = 取消，本次不装）
  Future<PendingInstallApply?> _showApplyPicker(List<PendingInstallApply> items) {
    return showModalBottomSheet<PendingInstallApply>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt, size: 18, color: kqwPrimary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '该号码有 ${items.length} 台待装机器，选一台开始装机',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final a = items[i];
                    return ListTile(
                      onTap: () => Navigator.of(ctx).pop(a),
                      leading: const Icon(Icons.point_of_sale,
                          size: 20, color: kqwPrimary),
                      title: Text(
                        a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        [
                          a.phone,
                          if (a.sourceName.isNotEmpty) a.sourceName,
                          if (a.brandName != null) a.brandName!,
                          if (a.typeName != null) a.typeName!,
                          if ((a.machineNo ?? '').isNotEmpty)
                            '机号 ${a.machineNo}',
                          if (a.submittedAt != null)
                            '提交 ${formatShortTime(a.submittedAt)}',
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 18),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('安装 POS 机'),
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
              InstallFormFields(
                snController: _snCtrl,
                trafficFeeController: _trafficFeeCtrl,
                remarkController: _remarkCtrl,
                installMode: _installMode,
                onInstallModeChanged: (v) => setState(() => _installMode = v),
                brands: _brands,
                types: _types,
                brandId: _brandId,
                typeId: _typeId,
                onBrandChanged: (v) => setState(() => _brandId = v),
                onTypeChanged: (v) => setState(() => _typeId = v),
                bootDate: _bootDate,
                onPickBootDate: _pickBootDate,
                optionsLoading: _optionsLoading,
                optionsError: _optionsError,
                onRetryOptions: _loadOptions,
                snValidator: _validateSn,
                onScanSn: _scanToFillSn,
                // 手机号是装机页独有的「按号码查待装申请」入口，弹窗按 applyId 装机不需要
                phoneField: installField(
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
                    decoration: installInputDecoration('申请时填写的使用人手机号'),
                  ),
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

}
