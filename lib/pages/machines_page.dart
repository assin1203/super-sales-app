import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api/pos_api.dart';
import '../core/api_client.dart';
import '../core/auth_provider.dart';
import '../core/models/machine.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import '../core/widgets/async_view.dart';
import '../core/widgets/install_form_fields.dart';

/// 我的机器（FR-3.x：机器编号 / 开机时间 / 推荐人 / 新手任务完成状态）
///
/// 数据源 `GET /pos/machines`：已装机机器分页 + `applies`（申请中的新增机器）。
/// 同一用户/同一客户手机号可以有多台，申请中的记录在装机完成前也能看到。
/// 提交达标走 `POST /pos/newbie/submit`。
/// 本页只读，申请新机器走右上角「申请新机器」（与首页「申请 POS 机」同一页 `/machine/apply`）。
class MachinesPage extends StatefulWidget {
  const MachinesPage({super.key, this.api});

  /// 测试可注入的接口实现，缺省用全局 [posApi]
  final PosApi? api;

  @override
  State<MachinesPage> createState() => _MachinesPageState();
}

class _MachinesPageState extends State<MachinesPage> {
  List<Machine> _machines = const [];
  List<MachineApply> _applies = const [];
  bool _loading = true;
  String? _error;
  String? _appliesError;
  String? _busySn;

