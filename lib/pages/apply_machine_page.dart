import 'package:dio/dio.dart' show DioMediaType;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api/pos_api.dart';
import '../core/api_client.dart';
import '../core/auth_provider.dart';
import '../core/models/machine.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import '../core/widgets/region_picker.dart';
import 'install_guide_page.dart';

/// 申请 POS 机（首页入口 `/machine/apply`）。
///
/// 走 `POST /pos/apply`：提交装机申请，审核通过后由运营装机，
/// 申请记录会出现在「我的机器」的"申请中的机器"里。
/// 一条申请 = 一台机器，同一手机号可连续提交多次申请多台。
class ApplyMachinePage extends StatefulWidget {
  const ApplyMachinePage({super.key, this.api});

  /// 测试可注入的接口实现，缺省用全局 [posApi]
  final PosApi? api;

  @override
  State<ApplyMachinePage> createState() => _ApplyMachinePageState();
}

class _ApplyMachinePageState extends State<ApplyMachinePage> {
  late final PosApi _api = widget.api ?? posApi;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  /// 所在地区：省市区拼串，由 [RegionPickerField] 选择后写入
  String _region = '';
  final _addressCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  bool _submitting = false;

  /// 装机凭证截图（选填，最多 [kMaxProofImages] 张，提交时先传到 COS 再申请）
  final ImagePicker _picker = ImagePicker();
  final List<_ProofShot> _proofs = [];

  /// 使用人标记：1 自己用（默认）/ 2 他人用
  int _useType = 1;

  /// 「自己用」时是否已用本人信息预填过，避免覆盖用户手填内容
  bool _selfPrefilled = false;

