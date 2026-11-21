import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/home_api.dart';
import '../../core/api/message_api.dart';
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
import '../../core/widgets/unread_badge.dart';
import '../team/enter_room_flow.dart';

/// 首页：广告轮播 / 购买升级礼包 / 机器达标监控 / 平台公告
///
/// 数据源（除 banner 公开外都需 app token）：
/// - `GET /home/banners`（空时用本地兜底图，不算错误）
/// - `GET /team/room-packages`（入房档位，只展示未购买的档位）
/// - `GET /user/points`（入房前判断积分是否够）
/// - `GET /pos/machines`（取本人全部机器，按是否达标筛出待监控的）
///
/// 已购买的档位整卡不展示：买过就不再需要「购买升级礼包」入口，
/// 仍可从「我的团队」进入房间。
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<BannerItem> _banners = const [];
  List<NoticeItem> _notices = const [];
  List<RoomPackage> _roomPackages = const [];
  List<Machine> _machines = const [];
  List<TaskItem> _newbieTasks = const [];
  PointsSummary? _points;
  bool _loading = true;

  /// 站内消息未读数（首页顶部消息入口的红点）
  int _unread = 0;

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
        _loadMachines(),
        _loadTasks(),
        _loadUnread(),
      ]);
    }
    if (mounted) setState(() => _loading = false);
  }

  /// 未读数只驱动红点：失败静默（不打断首屏其它模块）
  Future<void> _loadUnread() async {
    try {
      final unread = await messageApi.unreadCount();
      if (mounted) setState(() => _unread = unread);
    } on ApiException {
      // 消息模块不可用时保留上一次数字，不弹错
    }
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
      // 余额未知时确认弹窗里就不展示当前积分，不阻断点击
    }
  }

  /// 拉本人全部机器：首页只展示未达标且窗口未过期的，达标的不再占位。
  ///
  /// `/pos/machines` 是分页接口，只取第一页会让第 21 台起的机器静默消失——
  /// 而这张卡存在的意义正是防止漏掉达标窗口，所以按 total 续页收齐。
  Future<void> _loadMachines() async {
    try {
      final all = <Machine>[];
      var pageNum = 1;
      while (true) {
        final page = await posApi.machines(pageNum: pageNum, pageSize: 20);
        all.addAll(page.items);
        // items 为空即兜底退出：total 与实际条数不一致时不会死循环
        if (page.items.isEmpty || all.length >= page.total) break;
        pageNum++;
      }
      if (mounted) setState(() => _machines = all);
    } on ApiException {
      if (mounted) setState(() => _machines = const []);
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        // 首页没有 AppBar，列表从屏幕顶端开始，需自己让出状态栏高度，
        // 否则顶部轮播图会被系统状态栏压住。
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 20,
          bottom: 24,
        ),
        children: [
          _AdCarousel(banners: _banners),
          const SizedBox(height: 12),
          _messageEntryCard(),
          _applyEntryCard(),
          _noticeCard(),
          // 购买升级礼包：只展示「未购买」的档位，买过的整卡不出现
          for (final pkg in _roomPackages.where((p) => !p.purchased))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _giftCard(context, pkg),
            ),
          const SizedBox(height: 12),
          // 会员等级与任务中心入口按运营要求暂时下线（组件保留，恢复时加回这两行）
          _machineMonitor(context),
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

  // ---------- 站内消息入口（团队长装机提醒等） ----------

  /// 有未读时卡片描边变主色并显示数字，避免装机人漏掉下级的装机申请
  Widget _messageEntryCard() {
    final hasUnread = _unread > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await context.push('/messages');
          // 从消息页回来刷新红点（点开详情后端已置已读）
          if (mounted) await _loadUnread();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: hasUnread ? kqwPrimary.withValues(alpha: 0.35) : const Color(0xFFEDEFF3),
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: kqwPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_none, size: 22, color: kqwPrimary),
                  ),
                  if (hasUnread) UnreadBadge(count: _unread),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '站内消息',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1F2430)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasUnread ? '你有 $_unread 条未读消息' : '下级装机申请等业务通知',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8A94A6)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20, color: Color(0xFFB6BDC9)),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- 购买升级礼包（未购买档位） ----------

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
    // 扣过分要立刻同步余额，还要刷新档位：本档位买过后首页不再展示
    _loadPoints();
    _loadRoomPackages();
  }

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

  // ---------- 等级进度（L1 → L2 双条件取较优） ----------

  // ignore: unused_element
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

  // ---------- 机器达标监控（只列未达标且窗口未过期的机器） ----------

  Widget _machineMonitor(BuildContext context) {
    final monitoring = _machines.where((m) => m.needsMonitor).toList();
    if (monitoring.isEmpty) return _machineEmptyCard(context);
    // 装机多的业务员可能十几张卡：按需构建，避免首页每次 setState 全量重建
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: monitoring.length,
      itemBuilder: (context, i) => _monitorCard(context, i + 1, monitoring[i]),
    );
  }

  /// 空态文案按真实原因区分：全部达标与「窗口已过期但没达标」是两种结论，
  /// 后者显示成「机器均已达标」等于把丢了奖励说成好消息。
  String get _machineEmptyHint {
    if (_machines.isEmpty) return '未绑定机器';
    if (_machines.every((m) => m.reachedTarget)) return '机器均已达标';
    if (_machines.any((m) => m.progress.expired)) return '达标窗口已结束';
    return '暂无需跟进';
  }

  /// 没有需要监控的机器时的入口卡（未绑机器 / 都已达标 / 窗口已结束都走这里）
  Widget _machineEmptyCard(BuildContext context) {
    final hint = _machineEmptyHint;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/machines'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.point_of_sale, color: kqwPrimary),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('机器达标监控',
                      style: TextStyle(fontWeight: FontWeight.w600))),
              Text(hint,
                  style: const TextStyle(color: Colors.black45, fontSize: 12)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: kqwTextSecondary),
            ],
          ),
        ),
      ),
    );
  }

  /// 单台未达标机器：左侧剩余天数大字，右侧门店名 + 机号，底部达标规则
  Widget _monitorCard(BuildContext context, int index, Machine machine) {
    final statusColor = machine.newbieStatus == 2
        ? kqwPrimary
        : machine.newbieStatus == 1
            ? const Color(0xFFB25E00)
            : Colors.black45;
    // 每次 build 都按当前时间重算，页面重新打开/下拉刷新都会刷新天数
    final daysLeft = machine.daysLeftToReach;
    final statusName = machine.newbieStatusName.isNotEmpty
        ? machine.newbieStatusName
        : (machine.finished ? '已完成' : '进行中');
    final merchant = machine.merchantName?.trim() ?? '';
    final shopLabel = merchant.isEmpty
        ? (machine.model.isEmpty ? '未命名门店' : machine.model)
        : merchant;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                  const Icon(Icons.point_of_sale, color: kqwPrimary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('机器达标监控（$index）',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusName,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('达标剩余天数',
                            style: TextStyle(
                                color: Colors.black54, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          '$daysLeft天',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: daysLeft <= 3
                                ? const Color(0xFFE53935)
                                : kqwPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 42, color: const Color(0xFFEEEEEE)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shopLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          machine.sn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.black45, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _monitorRuleText(machine),
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 达标规则：从装机之日起 N 天内刷卡累计 X 元奖励 Y 积分
  String _monitorRuleText(Machine machine) {
    final window = machine.windowDays > 0 ? '${machine.windowDays}天' : '任务期内';
    final amount = _moneyLabel(machine.progress.target);
    final points = _moneyLabel(machine.taskSelfPoints);
    final reward = points == '0' ? '' : '奖励$points积分';
    return '从装机之日起$window内刷卡累计$amount元$reward';
  }

  /// 金额/积分去掉尾随的 .00（接口下发字符串，这里只做展示格式化）
  String _moneyLabel(String raw) {
    final value = double.tryParse(raw);
    if (value == null) return raw;
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  // ---------- 任务中心（进度 + 入口） ----------

  // ignore: unused_element
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
      height: 180,
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