  /// 注入的接口实现，缺省用全局 [posApi]
  PosApi get _api => widget.api ?? posApi;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _appliesError = null;
    });
    // 两个列表相互独立：申请列表失败不影响已装机机器的展示
    try {
      try {
        final list = await _api.machines();
        if (!mounted) return;
        setState(() => _machines = list.items);
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _machines = const [];
          _error = e.displayMessage;
        });
      } catch (_) {
        // 解析/类型类异常（非 ApiException）同样属于「这一段加载失败」，
        // 不能漏出去让 finally 之外的收尾逻辑失效，否则页面永久停在加载态
        if (!mounted) return;
        setState(() {
          _machines = const [];
          _error = '机器列表解析失败，请稍后重试';
        });
      }

      try {
        final applies = await _api.applies();
        if (!mounted) return;
        setState(() => _applies = applies.items);
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _applies = const [];
          _appliesError = e.displayMessage;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _applies = const [];
          _appliesError = '申请列表解析失败，请稍后重试';
        });
      }
    } finally {
      // 无论两段各自成败（含提前 return）都要退出加载态
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 申请新机器：与首页「申请 POS 机」同一页，提交成功后就地刷新列表
  /// （首页是跳回本页，这里已经在本页，只需重拉申请列表）
  Future<void> _openApply() async {
    final submitted = await context.push<bool>('/machine/apply');
    if (!mounted || submitted != true) return;
    await _load();
  }

  Future<void> _submitNewbie(Machine m) async {
    setState(() => _busySn = m.sn);
    try {
      final result = await _api.submitNewbie(m.sn);
      if (!mounted) return;
      showToast(context, '达标申请已提交，后台人工审核通过后发放奖励');
      // 用返回值就地置「审核中」，不整页重拉（申请列表与本条进度不受影响）
      setState(() {
        _machines = [
          for (final item in _machines)
            item.sn == m.sn
                ? item.copyWith(
                    newbieStatus: result.newbieStatus,
                    newbieStatusName: result.newbieStatusName,
                    clearRejectReason: true,
                  )
                : item,
        ];
      });
    } on ApiException catch (e) {
      if (mounted) showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _busySn = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('我的机器'),
          actions: [
            TextButton.icon(
              onPressed: _openApply,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('申请新机器'),
              style: TextButton.styleFrom(foregroundColor: kqwPrimary),
            ),
            const SizedBox(width: 8),
          ],
          bottom: TabBar(
            labelColor: kqwPrimary,
            unselectedLabelColor: Colors.black54,
            indicatorColor: kqwPrimary,
            tabs: [
              Tab(text: _tabLabel('已提交', _applies.length)),
              Tab(text: _tabLabel('已安装', _machines.length)),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          // 空态分到各自 tab，页级只处理加载中与失败
          child: AsyncStateView(
            loading: _loading,
            error: _error,
            isEmpty: false,
            onRetry: _load,
            child: TabBarView(
              children: [
                _applyTab(),
                _machineTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _tabLabel(String name, int count) =>
      count == 0 ? name : '$name ($count)';

  /// 已提交：还在审核/装机中的申请记录
  Widget _applyTab() {
    return AsyncStateView(
      loading: false,
      error: _appliesError,
      isEmpty: _applies.isEmpty,
      onRetry: _load,
      emptyText: '还没有提交过的申请，点右上角「申请新机器」提交',
      emptyIcon: Icons.assignment_outlined,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          for (final apply in _applies) ...[
            _applyCard(apply),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  /// 已安装：已装机的机器
  Widget _machineTab() {
    return AsyncStateView(
      loading: false,
      error: null,
      isEmpty: _machines.isEmpty,
      onRetry: _load,
      emptyText: '还没有已安装的机器，装机完成后会显示在这里',
      emptyIcon: Icons.point_of_sale_outlined,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          for (final machine in _machines) ...[
            _machineCard(machine),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  /// 申请单：审核通过后可直接装机（`POST /pos/applies/{id}/install`）
  Widget _applyCard(MachineApply a) {
    final (statusColor, statusText) = switch (a.status) {
      1 => (const Color(0xFF3F8600), '已通过'),
      2 => (const Color(0xFFE53935), '已拒绝'),
      _ => (const Color(0xFFB25E00), '待处理'),
    };
    final meta = [a.brandName, a.typeName]
        .where((v) => v != null && v.isNotEmpty)
        .join(' · ');
    // 申请还没分到机号时，以联系人作为标题
    final title = a.machineNo.isNotEmpty
        ? a.machineNo
        : (a.contactName?.isNotEmpty ?? false ? a.contactName! : '装机申请');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.qr_code_2, size: 18, color: kqwPrimary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    a.statusName.isEmpty ? statusText : a.statusName,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (a.contactName != null && a.contactName!.isNotEmpty)
              _infoItem(Icons.person_outline, '联系人', a.contactName!),
            _infoItem(
                Icons.phone_iphone,
                '联系电话',
                a.customerPhone.isEmpty
                    ? '—'
                    : revealOwnPhone(a.customerPhone, _selfPhone())),
            if (a.merchantName != null && a.merchantName!.isNotEmpty)
              _infoItem(Icons.storefront_outlined, '商户名称', a.merchantName!),
            _infoItem(Icons.people_outline, '使用人', a.useTypeName),
            _infoItem(Icons.dvr, '品牌/类型', meta.isEmpty ? '—' : meta),
            _infoItem(Icons.schedule, '提交时间', formatShortTime(a.submittedAt)),
            if (a.approved) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                  onPressed: () => _openInstall(a),
                  icon: const Icon(Icons.build_circle_outlined, size: 20),
                  label: const Text('立即装机'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 装机弹窗：选安装方式，申请记录缺的信息可在这里补录
  Future<void> _openInstall(MachineApply a) async {
    final installed = await showDialog<bool>(
      context: context,
      builder: (_) => _InstallDialog(apply: a),
    );
    if (installed == true && mounted) {
      showToast(context, '装机成功，已转入「已安装」列表');
      await _load();
    }
  }

  Widget _machineCard(Machine m) {
    final rejected = m.newbieRejectReason != null;
    final (statusColor, statusText) = m.newbieStatus == 1 && rejected
        ? (const Color(0xFFE53935), '已驳回')
        : switch (m.newbieStatus) {
            3 => (const Color(0xFF3F8600), '新手任务已完成'),
            2 => (const Color(0xFFE53935), '审核中'),
            _ => (
                const Color(0xFFB25E00),
                m.newbieStatusName.isEmpty ? '新手任务进行中' : m.newbieStatusName
              ),
          };
    final progress = m.progress;
    final busy = _busySn == m.sn;
    // 与后端 submitNewbie 同口径：只拦已过有效期，流水是否达标交给后台审核
    final canSubmit = !progress.expired;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.point_of_sale, size: 18, color: kqwPrimary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(m.sn,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoItem(Icons.schedule, '开机时间', formatShortTime(m.bootedAt)),
            _infoItem(Icons.dvr, '机器型号', m.model.isEmpty ? '—' : m.model),
            _infoItem(
              Icons.person_outline,
              '推荐人',
              m.referredBy == null
                  ? '—（自装机）'
                  : '${m.referredBy!.phone}（${m.referredBy!.levelLabel}）',
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        switch (m.newbieStatus) {
                          3 => Icons.task_alt,
                          2 => Icons.hourglass_bottom,
                          _ => Icons.pending_actions,
                        },
                        size: 16,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '已刷 ¥${progress.amount} / ${progress.target}'
                          '${progress.daysLeft > 0 ? ' · 剩 ${progress.daysLeft} 天' : ''}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.ratio,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(statusColor),
                    ),
                  ),
                ],
              ),
            ),
            // 驳回原因（状态 1 且有原因 = 审核被打回，可重新提交）
            if (m.newbieRejectReason != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline,
                      size: 14, color: Color(0xFFE53935)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '驳回原因：${m.newbieRejectReason}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFE53935)),
                    ),
                  ),
                ],
              ),
            ],
            // 仅「进行中」可提交；未达标/超期按钮置灰，提前拦住 41003/41017
            if (m.newbieStatus == 1) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kqwPrimary,
                    side: const BorderSide(color: kqwPrimary),
                    minimumSize: const Size(0, 38),
                  ),
                  onPressed:
                      (busy || !canSubmit) ? null : () => _submitNewbie(m),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    busy
                        ? '提交中…'
                        : canSubmit
                            ? '提交达标'
                            : '任务已过期',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 本机登录号码：申请单电话由后端统一脱敏，匹配上就补全成本人完整号码
  String? _selfPhone() => context.read<AuthProvider?>()?.user?.phone;

  Widget _infoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Colors.black45),
          const SizedBox(width: 6),
          SizedBox(
              width: 64,
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 13, color: Colors.black54))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13, color: Colors.black87))),
        ],
      ),
    );
  }
}

