import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/team_api.dart';
import '../../core/api_client.dart';
import '../../core/models/page_result.dart';
import '../../core/models/team_room.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import 'enter_room_flow.dart';
import 'room_detail_view.dart';

/// 团队页选项卡：按房间等级（`TeamRoom.level`，即入房档位）分组。
///
/// [level] 为 null 的是兜底页「其他」：房间未定级（`level == null`）或档位
/// 不是 L1/L2 时，避免自己的房间在有数据的页面上凭空消失。
class _RoomTab {
  const _RoomTab(this.label, this.level);

  final String label;
  final int? level;

  bool matches(int? roomLevel) =>
      level == null ? (roomLevel != 1 && roomLevel != 2) : roomLevel == level;
}

const List<_RoomTab> _baseTabs = [_RoomTab('L1', 1), _RoomTab('L2', 2)];
const _RoomTab _otherTab = _RoomTab('其他', null);

/// 我的团队：按 L1 / L2 选项卡切换，选项卡内直接铺开房间详情 ——
/// 最上是「我筹备中的房间」，下面「已结束」按结束时间倒序
/// （接口未下发结束时间时按 id 倒序，近似最近结束在前）。
///
/// 数据源 `GET /team/rooms`（我占过位或我当队长的房间）与
/// `GET /team/wait-queue`；点房间卡片进 `/room/:id` 单页详情。
class TeamTab extends StatefulWidget {
  const TeamTab({super.key, this.api});

  /// 便于测试注入，缺省用全局 [teamApi]
  final TeamApi? api;

