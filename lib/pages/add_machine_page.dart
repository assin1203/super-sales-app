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

/// 同一客户同一品牌的装机上限：装机核对时用于提醒（后端不拦截，业务规则）
const int _BRAND_INSTALL_LIMIT = 2;

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
  final _snFocusNode = FocusNode();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _idTailCtrl = TextEditingController();
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

  /// 扫/输机号后查到的机具档案（台账 → 申请单 → 已装机机器）
  PosMachineProfile? _profile;
  /// 正在按机号查档案：期间显示 loading，避免业务员以为没生效重复扫码
  bool _profileLoading = false;
  /// 已查过且查询成功的机号，防止输入框失焦时对同一机号重复请求
  ///
  /// 只在成功时写入：查询失败（网络抖动/后端 5xx）后业务员再失焦要能重试。
  String _profileQueriedSn = '';
  /// 正在飞的档案请求序号：旧请求返回时不能清掉新请求的 loading
  int _profileRequestSeq = 0;
  /// 上一次由机具档案自动回填的品牌/类型：换机号时只清这两个，保留业务员手选
  String? _autoBrandId;
  String? _autoTypeId;

  /// 实名核对结果（姓名 + 身份证后 6 位查该客户已装机器），null = 还没核对
  InstalledMachines? _installed;
  bool _checkingIdentity = false;
  /// 业务员已确认核对结果：false 时不允许提交（提交前必须先核对）
  bool _identityConfirmed = false;
  /// 已核对通过的「姓名 + 身份证后 6 位 + 手机号」快照
  ///
  /// 手机号决定这条核对结果最终装在谁的申请单上，改名/改号都要重新核对。
  String _verifiedName = '';
  String _verifiedIdTail = '';
  String _verifiedPhone = '';

  @override
  void initState() {
    super.initState();
    _snFocusNode.addListener(_onSnFocusChanged);
    // 姓名/身份证/手机号一改，上一次的核对结果就作废，必须重新核对
    _nameCtrl.addListener(_resetIdentityCheck);
    _idTailCtrl.addListener(_resetIdentityCheck);
    _phoneCtrl.addListener(_resetIdentityCheck);
    _loadOptions();
  }

  @override
  void dispose() {
    _snFocusNode.removeListener(_onSnFocusChanged);
    _snFocusNode.dispose();
    _nameCtrl.removeListener(_resetIdentityCheck);
    _idTailCtrl.removeListener(_resetIdentityCheck);
    _phoneCtrl.removeListener(_resetIdentityCheck);
    _snCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _idTailCtrl.dispose();
    _trafficFeeCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  /// 姓名/身份证/手机号变化后作废核对结果（已确认的也要重新确认）
  ///
  /// 只在文本真的变了才作废：控制器连光标/选区变化也会通知，
  /// 按通知清理会让业务员点一下输入框就丢掉已核对的结果。
  void _resetIdentityCheck() {
    if (!_identityConfirmed) return;
    if (_nameCtrl.text.trim() == _verifiedName &&
        normalizeInstallIdTail(_idTailCtrl.text) == _verifiedIdTail &&
        _phoneCtrl.text.trim() == _verifiedPhone) {
      return;
    }
    setState(() {
      _identityConfirmed = false;
      _installed = null;
    });
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
        // 扫码可能早于字典返回：那时回填不了，这里用已查到的档案补一次
        final profile = _profile;
        if (profile != null) _applyProfileSelection(profile);
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

  /// 按姓名 + 身份证后 6 位查该客户已装机器，弹窗核对（只展示机器号与品牌）
  ///
  /// 确认后 [_identityConfirmed] 置 true，提交按钮才放行；姓名/身份证/手机号一改结果作废。
  Future<void> _verifyInstalled() async {
    if (_checkingIdentity) return;
    final name = _nameCtrl.text.trim();
    final idTail = normalizeInstallIdTail(_idTailCtrl.text);
    if (name.isEmpty) {
      showToast(context, '请先填写客户姓名');
      return;
    }
    if (validateInstallIdTail(idTail) != null) {
      showToast(context, '请填写身份证号最后 6 位（末位可为 X）');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _checkingIdentity = true);
    InstalledMachines result;
    try {
      result = await _api.installedMachines(name: name, idTail: idTail);
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
      return;
    } catch (_) {
      if (mounted) showToast(context, '查询已装机器失败，请重试');
      return;
    } finally {
      if (mounted) setState(() => _checkingIdentity = false);
    }
    if (!mounted) return;

    // 查询期间姓名/身份证被改：这份结果对不上，不弹窗，让业务员重新核对
    if (_nameCtrl.text.trim() != name ||
        _idTailCtrl.text.trim().toUpperCase() != idTail) {
      return;
    }
    final confirmed = await _showInstalledResult(result);
    if (!mounted || confirmed != true) return;
    setState(() {
      _installed = result;
      _identityConfirmed = true;
      // 记下这次核对的输入：只有文本真的变了才作废（光标移动不算）
      _verifiedName = name;
      _verifiedIdTail = idTail;
      _verifiedPhone = _phoneCtrl.text.trim();
    });
  }

  /// 已装机器按品牌汇总台数：同品牌上限 2 台是给装机人员的提示（不拦截提交）
  Map<String, int> _brandCounts(List<InstalledMachineItem> items) {
    final counts = <String, int>{};
    for (final item in items) {
      final key = item.brandName.isEmpty ? '品牌未知' : item.brandName;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// 已装机器核对弹窗：合计台数 + 按品牌台数 + 机器号清单，确认返回 true
  ///
  /// 同一品牌不超过 2 台是业务规则，这里只提示装机人员核对，不阻断提交。
  Future<bool?> _showInstalledResult(InstalledMachines result) {
    final brandCounts = _brandCounts(result.items).entries.toList();
    final fullBrands =
        brandCounts.where((e) => e.value >= _BRAND_INSTALL_LIMIT).toList();

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(result.found ? '该客户已装机 ${result.total} 台' : '未查到装机记录'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.message.isNotEmpty
                    ? result.message
                    : (result.found
                        ? '请核对机器号与品牌后再提交'
                        : '未查到该客户的装机记录'),
                style: const TextStyle(fontSize: 13, color: Color(0xFF4A5160)),
              ),
              if (brandCounts.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '按品牌统计（同一品牌上限 $_BRAND_INSTALL_LIMIT 台）',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8A93A6)),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final entry in brandCounts)
                      _brandChip(
                        entry.key,
                        entry.value,
                        reachedLimit: entry.value >= _BRAND_INSTALL_LIMIT,
                      ),
                  ],
                ),
              ],
              if (fullBrands.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '${fullBrands.map((e) => e.key).join('、')} 已达 $_BRAND_INSTALL_LIMIT 台上限，'
                  '请与客户确认后装机（仅提示，不拦截提交）',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFE53935)),
                ),
              ],
              if (result.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.35,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: result.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = result.items[i];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.point_of_sale,
                            size: 18, color: kqwPrimary),
                        title: Text(
                          item.machineNo,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          item.brandName.isEmpty ? '品牌未知' : item.brandName,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('重新核对'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(result.found ? '确认无误，继续装机' : '确认，继续装机'),
          ),
        ],
      ),
    );
  }

  /// 品牌台数小标签：达到上限用红色
  Widget _brandChip(String brand, int count, {required bool reachedLimit}) {
    final color = reachedLimit ? const Color(0xFFE53935) : const Color(0xFF4A5160);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: reachedLimit ? const Color(0xFFFDECEC) : const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$brand $count 台',
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
  }

  /// 机器号输入框失焦：手输完成（≥6 位）也走一次机具档案查询，效果与扫码一致
  void _onSnFocusChanged() {
    if (_snFocusNode.hasFocus) return;
    final sn = _snCtrl.text.trim();
    if (sn.length < 6) return;
    if (sn == _profileQueriedSn && !_profileLoading) return;
    _loadProfile(sn);
  }

  /// 按机号查机具档案并回填品牌/类型
  ///
  /// 命中台账即把品牌/类型直接选中（业务员不用手填）；没命中只提示，保持手选。
  /// 一台机器只会有一个档案：已装机/已报废这类提示由后端 message 给出，这里只负责展示。
  Future<void> _loadProfile(String sn) async {
    final seq = ++_profileRequestSeq;
    setState(() {
      // 换了机号：上一台的档案、提示与自动回带的品牌/类型立刻作废，
      // 否则新机号在台账里查不到品牌时会把上一台的品牌带过去装机
      _profile = null;
      _clearAutoSelection();
      _profileLoading = true;
    });
    try {
      final profile = await _api.machineProfile(sn);
      if (!mounted || seq != _profileRequestSeq) return;
      // 查询期间业务员可能又改了机号：结果对不上就丢弃，避免把别的机器信息填进来
      if (_snCtrl.text.trim() != sn) return;
      setState(() {
        _profile = profile;
        // 只记成功的机号：失败后同一机号再失焦可以重试
        _profileQueriedSn = sn;
        _applyProfileSelection(profile);
      });
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } catch (_) {
      // 查询失败不挡装机：业务员照样可以手选品牌/类型
      if (mounted) showToast(context, '机具信息查询失败，请手动选择品牌/类型');
    } finally {
      // 只有最新一次请求能关 loading：扫码 + 失焦并发时旧请求不能提前清掉
      if (mounted && seq == _profileRequestSeq) {
        setState(() => _profileLoading = false);
      }
    }
  }

  /// 把档案里的品牌/类型回填到下拉框
  ///
  /// 只认字典里还启用着的项（停用就留给业务员手选）；已经手选过的不覆盖，
  /// 字典还没加载完（`_brands` / `_types` 为空）时留空，等 [_loadOptions] 回来再补一次。
  void _applyProfileSelection(PosMachineProfile profile) {
    final brandId = profile.brandId;
    if (brandId != null &&
        _brandId == null &&
        _brands.any((b) => b.id == brandId)) {
      _brandId = brandId;
      _autoBrandId = brandId;
    }
    final typeId = profile.typeId;
    if (typeId != null && _typeId == null && _types.any((t) => t.id == typeId)) {
      _typeId = typeId;
      _autoTypeId = typeId;
    }
  }

  /// 换机号时清掉「上一次由档案回填」的品牌/类型，业务员手选的不动
  void _clearAutoSelection() {
    if (_autoBrandId != null && _brandId == _autoBrandId) _brandId = null;
    if (_autoTypeId != null && _typeId == _autoTypeId) _typeId = null;
    _autoBrandId = null;
    _autoTypeId = null;
  }

  /// 扫码录入机器号：识别成功后回填输入框，并立刻查机具档案回带品牌/类型
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
    // 上一台的档案由 _loadProfile 统一作废（两条入口行为一致）
    await _loadProfile(sn);
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
    // 先核对客户已装机器再装机：没核对/改了姓名身份证都不放行
    if (!_identityConfirmed) {
      showToast(context, '请先点「核对已装机器」，确认客户信息后再提交');
      return;
    }
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
        // 实名核对用的两项：姓名 + 身份证后 6 位（后端只填空位，不覆盖已有值）
        contactName: _nameCtrl.text.trim(),
        idTail: normalizeInstallIdTail(_idTailCtrl.text),
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

  /// 机具信息卡片：扫码/输机号后展示机型、台账状态与后端提示（品牌/类型已自动选中）
  Widget _machineInfoCard() {
    final profile = _profile;
    final specs = profile?.specsLine ?? '';
    final trafficFee = profile?.trafficFee ?? '';
    final tips = <String>[
      if (specs.isNotEmpty) specs,
      if (trafficFee.isNotEmpty) '流量费 $trafficFee 元',
      if ((profile?.message ?? '').isNotEmpty) profile!.message,
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDE2EA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_profileLoading)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Icon(
              profile?.installed == true
                  ? Icons.warning_amber_rounded
                  : Icons.info_outline,
              size: 16,
              color: profile?.installed == true
                  ? const Color(0xFFE53935)
                  : const Color(0xFF8A93A6),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _profileLoading && tips.isEmpty
                  ? '正在识别机具信息…'
                  : (tips.isEmpty ? '未查到机具信息' : tips.join('\n')),
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: profile?.installed == true
                    ? const Color(0xFFE53935)
                    : const Color(0xFF4A5160),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 实名核对区：「核对已装机器」按钮 + 当前核对状态
  Widget _identityCheckBlock() {
    final confirmed = _identityConfirmed;
    final installed = _installed;
    final String status;
    if (!confirmed || installed == null) {
      status = '提交前需按姓名和身份证号核对客户已装机器';
    } else if (!installed.found) {
      status = '已确认：未查到该客户的装机记录';
    } else {
      final full = _brandCounts(installed.items)
          .entries
          .where((e) => e.value >= _BRAND_INSTALL_LIMIT)
          .map((e) => e.key)
          .toList();
      status = full.isEmpty
          ? '已确认：该客户已装 ${installed.total} 台'
          : '已确认：该客户已装 ${installed.total} 台，${full.join('、')} 已达 $_BRAND_INSTALL_LIMIT 台';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: confirmed ? const Color(0xFF1F9D55) : const Color(0xFF9AA3B2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _checkingIdentity ? null : _verifyInstalled,
            style: OutlinedButton.styleFrom(
              foregroundColor: kqwPrimary,
              side: const BorderSide(color: kqwPrimary),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
            child: _checkingIdentity
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(confirmed ? '重新核对' : '核对已装机器', style: const TextStyle(fontSize: 13)),
          ),
        ],
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
                snFocusNode: _snFocusNode,
                // 扫码/输机号带出的机具信息（品牌/类型已自动选中，这里只做展示与提示）
                machineInfo: _profileLoading || _profile != null ? _machineInfoCard() : null,
                contactNameController: _nameCtrl,
                contactNameValidator: validateInstallContactName,
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
                idTailController: _idTailCtrl,
                idTailValidator: validateInstallIdTail,
                identityCheck: _identityCheckBlock(),
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
