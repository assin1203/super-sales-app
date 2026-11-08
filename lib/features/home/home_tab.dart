import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/home_api.dart';
import '../../core/api/notice_api.dart';
import '../../core/api/points_api.dart';
import '../../core/api/pos_api.dart';
import '../../core/api/task_api.dart';
import '../../core/api/team_api.dart';
import '../../core/api_client.dart';
import '../../core/auth_provider.dart';
import '../../core/models/banner_item.dart';
import '../../core/models/machine.dart';
import '../../core/models/notice_item.dart';
import '../../core/models/points_summary.dart';
import '../../core/models/room_package.dart';
import '../../core/models/task_item.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../core/widgets/async_view.dart';
import '../team/enter_room_flow.dart';

/// 首页：广告轮播 / 入房档位（积分兑换）/ 等级进度 / 机器达标监控 / 任务中心 / 平台公告
///
/// 数据源（除 banner 公开外都需 app token）：
/// - `GET /home/banners`（空时用本地兜底图，不算错误）
/// - `GET /team/room-packages`（入房档位，只消耗积分）
/// - `GET /user/points`（入房前判断积分是否够）
/// - `GET /pos/machines`（取第一台展示达标进度）
/// - `GET /tasks?category=1`（新手任务完成度）
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<BannerItem> _banners = const [];
  List<NoticeItem> _notices = const [];
  List<RoomPackage> _roomPackages = const [];
  Machine? _machine;
  List<TaskItem> _newbieTasks = const [];
  PointsSummary? _points;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();

    List<BannerItem> banners = const [];
    List<NoticeItem> notices = const [];
    try {
      banners = await homeApi.banners();
    } on ApiException {
      // banner 是运营位，拉不到就用本地兜底图，不打断首屏
      banners = const [];
    }
    try {
      notices = (await noticeApi.list(pageSize: 5)).items;
    } on ApiException {
      // 公告是公开端点，失败按无数据处理，卡片给空态
      notices = const [];
    }
    if (!mounted) return;
    setState(() {
      _banners = banners;
      _notices = notices;
    });

    if (auth.loggedIn) {
      await Future.wait([
        _loadRoomPackages(),
        _loadPoints(),
        _loadMachine(),
        _loadTasks(),
      ]);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadRoomPackages() async {
    try {
      final items = await teamApi.roomPackages();
      if (mounted) setState(() => _roomPackages = items);
    } on ApiException {
      // 档位区留空即可，首页其他模块不受影响
    }
  }

  Future<void> _loadPoints() async {
    try {
      final summary = await pointsApi.summary();
      if (mounted) setState(() => _points = summary);
    } on ApiException {
      // 余额未知时入房提示里就不展示当前积分，不阻断点击
    }
  }

  Future<void> _loadMachine() async {
    try {
      final page = await posApi.machines(pageSize: 1);
      if (mounted) {
        setState(() => _machine = page.items.isEmpty ? null : page.items.first);
      }
    } on ApiException {
      if (mounted) setState(() => _machine = null);
    }
  }

  Future<void> _loadTasks() async {
    try {
      final items = await taskApi.list(category: 1);
      if (mounted) setState(() => _newbieTasks = items);
    } on ApiException {
      // 任务卡显示「暂无可做的新手任务」
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        // 首页没有 AppBar，列表从屏幕顶端开始，需自己让出状态栏高度，
        // 否则顶部「积分礼包」横幅会被系统状态栏压住。
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 24,
        ),
        children: [
          _banner(),
          _AdCarousel(banners: _banners),
          const SizedBox(height: 12),
          _applyEntryCard(),
          _noticeCard(),
          const SizedBox(height: 12),
          if (_roomPackages.isEmpty)
            const _EmptyHint(text: '暂无可入房档位')
          else
            for (final pkg in _roomPackages)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _giftCard(context, pkg),
              ),
          _levelCard(auth),
          const SizedBox(height: 12),
          _machineCard(context),
          const SizedBox(height: 12),
          _taskCard(context),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- 顶部横幅 ----------

  Widget _banner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: const BoxDecoration(
        gradient: kqwHeaderGradient,
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Stack(
        children: [
          Positioned(top: -50, right: -30, child: _circle(140)),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.card_giftcard_rounded,
                      color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Text('积分礼包',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              SizedBox(height: 8),
              Text('消耗积分入房，解锁团队分红收益',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circle(double size) => Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
          shape: BoxShape.circle, color: Color(0x14FFFFFF)));

  // ---------- 申请 POS 机入口 ----------

  /// 申请入口常驻首页、放在轮播下方：曝光稳定但不占首屏主视觉。
  /// 点击进 `/machine/apply` 提交，成功后去「我的机器」看申请进度。
  Widget _applyEntryCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openApply(),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFFFF3F0), Colors.white],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [kqwPrimary, kqwAccent]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.point_of_sale_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('申请 POS 机',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: kqwPrimary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('免费',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: kqwPrimary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '免费申请 · 快速开通 · 装机领积分',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: kqwPrimary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text('立即申请',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 申请完成后跳「我的机器」：申请中的机器只在那里可见，直接带用户看进度
  Future<void> _openApply() async {
    final submitted = await context.push<bool>('/machine/apply');
    if (!mounted || submitted != true) return;
    context.push('/machines');
  }

  // ---------- 入房档位卡（只消耗积分，无金额） ----------

  /// 档位图：取接口返回的 image（COS 绝对地址），无图或加载失败回落渐变礼盒图标
  Widget _packageImage(RoomPackage pkg) {
    final fallback = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFFE53935), Color(0xFFFF6B4A)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.card_giftcard, color: Colors.white, size: 26),
    );
    if (pkg.image.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        pkg.image,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : fallback,
      ),
    );
  }

  Widget _giftCard(BuildContext context, RoomPackage pkg) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _confirmEnter(context, pkg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _packageImage(pkg),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pkg.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('${pkg.entryPoints}',
                            style: pointsTextStyle(size: 17)),
                        const SizedBox(width: 4),
                        const Text('积分兑换',
                            style: TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (pkg.purchased)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle,
                          size: 14, color: Color(0xFF2E7D32)),
                      SizedBox(width: 4),
                      Text('已完成升级',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32))),
                    ],
                  ),
                )
              else
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: kqwPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _confirmEnter(context, pkg),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('购买升级礼包',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Icon(Icons.chevron_right, size: 16),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 进入房间：确认档位消耗后真调 `POST /team/rooms/enter`，
  /// 成功跳房间详情并刷新可用积分（首次入房会扣礼包积分）。
  Future<void> _confirmEnter(BuildContext context, RoomPackage pkg) async {
    final result = await enterRoomFlow(
      context,
      pkg: pkg,
      balance: _points?.balanceValue,
    );
    if (result == null || !mounted) return;
    // 扣过分要立刻同步余额，否则卡片上的积分看着没变
    _loadPoints();
  }

  // ---------- 等级进度（L1 → L2 双条件取较优） ----------

  Widget _levelCard(AuthProvider auth) {
    final level = auth.user?.level ?? 0;
    final levelName = auth.user?.levelLabel ?? 'L0';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kqwPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(levelName,
                      style: const TextStyle(
                          color: kqwPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                const Text('会员等级',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    level == 0 ? '完成新手任务升 L1' : '当前 $levelName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _newbieProgress(),
          ],
        ),
      ),
    );
  }

  /// 用新手任务完成度代替等级进度（等级升级条件由后端计算，前端不臆测）
  Widget _newbieProgress() {
    if (_newbieTasks.isEmpty) {
      return const Text('任务进度加载中…',
          style: TextStyle(color: Colors.black45, fontSize: 12));
    }
    final done = _newbieTasks.where((t) => t.claimed).length;
    final total = _newbieTasks.length;
    final ratio = total == 0 ? 0.0 : done / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          child: LinearProgressIndicator(value: ratio, minHeight: 8),
        ),
        const SizedBox(height: 8),
        Text('新手任务 $done/$total 已完成 · 完成后进入 L1 团队池',
            style: const TextStyle(color: Colors.black54, fontSize: 13)),
      ],
    );
  }

  // ---------- 机器达标监控（25 天 / 1000 元） ----------

  Widget _machineCard(BuildContext context) {
    final machine = _machine;
    if (machine == null) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/machines'),
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.point_of_sale, color: kqwPrimary),
                SizedBox(width: 8),
                Expanded(
                    child: Text('机器达标监控',
                        style: TextStyle(fontWeight: FontWeight.w600))),
                Text('未绑定机器', style: TextStyle(color: Colors.black45, fontSize: 12)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: kqwTextSecondary),
              ],
            ),
          ),
        ),
      );
    }

    final progress = machine.progress;
    final statusColor = machine.finished
        ? const Color(0xFF3F8600)
        : machine.newbieStatus == 2
            ? kqwPrimary
            : const Color(0xFFB25E00);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/machines'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.point_of_sale, color: kqwPrimary),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('机器达标监控',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      machine.newbieStatusName.isEmpty
                          ? (machine.finished ? '已完成' : '进行中')
                          : machine.newbieStatusName,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _machineStat(
                      '已刷金额',
                      '¥${progress.amount} / ¥${progress.target}',
                      progress.ratio,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _machineStat(
                      '剩余天数',
                      '${progress.daysLeft} 天',
                      (progress.daysLeft / 25).clamp(0.0, 1.0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: Colors.black45),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${machine.sn} · 期限 25 天，刷满 ${progress.target} 元即达标，达标送积分并入队',
                      style: const TextStyle(
                          color: Colors.black45, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _machineStat(String label, String value, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: progress, minHeight: 6),
        ),
      ],
    );
  }

  // ---------- 任务中心（进度 + 入口） ----------

  Widget _taskCard(BuildContext context) {
    final total = _newbieTasks.length;
    final done = _newbieTasks.where((t) => t.claimed).length;
    final claimable = _newbieTasks.where((t) => t.claimable).length;
    final next = _newbieTasks
        .where((t) => !t.claimed)
        .cast<TaskItem?>()
        .firstWhere((_) => true, orElse: () => null);
    final ratio = total == 0 ? 0.0 : done / total;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/tasks'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.task_alt, color: kqwPrimary),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('任务中心',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  Text(
                    claimable > 0 ? '$claimable 个可领取' : '剩 $total 项',
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right,
                      size: 18, color: kqwTextSecondary),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('新手任务 $done/$total',
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 13)),
                  const Spacer(),
                  Text('奖励 ${_newbieTasks.fold<String>('0', (s, t) => '${(int.tryParse(s) ?? 0) + (int.tryParse(t.rewardPoints) ?? 0)}')} 分',
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                child: LinearProgressIndicator(value: ratio, minHeight: 8),
              ),
              const SizedBox(height: 8),
              Text(
                total == 0
                    ? '暂无可做的新手任务'
                    : next == null
                        ? '新手任务全部完成，继续努力！'
                        : '再完成「${next.name}」得 ${next.rewardPoints} 积分',
                style:
                    const TextStyle(color: Colors.black45, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 公告 / 活动卡 ----------

  /// 首页只展示最近几条，其余进详情
  static const int _noticePreview = 3;

  Widget _noticeCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_outlined,
                    color: kqwPrimary, size: 20),
                const SizedBox(width: 8),
                const Text('平台公告',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (_notices.isNotEmpty)
                  Text('共 ${_notices.length} 条',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black38)),
              ],
            ),
            if (_notices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('暂无公告',
                    style: TextStyle(color: Colors.black45, fontSize: 12)),
              )
            else
              for (final notice in _notices.take(_noticePreview))
                InkWell(
                  onTap: () => _openNotice(notice),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        if (notice.isTop)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: kqwPrimary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('置顶',
                                style:
                                    TextStyle(fontSize: 10, color: kqwPrimary)),
                          ),
                        Expanded(
                          child: Text(
                            notice.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatDate(notice.displayAt),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.black38),
                        ),
                        const Icon(Icons.chevron_right,
                            size: 16, color: Colors.black26),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  /// 点公告：拉正文再弹窗；详情失败（刚好过期/下线）就退回列表摘要
  Future<void> _openNotice(NoticeItem item) async {
    String content;
    DateTime? at = item.displayAt;
    try {
      final detail = await noticeApi.detail(item.id);
      content = detail.content;
      at = detail.createdAt ?? at;
    } on ApiException catch (e) {
      if (item.summary.isEmpty) {
        if (mounted) showToast(context, e.displayMessage);
        return;
      }
      content = item.summary;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        content: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.5),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatDate(at),
                    style: const TextStyle(
                        fontSize: 11, color: Colors.black45)),
                const SizedBox(height: 8),
                Text(content,
                    style: const TextStyle(fontSize: 13, height: 1.6)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(text,
          style: const TextStyle(color: Colors.black45, fontSize: 13)),
    );
  }
}

