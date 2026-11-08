import 'package:flutter/material.dart';

import '../core/theme.dart';

/// 装机凭证截图的上传说明。
///
/// 装机页「装机凭证截图」旁的「查看」入口，按官方截图顺序讲清楚该传哪几页：
/// 1. 「我的」页点「我是商户」；2. 「商户服务」点「一键通查」输入密码后截图；
/// 3. 结果页点「展开更多」展开全部商户后再截图。三张图来自产品提供的操作指引。
class InstallGuidePage extends StatelessWidget {
  const InstallGuidePage({super.key});

  /// 步骤文案：图与说明一一对应（1→2→3 顺序不可打乱）
  static const List<({String title, String desc, String asset})> _steps = [
    (
      title: '① 在「我的」页点「我是商户」',
      desc: '打开手机上的收银工具，从「我的」页进入「商户服务」，确认当前登录的是要装这台机器的商户账号。',
      asset: 'assets/guide/install_step1.jpg',
    ),
    (
      title: '② 点「一键通查」，输入密码后截图',
      desc: '在「商户服务」页点「一键通查」，输入查询密码，把查出来的「商户查询概况」这一屏完整截图。',
      asset: 'assets/guide/install_step2.jpg',
    ),
    (
      title: '③ 点「展开更多」，展开全部商户再截图',
      desc: '结果页点「展开更多」把商户明细全部展开后再截图，确保每一家商户都截到，不要裁掉列表。',
      asset: 'assets/guide/install_step3.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('装机凭证上传说明'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '返回',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _introCard(),
            const SizedBox(height: 12),
            for (var i = 0; i < _steps.length; i++) ...[
              _stepCard(context, index: i),
              if (i != _steps.length - 1) const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
            _tipsCard(),
          ],
        ),
      ),
    );
  }

  Widget _introCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EBF1)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 18, color: kqwPrimary),
              SizedBox(width: 6),
              Text('为什么需要上传截图',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),          SizedBox(height: 8),
          Text(
            '装机凭证用于核对这台机器背后真实的商户归属：按下面三步截图，'
            '能一次看清商户名称、商户编码和收单机构，后台审核时不用再来回找你确认。',
            style: TextStyle(
                fontSize: 13, height: 1.6, color: Color(0xFF4A5160)),
          ),
        ],
      ),
    );
  }

  Widget _stepCard(BuildContext context, {required int index}) {
    final step = _steps[index];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EBF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step.title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            step.desc,
            style: const TextStyle(
                fontSize: 13, height: 1.6, color: Color(0xFF4A5160)),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _previewImage(context, index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                step.asset,
                width: double.infinity,
                fit: BoxFit.fitWidth,
                errorBuilder: (_, __, ___) => Container(
                  height: 160,
                  alignment: Alignment.center,
                  color: const Color(0xFFF2F4F8),
                  child: const Text('示例图加载失败',
                      style: TextStyle(fontSize: 13, color: Color(0xFF8A93A6))),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text('点击看大图，左右滑动可切换三张示例',
              style: TextStyle(fontSize: 11, color: Color(0xFF9AA3B2))),
        ],
      ),
    );
  }

  Widget _tipsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE4B0)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('上传注意事项',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text(
            '· 选填，最多 4 张，单张不超过 5MB\n'
            '· 优先传「商户查询概况」整屏，商户多时连「展开更多」后的明细一起传\n'
            '· 图片会随本次装机一起提交，后台可在装机记录里查看',
            style: TextStyle(
                fontSize: 13, height: 1.7, color: Color(0xFF6B5A2E)),
          ),
        ],
      ),
    );
  }

  /// 全屏预览：从点击的那张起，左右滑动切换三张示例，右上角关闭或返回键退出
  void _previewImage(BuildContext context, int index) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _GuideImagePreview(
          initialIndex: index,
          assets: [for (final step in _steps) step.asset],
        ),
      ),
    );
  }
}

/// 示例图全屏预览：PageView 左右滑动切换 + 页码，避免单张图「看得到、切不动、关不掉」
class _GuideImagePreview extends StatefulWidget {
  const _GuideImagePreview({required this.initialIndex, required this.assets});

  final int initialIndex;
  final List<String> assets;

  @override
  State<_GuideImagePreview> createState() => _GuideImagePreviewState();
}

class _GuideImagePreviewState extends State<_GuideImagePreview> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '关闭',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('${_index + 1}/${widget.assets.length}',
            style: const TextStyle(fontSize: 15, color: Colors.white)),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.assets.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => GestureDetector(
          // 单击图片也关掉预览，符合相册习惯
          onTap: () => Navigator.of(context).maybePop(),
          child: Center(
            child: Image.asset(
              widget.assets[i],
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text(
                '示例图加载失败',
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
