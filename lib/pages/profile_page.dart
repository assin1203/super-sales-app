import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/auth_provider.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import 'avatar_crop_page.dart';

/// 修改个人资料：头像（相册选取 + 圆形裁切）+ 昵称
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  Uint8List? _avatarBytes;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _avatarBytes = auth.avatarBytes;
    _nameController.text = auth.name ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
      debugPrint('[avatar] picked=${picked.path} bytes=${bytes.length}');
      if (bytes.isEmpty) {
        showToast(context, '该照片无法读取（可能是未下载到本机的云照片），请换一张');
        return;
      }
      final cropped = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(builder: (_) => AvatarCropPage(imageBytes: bytes)),
      );
      if (cropped == null || !mounted) return;
      setState(() => _avatarBytes = cropped);
    } catch (e) {
      debugPrint('[avatar] pick error: $e');
      if (mounted) showToast(context, '选取图片失败，请重试');
    }
  }

  void _save() {
    context.read<AuthProvider>().updateProfile(
          name: _nameController.text,
          avatarBytes: _avatarBytes,
        );
    showToast(context, '资料已更新');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
              onPressed: _save,
              child: const Text('保存', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          _avatarSection(),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _nameController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '昵称',
                  hintText: '请输入昵称',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_outlined, color: kqwPrimary),
              title: const Text('手机号'),
              subtitle: const Text(
                '138****0001 · 已绑定（更换请联系客服）',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarSection() {
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
                child: _avatarBytes != null
                    ? ClipOval(
                        child: Image.memory(_avatarBytes!, width: 128, height: 128, fit: BoxFit.cover),
                      )
                    : Image.asset('assets/avatar.jpeg', width: 104, height: 104),
              ),
            ),
            GestureDetector(
              onTap: () => _pickAvatar(source: ImageSource.camera),
              child: Container(
                margin: const EdgeInsets.only(bottom: 4, right: 4),
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFF2B5BFF), Color(0xFF00A9E8)]),
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
}
