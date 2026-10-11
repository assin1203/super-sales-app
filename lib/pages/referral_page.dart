import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme.dart';

/// 我的推荐（FR-1.2：推荐码二维码展示 + 分享微信）
class ReferralPage extends StatelessWidget {
  const ReferralPage({super.key});

  static const _code = 'KQW888';
  static const _inviteUrl = 'https://kqw.example.com/r/KQW888';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('邀请好友')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // 推荐码卡
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text('我的推荐码', style: TextStyle(fontSize: 13, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Text(_code, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 3, color: kqwPrimary)),
                  const SizedBox(height: 20),
                  // 二维码（中间叠红色 logo）
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        QrImageView(
                          data: _inviteUrl,
                          version: QrVersions.auto,
                          size: 200,
                          gapless: false,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFFCC0000),
                          ),
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                        ),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCC0000),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(Icons.storefront, color: Colors.white, size: 30),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('好友扫码注册并填写推荐码，注册成功后建立推荐关系', style: TextStyle(fontSize: 12, color: Colors.black45)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 奖励说明
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.card_giftcard, size: 20, color: kqwPrimary),
                      SizedBox(width: 8),
                      Text('推荐奖励', style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('· 好友成功注册：+50 积分', style: TextStyle(color: Colors.black87, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('· 好友首台机器达标：+150 积分', style: TextStyle(color: Colors.black87, fontSize: 13)),
                  const SizedBox(height: 4),
                  const Text('· 累计直推达标 2 人：升级 L2 会员', style: TextStyle(color: Colors.black87, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // 分享微信
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF07C160),
                foregroundColor: Colors.white,
              ),
              onPressed: () => _shareWechat(context),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('分享到微信'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: kqwPrimary, side: const BorderSide(color: kqwPrimary)),
            onPressed: () => _copyCode(context),
            icon: const Icon(Icons.copy_outlined),
            label: const Text('复制推荐码'),
          ),
        ],
      ),
      ),
    );
  }

  void _shareWechat(BuildContext context) {
    // TODO: 接入 share_plus / 微信 SDK 分享（当前 mock）
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('「超级展业 · 推荐码 $_code」已发送到微信（mock）')),
    );
  }

  void _copyCode(BuildContext context) {
    // TODO: 接入 Clipboard（当前 mock）
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('推荐码 $_code 已复制（mock）')));
  }
}
