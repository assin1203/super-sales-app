import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/api/user_api.dart';
import '../core/api_client.dart';
import '../core/models/invite.dart';
import '../core/theme.dart';
import '../core/toast.dart';
import '../core/widgets/async_view.dart';

/// 推广中心（FR-12.x：我的推广码 / 推广二维码 / 3 级人数分布 / 推荐奖励 / 下级明细）
///
/// 数据源 `GET /user/invite`（码 + 统计）与 `GET /user/invite/records`（分页明细）。
/// 二维码内容即推广链接，长按保存为 PNG 到系统相册（RepaintBoundary 截图 + gal）。
class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  InviteSummary _summary = InviteSummary.empty;
  List<InviteRecord> _records = const [];
  bool _loading = true;
  String? _error;

  /// 二维码卡片截图区域（长按保存时按它取像素）
  final GlobalKey _qrKey = GlobalKey();
  bool _saving = false;

  /// 头像占位字：昵称为空或全空白时 `characters.first` 会抛 StateError，
  /// 一条脏数据就会让整页报错，这里兜成 '?'。
  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        userApi.invite(),
        userApi.inviteRecords(pageSize: 50),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as InviteSummary;
        _records = (results[1] as dynamic).items as List<InviteRecord>;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _summary = InviteSummary.empty;
        _records = const [];
        _error = e.displayMessage;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _copy(String text, String label) async {
    if (text.isEmpty) {
      showToast(context, '$label 还没生成，稍后下拉刷新');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showToast(context, '$label 已复制');
  }

  /// 长按二维码：把卡片截成 PNG 存进系统相册
  ///
  /// 用 RepaintBoundary 抓像素而不是自己拼图，保证保存出来的图和屏幕上一致
  /// （含邀请码文字）；pixelRatio 3 让二维码放大后仍然清晰可扫。
  Future<void> _saveQr() async {
    if (_saving || _summary.inviteUrl.isEmpty) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    ui.Image? image;
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('二维码还没渲染完成');
      image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('图片编码失败');
      final bytes = data.buffer.asUint8List();

      if (!await Gal.hasAccess()) {
        final granted = await Gal.requestAccess();
        if (!granted) throw StateError('没有相册权限，请在系统设置里开启');
      }
      await Gal.putImageBytes(bytes, name: 'invite_${_summary.inviteCode}');
      if (mounted) showToast(context, '二维码已保存到相册');
    } on GalException catch (e) {
      if (mounted) showToast(context, '保存失败：${e.type.message}');
    } catch (e) {
      if (mounted) showToast(context, '保存失败：$e');
    } finally {
      image?.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('推广中心')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 推广码来自登录态，加载/失败时都应可见
            _codeCard(),
            const SizedBox(height: 12),
            _qrCard(),
            const SizedBox(height: 12),
            ..._sections(),
          ],
        ),
      ),
    );
  }

  /// 统计与明细：加载中给紧凑转圈，失败给原因 + 重试，成功才渲染卡片
  List<Widget> _sections() {
    if (_loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ];
    }
    if (_error != null) {
      return [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(Icons.cloud_off_outlined,
                    size: 36, color: Colors.black26),
                const SizedBox(height: 8),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 13, color: Colors.black54)),
                TextButton(onPressed: _load, child: const Text('重试')),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      _statsCard(),
      const SizedBox(height: 12),
      _levelCard(),
      const SizedBox(height: 12),
      _recordsCard(),
    ];
  }

  Widget _codeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: kqwHeaderGradient,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('我的推广码',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  _summary.inviteCode.isEmpty ? '生成中…' : _summary.inviteCode,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: '复制推广码',
                onPressed: () => _copy(_summary.inviteCode, '推广码'),
                icon: const Icon(Icons.copy, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('下级注册时填写推广码即可绑定推荐关系（最多 3 级）',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  /// 推广二维码卡片：二维码在「复制推广链接」上方，说明文字在下方
  Widget _qrCard() {
    final ready = _summary.inviteUrl.isNotEmpty;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          children: [
            const Text('推广二维码',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              ready ? '长按二维码保存到相册' : '二维码生成中…',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onLongPress: ready && !_saving ? _saveQr : null,
              child: RepaintBoundary(key: _qrKey, child: _qrImage(ready)),
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _copy(_summary.inviteUrl, '推广链接'),
                icon: const Icon(Icons.link, size: 18),
                label: const Text('复制推广链接'),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '扫码或复制链接分享给好友，好友注册后自动绑定推荐关系，最多 3 级；'
              '每级达标后推荐奖励积分自动到账，可在下方明细查看。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.black45, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  /// 二维码本体（截图保存的就是这块：白底 + 码 + 邀请码文字）
  Widget _qrImage(bool ready) {
    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ready)
            QrImageView(
              data: _summary.inviteUrl,
              size: 180,
              gapless: true,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              backgroundColor: Colors.white,
            )
          else
            const SizedBox(
              width: 180,
              height: 180,
              child: Center(
                child: Text('——', style: TextStyle(color: Colors.black26)),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            _summary.inviteCode.isEmpty ? '——' : _summary.inviteCode,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          const Text('超级展业 · 邀请注册',
              style: TextStyle(fontSize: 10, color: Colors.black38)),
        ],
      ),
    );
  }

  Widget _statsCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _stat('${_summary.invitedCount}', '直推人数'),
            _stat('${_summary.qualifiedCount}', '已达标'),
            _stat(_summary.totalReward, '累计奖励'),
            _stat(_summary.monthReward, '本月奖励'),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black45)),
      ],
    );
  }

  Widget _levelCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('三级人数分布',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [1, 2, 3]
                  .map((level) => Column(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                kqwPrimary.withValues(alpha: 0.1),
                            child: Text('${_summary.levelCount(level)}',
                                style: const TextStyle(
                                    color: kqwPrimary,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 6),
                          Text('$level 级',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ],
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recordsCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('下级明细', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_records.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('还没有下级，快去分享推广码吧',
                    style: TextStyle(color: Colors.black45)),
              )
            else
              ..._records.map(
                (r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.grey.shade200,
                        child: Text(
                          _initial(r.displayName),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.displayName,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            Text(
                              '${r.levelLabel} · ${formatDate(r.registeredAt)} 注册',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.black45),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            r.qualified ? '已达标' : '未达标',
                            style: TextStyle(
                              fontSize: 12,
                              color: r.qualified
                                  ? const Color(0xFF3F8600)
                                  : Colors.black45,
                            ),
                          ),
                          if (r.rewardPoints != '0')
                            Text('+${r.rewardPoints}',
                                style: pointsTextStyle(size: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
