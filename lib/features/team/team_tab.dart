import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/team_api.dart';
import '../../core/api_client.dart';
import '../../core/models/team_room.dart';
import '../../core/theme.dart';
import '../../core/widgets/async_view.dart';
import 'enter_room_flow.dart';

/// 我的团队：进行中房间置顶（座位 + 贡献值 + 轮次 + 奖池），
/// 结束后房间在下；底部展示候补队列。
///
/// 数据源 `GET /team/rooms` 与 `GET /team/wait-queue`，点卡片进房间详情。
class TeamTab extends StatefulWidget {
  const TeamTab({super.key});

  @override
  State<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<TeamTab> {
  List<TeamRoom> _rooms = const [];
  List<WaitQueueItem> _waitQueue = const [];
  bool _loading = true;
  String? _error;

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
        teamApi.rooms(pageSize: 50),
        teamApi.waitQueue(),
      ]);
      if (!mounted) return;
      final rooms = (results[0] as dynamic).items as List<TeamRoom>;
      // 进行中（status=1）置顶，其次筹备中，已结束沉底
      rooms.sort((a, b) => _rank(b).compareTo(_rank(a)));
      setState(() {
        _rooms = rooms;
        _waitQueue = results[1] as List<WaitQueueItem>;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _rooms = const [];
        _waitQueue = const [];
        _error = e.displayMessage;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _rank(TeamRoom r) => switch (r.status) {
        1 => 2,
        0 => 1,
        _ => 0,
      };

  /// 选档位后调 `POST /team/rooms/enter`；成功后刷新列表把新房间带出来。
  /// 团队页不拉积分总览，余额传 null（不展示当前积分，以后端判定为准）。
  Future<void> _enterRoom() async {
    final result = await pickPackageAndEnter(context);
    if (result == null || !mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final room in _rooms) ...[
                _roomCard(room),
                const SizedBox(height: 12),
              ],
              if (_waitQueue.isNotEmpty) ...[
                const SizedBox(height: 4),
                _waitQueueCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _roomCard(TeamRoom room) {
    final inProgress = room.status == 1;
    final totalContribution = room.positions.fold<int>(
      0,
      (sum, p) => sum + (int.tryParse(p.contribution) ?? 0),
    );
    // 权重进度：贡献值占满座位的比例（每座位 2 点为上限）
    final progress = room.positions.isEmpty
        ? 0.0
        : (totalContribution / (room.positions.length * 2)).clamp(0.0, 1.0);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/room/${room.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: inProgress
                          ? kqwPrimary.withValues(alpha: 0.1)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      room.statusName.isEmpty ? '未知状态' : room.statusName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: inProgress ? kqwPrimary : Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('房间 ${room.roomNo}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${room.memberCount}/${room.positions.length} 人',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black45)),
                  const Icon(Icons.chevron_right,
                      size: 18, color: Colors.black26),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(
                            inProgress ? kqwPrimary : Colors.grey.shade400),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('权重 $totalContribution',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.black45)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _metric('第 ${room.round} 轮', '轮次'),
                  const SizedBox(width: 20),
                  _metric(room.levelLabel, '等级'),
                  const SizedBox(width: 20),
                  _metric(room.rewardPool, inProgress ? '目标奖池' : '已分奖池'),
                  const Spacer(),
                  if (room.myPosition != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kqwPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('我的位置 ${room.myPosition}',
                          style:
                              const TextStyle(fontSize: 11, color: kqwPrimary)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.black45)),
      ],
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