  /// 自动带出的本人姓名 / 手机号，切到「他人用」时按它判断能否清空
  String? _selfName;
  String? _selfPhone;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selfPrefilled) return;
    _selfPrefilled = true;
    if (_useType == 1) _fillSelfInfo();
  }

  /// 自己用：把本人昵称/手机号带进联系人，只填空字段，不覆盖手填内容
  void _fillSelfInfo() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final nickname = user.nickname?.trim() ?? '';
    if (nickname.isNotEmpty && _nameCtrl.text.trim().isEmpty) {
      _nameCtrl.text = nickname;
      _selfName = nickname;
    }
    if (user.phone.isNotEmpty && _phoneCtrl.text.trim().isEmpty) {
      _phoneCtrl.text = user.phone;
      _selfPhone = user.phone;
    }
  }

  /// 切到他人用：只清掉自动带出的本人信息，用户手填的内容不动
  void _clearSelfInfo() {
    if (_selfName != null && _nameCtrl.text.trim() == _selfName) {
      _nameCtrl.clear();
      _selfName = null;
    }
    if (_selfPhone != null && _phoneCtrl.text.trim() == _selfPhone) {
      _phoneCtrl.clear();
      _selfPhone = null;
    }
  }

  void _selectUseType(int value) {
    if (_useType == value) return;
    setState(() => _useType = value);
    if (value == 1) {
      _fillSelfInfo();
    } else {
      _clearSelfInfo();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return '请输入联系人姓名';
    if (name.length < 2) return '姓名至少 2 个字';
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) return '请输入手机号';
    if (!RegExp(r'^1\d{10}$').hasMatch(phone)) return '手机号格式不正确';
    return null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      // 先逐张上传换 URL：任一张失败即中止，避免「申请提交了但凭证丢了」
      final proofUrls = await _uploadProofs();
      final MachineApplyResult result = await _api.apply(
        contactName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        useType: _useType,
        region: _region,
        address: _addressCtrl.text.trim(),
        remark: _remarkCtrl.text.trim(),
        proofImages: proofUrls,
      );
      if (!mounted) return;
      final status = result.statusName.isEmpty ? '已提交' : result.statusName;
      showToast(context, '申请$status，可在「我的机器」查看进度；装多台可再次提交');
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
        title: const Text('申请 POS 机'),
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
              _introCard(),
              const SizedBox(height: 20),
              _useTypeSelector(),
              const SizedBox(height: 16),
              _labeled(
                '联系人',
                required: true,
                child: TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(20)],
                  validator: _validateName,
                  decoration: _inputDecoration(
                      _useType == 1 ? '请确认本人姓名' : '请输入使用人姓名'),
                ),
              ),
              _labeled(
                '手机号',
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
                  decoration: _inputDecoration(_useType == 1
                      ? '本人常用号码，用于装机联系'
                      : '使用人常用号码，用于装机联系'),
                ),
              ),
              _labeled(
                '所在地区',
                child: RegionPickerField(
                  value: _region,
                  onChanged: (value) => setState(() => _region = value),
                ),
              ),
              _labeled(
                '详细地址',
                child: TextFormField(
                  controller: _addressCtrl,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  decoration: _inputDecoration('门牌号 / 档口位置（选填）'),
                ),
              ),
              _labeled('装机凭证截图', child: _proofField()),
              _labeled(
                '备注',
                child: TextFormField(
                  controller: _remarkCtrl,
                  maxLines: 3,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  decoration: _inputDecoration('其他说明，如期望装机时间'),
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
                      : const Text('提交申请',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '一条申请对应一台机器，需要多台请重复提交；提交后由工作人员电话联系并安排装机，'
                '装机完成前可在「我的机器」查看申请进度。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black38),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部说明：把"免费/流程/到哪看进度"一次讲清楚，减少提交前的疑问
  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3F0), Color(0xFFFFFBF9)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFE0D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [kqwPrimary, kqwAccent]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.point_of_sale_rounded,
                    color: Colors.white, size: 19),
              ),
              const SizedBox(width: 10),
              const Text('免费申请，装机后领积分',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          for (final step in const ['① 填写门店信息提交申请', '② 工作人员联系确认并装机', '③ 装机完成到「我的机器」看进度'])
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(step,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.black54)),
            ),
        ],
      ),
    );
  }

  // ---------- 使用人标记 ----------

  /// 自己用 / 他人用：决定这台机器的使用人，提交时随 `useType` 传给后端。
  Widget _useTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('*',
                style: TextStyle(fontSize: 13, color: Color(0xFFE53935))),
            SizedBox(width: 2),
            Text('使用人',
                style: TextStyle(fontSize: 13, color: Color(0xFF4A5160))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _useTypeOption(
                1,
                Icons.person_outline,
                '自己使用',
                '本人是商户，自己装机',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _useTypeOption(
                2,
                Icons.people_outline,
                '他人使用',
                '帮别人申请装机',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _useTypeOption(
      int value, IconData icon, String title, String desc) {
    final selected = _useType == value;
    return InkWell(
      onTap: () => _selectUseType(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFF3F0) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? kqwPrimary : const Color(0xFFDDE2EA),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: selected ? kqwPrimary : const Color(0xFF8A93A6)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color:
                            selected ? kqwPrimary : const Color(0xFF1F2430),
                      )),
                  const SizedBox(height: 2),
                  Text(desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, size: 16, color: kqwPrimary),
          ],
        ),
      ),
    );
  }

  // ---------- 装机凭证截图（选填，最多 kMaxProofImages 张） ----------

  /// 上传说明：三张官方截图按顺序讲清楚该传哪些页面
  Future<void> _openGuide() async {
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const InstallGuidePage()),
    );
  }

  /// 添加凭证：先选来源（相册可多选 / 拍照单张），再统一入列
  Future<void> _pickProofs() async {
    FocusScope.of(context).unfocus();
    final remain = kMaxProofImages - _proofs.length;
    if (remain <= 0) {
      showToast(context, '最多上传 $kMaxProofImages 张凭证截图');
      return;
    }
    final source = await showModalBottomSheet<_ProofSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('添加装机凭证',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, size: 20),
              title: const Text('从相册选择'),
              subtitle: const Text('可一次选多张'),
              onTap: () => Navigator.of(ctx).pop(_ProofSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, size: 20),
              title: const Text('拍照上传'),
              subtitle: const Text('现拍现传，一次一张'),
              onTap: () => Navigator.of(ctx).pop(_ProofSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    if (source == _ProofSource.camera) {
      await _pickFromCamera();
    } else {
      await _pickFromGallery(remain);
    }
  }

  /// 相册：可多选，超出上限只保留前几张
  Future<void> _pickFromGallery(int remain) async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;
      final shots = <_ProofShot>[];
      for (final file in picked.take(remain)) {
        final shot = await _toShot(file);
        if (shot != null) shots.add(shot);
      }
      if (!mounted || shots.isEmpty) return;
      setState(() => _proofs.addAll(shots));
      if (picked.length > remain) {
        showToast(context, '最多上传 $kMaxProofImages 张，已保留前 $remain 张');
      }
    } catch (_) {
      if (mounted) showToast(context, '图片选择失败，请重试');
    }
  }

  /// 拍照：系统相机现拍一张，拍完直接入列
  Future<void> _pickFromCamera() async {
    try {
      final file =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (file == null) return;
      final shot = await _toShot(file);
      if (!mounted || shot == null) return;
      setState(() => _proofs.add(shot));
    } catch (_) {
      if (mounted) showToast(context, '拍照失败，请检查相机权限后重试');
    }
  }

  /// 读入一张图并生成上传用的文件名（序号按当前已选张数递增）
  Future<_ProofShot?> _toShot(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    return _ProofShot(
      bytes: bytes,
      filename: _proofName(file.name, _proofs.length + 1),
    );
  }

  /// COS 对象名用序号 + 原扩展名（服务端按文件头嗅探真实类型，与这里无关）
  String _proofName(String origin, int index) {
    final lower = origin.toLowerCase();
    final isKnown = lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg');
    final ext = isKnown ? lower.substring(lower.lastIndexOf('.')) : '.jpg';
    return 'pos_apply_proof_$index$ext';
  }

  /// 逐张上传到 `/common/upload/image`，返回可直接落库的 URL 列表
  Future<List<String>> _uploadProofs() async {
    final urls = <String>[];
    for (var i = 0; i < _proofs.length; i++) {
      final shot = _proofs[i];
      final res = await api.uploadImage(
        shot.bytes,
        filename: shot.filename,
        contentType: shot.contentType,
      );
      final url = (res['url'] as String?)?.trim() ?? '';
      if (url.isEmpty) {
        throw ApiException(-1, '第 ${i + 1} 张凭证截图上传失败，请重试');
      }
      urls.add(url);
    }
    return urls;
  }

  Widget _proofField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _openGuide,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F7FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD8E6FF)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: kqwPrimary),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    // 张数与 kMaxProofImages 同步维护
                    '选填，最多 4 张。不清楚传哪张？看截图示例',
                    style: TextStyle(fontSize: 12, color: Color(0xFF4A5160)),
                  ),
                ),
                Text('查看 ›',
                    style: TextStyle(
                        fontSize: 12,
                        color: kqwPrimary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _proofs.length; i++) _proofThumb(i),
            if (_proofs.length < kMaxProofImages) _proofAddTile(),
          ],
        ),
      ],
    );
  }

  Widget _proofThumb(int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            _proofs[index].bytes,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: InkWell(
            onTap: () => setState(() => _proofs.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0x99000000),
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _proofAddTile() {
    return InkWell(
      onTap: _pickProofs,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFC),
          border: Border.all(color: const Color(0xFFDDE2EA)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined,
                size: 22, color: Color(0xFF8A93A6)),
            const SizedBox(height: 4),
            Text(
              '${_proofs.length}/$kMaxProofImages',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8A93A6)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 字段容器与样式 ----------

  /// 标签在上、输入框在下，与「新增机器」页保持同一套表单风格
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
}

/// 凭证截图张数上限：与后端 `MachineApplyDto.proofImages` 的 4 张保持一致
const int kMaxProofImages = 4;

/// 凭证截图来源：相册（可多选）/ 拍照（单张）
enum _ProofSource { gallery, camera }

/// 一张待上传的凭证截图（本地持有；提交申请前统一上传换 URL）
class _ProofShot {
  _ProofShot({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;

  /// 按扩展名声明 MIME：服务端仍按文件头嗅探，这里只影响白名单校验
  DioMediaType get contentType {
    if (filename.endsWith('.png')) return DioMediaType('image', 'png');
    if (filename.endsWith('.gif')) return DioMediaType('image', 'gif');
    if (filename.endsWith('.webp')) return DioMediaType('image', 'webp');
    return DioMediaType('image', 'jpeg');
  }
}
