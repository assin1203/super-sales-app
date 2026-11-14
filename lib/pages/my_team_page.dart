import 'package:flutter/material.dart';

import '../core/api/user_api.dart';
import '../core/api_client.dart';
import '../core/models/invite.dart';
import '../core/widgets/async_view.dart';

/// 我的团队：只列「我直接推荐」的成员（一级直推）。
///
/// 数据源 `GET /user/invite/records`（后端按 `maskPhone` 脱敏），
/// 前端再兜底打码一次，避免后端漏脱敏时明文手机号出现在列表里。
class MyTeamPage extends StatefulWidget {
  const MyTeamPage({super.key, this.api});

  /// 便于测试注入；生产走全局 [userApi]
  final UserApi? api;

  @override
  State<MyTeamPage> createState() => _MyTeamPageState();
}

class _MyTeamPageState extends State<MyTeamPage> {
  late final UserApi _api = widget.api ?? userApi;

  InviteSummary _summary = InviteSummary.empty;
  List<InviteRecord> _records = const [];
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
        _api.invite(),
        _api.inviteRecords(pageSize: 100),
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

  /// 手机号打码：后端已返回 `138****8000`，对已脱敏值幂等；
  /// 万一来的是明文，这里兜底成同样的格式。
  String _maskPhone(String phone) {
    final p = phone.trim();
    if (p.length >= 11) return '${p.substring(0, 3)}****${p.substring(7)}';
    if (p.length > 1) return '${p.substring(0, 1)}****';
    return p;
  }

  /// 头像占位字：昵称为空时 `characters.first` 会抛 StateError，兜成 '?'
  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的团队')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _summaryCard(),
            const SizedBox(height: 12),
            _listCard(),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: _stat('${_summary.invitedCount}', '直推人数'),
            ),
            Container(width: 1, height: 28, color: const Color(0xFFEEEEEE)),
            Expanded(
              child: _stat('${_summary.qualifiedCount}', '已达标'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black45)),
        ],
      );

  Widget _listCard() {
    if (_loading && _records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (_error != null && _records.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Column(
            children: [
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black45)),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('直推成员',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            if (_records.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('还没有直推成员，去「推荐海报」分享推广码邀请好友',
                    style: TextStyle(color: Colors.black45)),
              )
            else
              ..._records.map(_recordRow),
          ],
        ),
      ),
    );
  }

  Widget _recordRow(InviteRecord r) {
    return Padding(
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
                const SizedBox(height: 2),
                Text(
                  '${_maskPhone(r.phone)} · ${r.levelLabel} · ${formatDate(r.registeredAt)} 注册',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.black45),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            r.qualified ? '已达标' : '未达标',
            style: TextStyle(
              fontSize: 12,
              color:
                  r.qualified ? const Color(0xFF3F8600) : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }
}