// ---------- 轮播广告 ----------

/// 广告轮播：优先服务端 `GET /home/banners`，无数据时回落到本地兜底图。
class _AdCarousel extends StatefulWidget {
  const _AdCarousel({required this.banners});
  final List<BannerItem> banners;

  @override
  State<_AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<_AdCarousel> {
  int _index = 0;
  late final PageController _controller;
  Timer? _timer;

  static const _fallback = [
    _AdSlide('10 月达标冲刺', '达标额外 +100 积分，速来参与', Icons.campaign_rounded,
        'assets/carousel/ad_campaign.png'),
    _AdSlide('团队分红', '组建 7 人队伍，共享团队展业分红', Icons.groups_rounded,
        'assets/carousel/ad_team.png'),
    _AdSlide('积分商城上新', '热门商品限时积分兑换', Icons.storefront_rounded,
        'assets/carousel/ad_mall.png'),
  ];

  int get _count => widget.banners.isEmpty ? _fallback.length : widget.banners.length;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant _AdCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // banner 从空变有数据后，页码可能越界，重置到首屏
    if (oldWidget.banners.length != widget.banners.length) {
      _index = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
      _timer?.cancel();
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_controller.hasClients || _count <= 1) return;
      final next = (_index + 1) % _count;
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    });
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    _startAutoScroll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      height: 120,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              itemCount: _count,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, i) => widget.banners.isEmpty
                  ? _slide(context, _fallback[i])
                  : _remoteSlide(context, widget.banners[i]),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 10,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_count, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: active ? 14 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slide(BuildContext context, _AdSlide ad) {
    return InkWell(
      onTap: () => showToast(context, '「${ad.title}」活动详情待接入'),
      child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: AssetImage(ad.asset), fit: BoxFit.cover),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Color(0x29FFFFFF)),
              child: Icon(ad.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(ad.title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(ad.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _remoteSlide(BuildContext context, BannerItem banner) {
    return InkWell(
      onTap: () => _openBanner(context, banner),
      child: Container(
        color: kqwPrimary,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (banner.hasImage)
              Image.network(
                banner.image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            // 底部压一层渐变，保证文字在浅色图上也读得清
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0x99000000)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(banner.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  if (banner.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(banner.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// linkType：0 不跳转 / 1 内部路由 / 2 外链 / 3 商品详情
  void _openBanner(BuildContext context, BannerItem banner) {
    if (!banner.clickable) return;
    switch (banner.linkType) {
      case 1:
        context.push(banner.linkValue);
      case 3:
        context.push('/mall');
      default:
        showToast(context, '外链暂未接入：${banner.linkValue}');
    }
  }
}

class _AdSlide {
  const _AdSlide(this.title, this.subtitle, this.icon, this.asset);

  final String title;
  final String subtitle;
  final IconData icon;
  final String asset;
}
