import 'package:flutter/material.dart';

import '../core/api/pos_api.dart';
import '../core/api_client.dart';
import '../core/models/machine.dart';
import '../core/toast.dart';
import '../core/widgets/install_form_fields.dart';

/// 按申请单装机（`POST /pos/applies/{id}/install`）。
///
/// 原来是从「申请列表」里弹 `AlertDialog`，弹窗高度被键盘挤得只剩几行、
/// 「确认装机」按钮容易被键盘顶掉，装机现场填 9 个字段体验很差，
/// 因此改成独立全屏页：字段与装机页共用 [InstallFormFields]，
/// 提交成功后 `pop(true)`，由列表页提示并刷新。
class InstallApplyPage extends StatefulWidget {
  const InstallApplyPage({super.key, required this.apply});

  /// 待装机的申请记录（决定预填值与 applyId）
  final MachineApply apply;

  @override
  State<InstallApplyPage> createState() => _InstallApplyPageState();
}

class _InstallApplyPageState extends State<InstallApplyPage> {
  /// 表单校验器只在 Form.validate() 时才执行，
  /// 不包 Form 的话「客户姓名 / 身份证后 6 位」的必填校验形同摆设
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _sn =
      TextEditingController(text: widget.apply.machineNo);
  late final TextEditingController _contact =
      TextEditingController(text: widget.apply.contactName ?? '');

  /// 客户身份证号后 6 位（实名核对；申请记录没存，装机现场必填）
  final TextEditingController _idTail = TextEditingController();
  late final TextEditingController _merchant =
      TextEditingController(text: widget.apply.merchantName ?? '');
  late final TextEditingController _region =
      TextEditingController(text: widget.apply.region ?? '');
  late final TextEditingController _address =
      TextEditingController(text: widget.apply.address ?? '');
  late final TextEditingController _remark =
      TextEditingController(text: widget.apply.remark ?? '');
  late final TextEditingController _trafficFee = TextEditingController();

  int _mode = 1;
  String? _brandId;
  String? _typeId;
  DateTime? _bootDate;
  List<PosBrandOption> _brands = const [];
  List<PosTypeOption> _types = const [];
  bool _loadingOptions = true;
  String? _optionsError;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _brandId = widget.apply.brandId;
    _typeId = widget.apply.typeId;
    _bootDate = widget.apply.bootTime;
    _loadOptions();
  }

  @override
  void dispose() {
    _sn.dispose();
    _contact.dispose();
    _idTail.dispose();
    _merchant.dispose();
    _region.dispose();
    _address.dispose();
    _remark.dispose();
    _trafficFee.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    var brands = const <PosBrandOption>[];
    var types = const <PosTypeOption>[];
    String? error;
    setState(() {
      _loadingOptions = true;
      _optionsError = null;
    });
    try {
      brands = await posApi.brands();
      types = await posApi.types();
    } on ApiException catch (e) {
      // 选项拉不到不阻断装机：品牌/类型留空由后端沿用申请记录，但要给出可重试的入口
      error = e.displayMessage;
    } finally {
      if (mounted) {
        setState(() {
          _brands = brands;
          _types = types;
          _optionsError = error;
          if (_brandId != null && !brands.any((b) => b.id == _brandId)) {
            _brandId = null;
          }
          if (_typeId != null && !types.any((t) => t.id == _typeId)) {
            _typeId = null;
          }
          _loadingOptions = false;
        });
      }
    }
  }

  Future<void> _pickBootDate() async {
    final picked = await pickInstallBootDate(context, _bootDate);
    if (picked != null && mounted) setState(() => _bootDate = picked);
  }

  Future<void> _submit() async {
    // 必填项没填完不发起装机：否则 idTail 会被 _installBody 静默丢掉
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    try {
      await posApi.installApply(
        applyId: widget.apply.applyId,
        machineNo: _sn.text.trim(),
        installMode: _mode,
        brandId: _brandId,
        typeId: _typeId,
        bootTime: _bootDate,
        trafficFeeRemark: _trafficFee.text.trim(),
        contactName: _contact.text.trim(),
        idTail: _idTail.text.trim(),
        merchantName: _merchant.text.trim(),
        region: _region.text.trim(),
        address: _address.text.trim(),
        remark: _remark.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } catch (_) {
      if (mounted) showToast(context, '装机失败，请稍后重试');
    } finally {
      // 成功时已经 pop，这里只在失败路径恢复按钮，避免「提交中…」永久置灰
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 提交中不让返回：此时关掉页面会让用户以为装机失败，而后端可能已经成功
      canPop: !_submitting,
      child: Scaffold(
        appBar: AppBar(title: const Text('安装 POS 机')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Form(
            key: _formKey,
            child: InstallFormFields(
              snController: _sn,
              trafficFeeController: _trafficFee,
              remarkController: _remark,
              installMode: _mode,
              onInstallModeChanged: (v) => setState(() => _mode = v),
              brands: _brands,
              types: _types,
              brandId: _brandId,
              typeId: _typeId,
              onBrandChanged: (v) => setState(() => _brandId = v),
              onTypeChanged: (v) => setState(() => _typeId = v),
              bootDate: _bootDate,
              onPickBootDate: _pickBootDate,
              optionsLoading: _loadingOptions,
              optionsError: _optionsError,
              onRetryOptions: _loadOptions,
              // 姓名与身份证后 6 位与装机页同源（共享字段与共享校验器）
              contactNameController: _contact,
              contactNameValidator: validateInstallContactName,
              idTailController: _idTail,
              idTailValidator: validateInstallIdTail,
              // 按 applyId 装机，比装机页多出「补录」三项
              extraFields: [
                installField('门店名称', child: _text(_merchant, '申请记录已填可留空')),
                installField('所在地区', child: _text(_region, '申请记录已填可留空')),
                installField('详细地址', child: _text(_address, '申请记录已填可留空')),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? '提交中…' : '确认装机'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _text(TextEditingController controller, String hint) => TextField(
        controller: controller,
        decoration: installInputDecoration(hint),
      );
}