  @override
  State<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<TeamTab> with TickerProviderStateMixin {
  List<TeamRoom> _rooms = const [];
  List<WaitQueueItem> _waitQueue = const [];
  bool _loading = true;
  String? _error;

  TabController? _tabs;
  List<_RoomTab> _tabSpecs = _baseTabs;

  TeamApi get _api => widget.api ?? teamApi;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _baseTabs.length, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 两个请求并行发出；pageSize 顶到后端上限，房间总量不大。
      // 用 Future.wait 而非裸的并发 await：任一失败时另一只的异常也已被
      // 内部接管，不会逃逸成 uncaught async error。
      final results = await Future.wait<Object>([
        _api.rooms(pageSize: 100),
        _api.waitQueue(),
      ]);
      final page = results[0] as PageResult<TeamRoom>;
      final queue = results[1] as List<WaitQueueItem>;
      if (!mounted) return;
      setState(() {
        _rooms = page.items;
        _waitQueue = queue;
        _error = null;
        _syncTabSpecs(page.items);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _rooms = const [];
        _waitQueue = const [];
        _error = e.displayMessage;
        _syncTabSpecs(const []);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 出现非 L1/L2 的房间时补一个「其他」选项卡，其余情况保持两个。
  void _syncTabSpecs(List<TeamRoom> rooms) {
    final specs = rooms.any((r) => r.level != 1 && r.level != 2)
        ? const [..._baseTabs, _otherTab]
        : _baseTabs;
    final current = _tabs;
    if (current != null && current.length == specs.length) {
      _tabSpecs = specs;
      return;
    }
    final index = current == null ? 0 : current.index.clamp(0, specs.length - 1);
    final old = current;
    _tabs = TabController(length: specs.length, vsync: this, initialIndex: index);
    _tabSpecs = specs;
    // 等这一帧把 TabBar 重新绑定到新 controller 之后再释放旧的
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  /// 选档位后调 `POST /team/rooms/enter`；成功后刷新列表把新房间带出来。
  /// 团队页不拉积分总览，余额传 null（不展示当前积分，以后端判定为准）。
  Future<void> _enterRoom() async {
    final result = await pickPackageAndEnter(context);
    if (result == null || !mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的团队'),
        actions: [
          TextButton(
            onPressed: _enterRoom,
            child: const Text(
              '进入房间',
              style: TextStyle(fontSize: 14, color: kqwPrimary),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: AsyncStateView(
          loading: _loading,
          error: _error,
          isEmpty: _rooms.isEmpty && _waitQueue.isEmpty,
          onRetry: _load,
          emptyText: '还没有加入团队，达标后在队列中自动组队',
          emptyIcon: Icons.groups_outlined,
          child: tabs == null
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    Material(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: TabBar(
                        controller: tabs,
                        labelColor: kqwPrimary,
                        unselectedLabelColor: Colors.black54,
                        indicatorColor: kqwPrimary,
                        indicatorSize: TabBarIndicatorSize.label,
                        tabs: [
                          for (final spec in _tabSpecs) Tab(text: spec.label),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: tabs,
                        children: [for (final spec in _tabSpecs) _tabBody(spec)],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// 单个选项卡：筹备中（status=0）在上，已结束（status=2）在下。
  /// 进行中（status=1）的房间不在此页展示。
  Widget _tabBody(_RoomTab tab) {
    final preparing = _rooms
        .where((r) => r.status == 0 && tab.matches(r.level))
        .toList()
      ..sort((a, b) => b.idValue.compareTo(a.idValue));
    final ended = _rooms
        .where((r) => r.status == 2 && tab.matches(r.level))
        .toList()
      ..sort(_compareEnded);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle('我筹备中的房间', preparing.length),
        if (preparing.isEmpty)
          _sectionEmpty('暂无筹备中的房间')
        else
          for (final room in preparing) ...[
            _roomBlock(room),
            const SizedBox(height: 12),
          ],
        const SizedBox(height: 4),
        _sectionTitle('已结束', ended.length),
        if (ended.isEmpty)
          _sectionEmpty('暂无已结束的房间')
        else
          for (final room in ended) ...[
            _roomBlock(room, ended: true),
            const SizedBox(height: 12),
          ],
        if (_waitQueue.isNotEmpty) ...[
          const SizedBox(height: 4),
          _waitQueueCard(),
        ],
      ],
    );
  }

  /// 已结束房间排序：有结束时间按结束时间倒序；缺时间的一律沉底，
  /// 同组内按 id 倒序（归档不改 id，id 越大创建越晚，近似最近结束在前）。
  int _compareEnded(TeamRoom a, TeamRoom b) {
    final at = a.endedAt;
    final bt = b.endedAt;
    if (at != null && bt != null) {
      final byTime = bt.compareTo(at);
      if (byTime != 0) return byTime;
    } else if (at != null) {
      return -1;
    } else if (bt != null) {
      return 1;
    }
    return b.idValue.compareTo(a.idValue);
  }

  Widget _sectionTitle(String text, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: kqwPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text('$count',
              style: const TextStyle(fontSize: 12, color: Colors.black45)),
        ],
      ),
    );
  }

  Widget _sectionEmpty(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: Colors.black38)),
    );
  }

  /// 一间房：整张卡片就是详情（表头 + 1+2+4 座位图），点开进单页详情。
  /// 已结束的房间补一行结束时间。
  Widget _roomBlock(TeamRoom room, {bool ended = false}) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/room/${room.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RoomDetailView(room: room),
              if (ended) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.event_available,
                        size: 14, color: Colors.black38),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        room.endedAtText.isEmpty
                            ? '结束时间未记录'
                            : '结束于 ${room.endedAtText}',
                        style: const TextStyle(
                            fontSize: 11.5, color: Colors.black45),
                      ),
                    ),
                    const Text('查看详情',
                        style: TextStyle(fontSize: 11.5, color: kqwPrimary)),
                    const Icon(Icons.chevron_right,
                        size: 16, color: kqwPrimary),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _waitQueueCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hourglass_bottom, size: 18, color: kqwPrimary),
                const SizedBox(width: 6),
                const Text('候补队列',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${_waitQueue.length} 人排队',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black45)),
              ],
            ),
            const SizedBox(height: 10),
            ..._waitQueue.take(10).map(
                  (w) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: kqwPrimary.withValues(alpha: 0.1),
                          child: Text('${w.position}',
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: kqwPrimary,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(w.displayName,
                              style: const TextStyle(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text(w.levelLabel,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black45)),
                      ],
                    ),
                  ),
                ),
            if (_waitQueue.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('还有 ${_waitQueue.length - 10} 人…',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black38)),
              ),
          ],
        ),
      ),
    );
  }
}