/// 装机弹窗：安装方式 + 申请记录缺的信息补录
///
/// 只提交用户填了值的字段，留空由后端沿用申请记录，
/// 避免把申请里已有的值覆盖成空。
class _InstallDialog extends StatefulWidget {
  const _InstallDialog({required this.apply});

  final MachineApply apply;

  @override
  State<_InstallDialog> createState() => _InstallDialogState();
}

class _InstallDialogState extends State<_InstallDialog> {
  /// 弹窗里的 TextFormField 校验器只在 Form.validate() 时才执行，
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
    return AlertDialog(
      title: const Text('安装 POS 机'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
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
              // 姓名与身份证后 6 位与装机页同源（共享字段与共享校验器），弹窗不再单列「联系人」
              contactNameController: _contact,
              contactNameValidator: validateInstallContactName,
              idTailController: _idTail,
              idTailValidator: validateInstallIdTail,
              // 弹窗按 applyId 装机，比装机页多出「补录」三项
              extraFields: [
                installField('门店名称', child: _text(_merchant, '申请记录已填可留空')),
                installField('所在地区', child: _text(_region, '申请记录已填可留空')),
                installField('详细地址', child: _text(_address, '申请记录已填可留空')),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '提交中…' : '确认装机'),
        ),
      ],
    );
  }

  Widget _text(TextEditingController controller, String hint) => TextField(
        controller: controller,
        decoration: installInputDecoration(hint),
      );
}
