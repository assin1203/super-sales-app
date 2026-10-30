import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/auth_provider.dart';
import '../core/models/user_info.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import 'avatar_crop_page.dart';

/// 修改个人资料：初值来自 `GET /user/me`，保存走 `PUT /user/profile`（补丁式）。
///
/// - 头像：相册 / 拍照 → 圆形裁切 → `POST /common/upload/image` 拿 URL 再提交
/// - 昵称（1~20 字）、性别（0 未设置 / 1 男 / 2 女）、生日（YYYY-MM-DD）
/// - 只提交真正改动过的字段，未改动不传，避免覆盖服务端其它数据
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _picker = ImagePicker();
  final _nameController = TextEditingController();

  /// 新裁切结果（仅本地预览；保存成功后由服务端 URL 接管）
  Uint8List? _avatarBytes;
  bool _avatarChanged = false;

  int _gender = 0;
  DateTime? _birthday;

  /// 进入页面时的服务端快照，用于判断哪些字段真的改了
  String _initialNickname = '';
  int _initialGender = 0;
  DateTime? _initialBirthday;

  /// 用户是否已动过表单：动过就不再被后台刷新覆盖
  bool _dirty = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 先用本地快照渲染，再拉 /user/me 校准
    _applyUser(Provider.of<AuthProvider>(context, listen: false).user);
    _refreshFromServer();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 用服务端资料填充表单初值
  void _applyUser(UserInfo? user) {
    final nickname = (user?.nickname ?? '').trim();
    _initialNickname = nickname;
    _nameController.text = nickname;
    _initialGender = user?.gender ?? 0;
    _gender = _initialGender;
    _initialBirthday = _parseDate(user?.birthday);
    _birthday = _initialBirthday;
  }

  /// 拉一次 `GET /user/me`（失败时 [AuthProvider.loadProfile] 内部吞掉，保留本地快照）
  Future<void> _refreshFromServer() async {
    final auth = context.read<AuthProvider>();
    await auth.loadProfile();
    if (!mounted) return;
    setState(() {
      if (!_dirty) _applyUser(auth.user);
      _loading = false;
    });
  }

  /// 选图（相册 / 相机）→ 圆形裁切页 → 本地预览
  Future<void> _pickAvatar({ImageSource source = ImageSource.gallery}) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      debugPrint('[avatar] picked=${picked.path} bytes=${bytes.length}');
      if (bytes.isEmpty) {
        showToast(context, '该照片无法读取（可能是未下载到本机的云照片），请换一张');
        return;
      }
      final cropped = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => AvatarCropPage(imageBytes: bytes)),
      );
      if (cropped == null || !mounted) return;
      setState(() {
        _avatarBytes = cropped;
        _avatarChanged = true;
        _dirty = true;
      });
    } catch (e) {
      debugPrint('[avatar] pick error: $e');
      if (mounted) showToast(context, '选取图片失败，请重试');
    }
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final initial = _birthday ?? DateTime(now.year - 20, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: '选择生日',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birthday = picked;
      _dirty = true;
    });
  }

  /// 保存：头像有变更时先上传拿 URL，再调 `PUT /user/profile` 落库（只传改动字段）
  Future<void> _save() async {
    if (_saving) return;
    final auth = context.read<AuthProvider>();

    final nickname = _nameController.text.trim();
    if (nickname.isEmpty) {
      showToast(context, '昵称不能为空');
      return;
    }
    if (nickname.length > 20) {
      showToast(context, '昵称最多 20 个字');
      return;
    }

    final nicknameChanged = nickname != _initialNickname;
    final genderChanged = _gender != _initialGender;
    final birthdayChanged = !_sameDate(_birthday, _initialBirthday);
    if (!_avatarChanged && !nicknameChanged && !genderChanged && !birthdayChanged) {
      Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);
    try {
      String? avatarUrl;
      final bytes = _avatarBytes;
      if (_avatarChanged && bytes != null) {
        final res = await api.uploadImage(bytes, filename: 'avatar.png');
        avatarUrl = res['url'] as String?;
        if (avatarUrl == null || avatarUrl.isEmpty) {
          throw ApiException(-1, '头像上传失败，请重试');
        }
      }
      await auth.saveProfile(
        nickname: nicknameChanged ? nickname : null,
        avatar: avatarUrl,
        gender: genderChanged ? _gender : null,
        birthday: birthdayChanged ? _formatDate(_birthday) : null,
      );
      if (!mounted) return;
      showToast(context, '资料已更新');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      showToast(context, e.displayMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('修改个人资料'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(64, 36),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 8),
          _avatarSection(auth),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                maxLength: 20,
                inputFormatters: [LengthLimitingTextInputFormatter(20)],
                onChanged: (_) => _dirty = true,
                decoration: const InputDecoration(
                  labelText: '昵称',
                  hintText: '请输入昵称',
                  counterText: '',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '性别',
                    style: TextStyle(fontSize: 12, color: kqwTextSecondary),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 0, label: Text('未设置')),
                        ButtonSegment(value: 1, label: Text('男')),
                        ButtonSegment(value: 2, label: Text('女')),
                      ],
                      selected: {_gender},
                      onSelectionChanged: (selected) => setState(() {
                        _gender = selected.first;
                        _dirty = true;
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cake_outlined, color: kqwPrimary),
              title: const Text('生日'),
              subtitle: Text(
                _birthday == null ? '未设置' : _formatDate(_birthday),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: _pickBirthday,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_outlined, color: kqwPrimary),
              title: const Text('手机号'),
              subtitle: Text(
                '${auth.maskedPhone ?? '-'} · 已绑定（更换请联系客服）',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarSection(AuthProvider auth) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            GestureDetector(
              onTap: _pickAvatar,
              child: CircleAvatar(
                radius: 64,
                backgroundColor: kqwPrimary.withValues(alpha: 0.08),
                child: ClipOval(child: _avatarImage(auth)),
              ),
            ),
            GestureDetector(
              onTap: () => _pickAvatar(source: ImageSource.camera),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4, right: 4),
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFE53935), Color(0xFFFF6B4A)]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_camera, size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          '点击头像从相册选取，点小相机可直接拍照',
          style: TextStyle(fontSize: 12, color: kqwTextSecondary),
        ),
      ],
    );
  }

  /// 头像：本次裁切的本地预览 → 服务端返回的头像 URL → 默认图
  Widget _avatarImage(AuthProvider auth) {
    final bytes = _avatarBytes;
    if (bytes != null) {
      return Image.memory(bytes, width: 128, height: 128, fit: BoxFit.cover);
    }
    final url = auth.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: 128,
        height: 128,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultAvatar(),
      );
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() =>
      Image.asset('assets/avatar.jpeg', width: 104, height: 104);

  /// 服务端 `birthday` 是 YYYY-MM-DD 字符串
  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = DateTime.tryParse(value);
    return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String _formatDate(DateTime? date) {
    if (date == null) return '';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static bool _sameDate(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == null && b == null;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
