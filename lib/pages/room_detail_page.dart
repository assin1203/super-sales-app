import 'package:flutter/material.dart';

import '../core/api/team_api.dart';
import '../core/api_client.dart';
import '../core/models/team_room.dart';
import '../core/widgets/async_view.dart';
import '../features/team/room_detail_view.dart';

/// 房间详情（FR-10.3：1+2+4 布局、权重展示、分红轮次）
///
/// 数据源 `GET /team/rooms/{id}`（座位含空位）；
/// 表头与座位板复用 [RoomDetailView]，与「我的团队」页保持同一套渲染。
class RoomDetailPage extends StatefulWidget {
  const RoomDetailPage({super.key, required this.roomId, this.api});

  final String roomId;

  /// 便于测试注入，缺省用全局 [teamApi]
  final TeamApi? api;

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  TeamRoom? _room;
  bool _loading = true;
  String? _error;

  TeamApi get _api => widget.api ?? teamApi;

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
      final room = await _api.roomDetail(widget.roomId);
      if (!mounted) return;
      setState(() {
        _room = room;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _room = null;
        _error = e.displayMessage;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    return Scaffold(
      appBar: AppBar(title: Text('房间 #${room?.roomNo ?? widget.roomId} 详情')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: AsyncStateView(
          loading: _loading,
          error: _error,
          isEmpty: room == null,
          onRetry: _load,
          emptyText: '房间不存在或已解散',
          emptyIcon: Icons.meeting_room_outlined,
          // AsyncStateView 在空态/加载态时仍会构建 child，
          // 这里显式判空，避免空断言在无数据帧上崩溃。
          child: room == null
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [RoomDetailView(room: room)],
                ),
        ),
      ),
    );
  }
}
