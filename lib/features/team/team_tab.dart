import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth_provider.dart';
import '../../core/theme.dart';

/// 我的团队：进行中的队伍置顶（成员头像 + 贡献值 + 进度），
/// 已完成队伍在下（展示分到的积分）。
class TeamTab extends StatelessWidget {
  const TeamTab({super.key});

  /// 固定 6 人制团队（房主 1 + 成员 5，排布 1/2/3）
  static const int _teamSize = 6;

  /// 队伍贡献值上限（每成员最多 2 点）
  static const int _maxContribution = _teamSize * 2;

  /// 成员首字头像配色
  static const List<Color> _avatarPalette = [
    Color(0xFF2B5BFF),
    Color(0xFF00A9E8),
    Color(0xFF7A5CFF),
    Color(0xFF2BAE7E),
    Color(0xFFF5A623),
    Color(0xFFF0564A),
    Color(0xFF5C6B8A),
  ];

  static final List<_Team> _teams = [
    // ---------- 进行中（置顶） ----------
    const _Team(
      number: 64,
      inProgress: true,
      startTime: '2025-12-23',
      reward: 600,
      members: [
        _TeamMember('我', 2, isSelf: true, done: true),
        _TeamMember('王磊', 2, done: true),
        _TeamMember('李娜', 1),
        _TeamMember('张倩', 1),
      ],
    ),
    // ---------- 已完成 ----------
    const _Team(
      number: 121,
      inProgress: false,
      startTime: '2025-11-23',
      finishTime: '2025-12-12',
      reward: 600,
      members: [
        _TeamMember('王磊', 2, done: true),
        _TeamMember('李娜', 2, done: true),
        _TeamMember('刘洋', 2, done: true),
        _TeamMember('陈晨', 2, done: true),
        _TeamMember('杨帆', 1),
        _TeamMember('赵敏', 0),
      ],
    ),
    const _Team(
      number: 95,
      inProgress: false,
      startTime: '2025-10-14',
      finishTime: '2025-11-02',
      reward: 600,
      members: [
        _TeamMember('周涛', 2, done: true),
        _TeamMember('吴敏', 2, done: true),
        _TeamMember('郑浩', 1),
        _TeamMember('孙丽', 1),
        _TeamMember('马俊', 0),
      ],
    ),
    const _Team(
      number: 59,
      inProgress: false,
      startTime: '2025-09-10',
      finishTime: '2025-10-01',
      reward: 600,
      members: [
        _TeamMember('朱明', 2, done: true),
        _TeamMember('胡雪', 2, done: true),
        _TeamMember('郭强', 2, done: true),
        _TeamMember('林芳', 1),
        _TeamMember('何平', 1),
        _TeamMember('高翔', 0),
      ],
    ),
    const _Team(
      number: 42,
      inProgress: false,
      startTime: '2025-08-15',
      finishTime: '2025-09-12',
      reward: 600,
      members: [
        _TeamMember('梁宇', 2, done: true),
        _TeamMember('宋佳', 2, done: true),
        _TeamMember('唐军', 2, done: true),
        _TeamMember('韩梅', 1),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final inProgress = _teams.where((t) => t.inProgress).toList();
    final completed = _teams.where((t) => !t.inProgress).toList();
    final earned = completed.fold(0, (sum, t) => sum + t.reward);
    final selfAvatar = context.read<AuthProvider>().avatarBytes;
    return Scaffold(
      appBar: AppBar(title: const Text('我的团队')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _header(inProgress.length, completed.length, earned),
          const SizedBox(height: 20),
          _sectionTitle('进行中', inProgress.length, kqwPrimary),
          const SizedBox(height: 10),
          ...inProgress.map((t) => _inProgressCard(t, selfAvatar)),
          const SizedBox(height: 16),
          _sectionTitle('已完成', completed.length, kqwTextSecondary),
          const SizedBox(height: 10),
          ...completed.map((t) => _completedCard(t)),
        ],
      ),
    );
  }

  // ---------- 渐变统计条 ----------

  Widget _header(int inCount, int doneCount, int earned) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(gradient: kqwHeaderGradient),
      child: Stack(
        children: [
          Positioned(top: -30, right: -20, child: _decoCircle(120)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                _stat('$inCount 个', '进行中'),
                _stat('$doneCount 个', '已完成'),
                _stat('$earned 积分', '累计获得'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _decoCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.14), Colors.white.withValues(alpha: 0.02)],
        ),
      ),
    );
  }

  // ---------- 区块标题 ----------

  Widget _sectionTitle(String title, int count, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text('$count 支', style: const TextStyle(fontSize: 13, color: kqwTextSecondary)),
        ],
      ),
    );
  }

  // ---------- 进行中队伍卡片（点击展开成员明细） ----------

  Widget _inProgressCard(_Team team, Uint8List? selfAvatar) =>
      _InProgressCard(team: team, selfAvatar: selfAvatar);

  // ---------- 已完成队伍卡片（点击展开成员明细） ----------

  Widget _completedCard(_Team team) => _CompletedCard(team: team);

}

// ---------- 成员树：房主首排，第二排 2 人，第三排 3 人；人左空右 ----------

/// 成员树每排座位数
const List<int> _rowSizes = [1, 2, 3];

Widget _memberTree(_Team team, Uint8List? selfAvatar) {
  final slots = List<_TeamMember?>.generate(
    TeamTab._teamSize,
    (i) => i < team.members.length ? team.members[i] : null,
  );
  var offset = 0;
  return Column(
    children: [
      for (var r = 0; r < _rowSizes.length; r++) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _rowSizes[r]; i++) ...[
              if (i > 0) const SizedBox(width: 24),
              _seat(slots[offset++], selfAvatar),
            ],
          ],
        ),
        if (r < _rowSizes.length - 1) const SizedBox(height: 14),
      ],
    ],
  );
}

Widget _seat(_TeamMember? member, Uint8List? selfAvatar) {
  return member == null ? _emptySeat() : _memberTile(member, selfAvatar);
}

/// 成员格子（头像 + 姓名 + 贡献值）
Widget _memberTile(_TeamMember m, Uint8List? selfAvatar) {
  return Column(
    children: [
      Stack(
        clipBehavior: Clip.none,
        children: [
          _memberAvatar(m, selfAvatar),
          if (m.isSelf || m.done)
            Positioned(top: -2, right: -2, child: _badge(m.isSelf)),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        m.isSelf ? '我（房主）' : m.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: Color(0xFF1F2430)),
      ),
      const SizedBox(height: 2),
      Text('贡献值 ${m.contribution}', style: pointsTextStyle(size: 12)),
    ],
  );
}

/// 房主金色皇冠，达标成员蓝色对勾
Widget _badge(bool isLeader) {
  return Container(
    width: 16,
    height: 16,
    decoration: BoxDecoration(
      color: isLeader ? const Color(0xFFF5A623) : kqwPrimary,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 1.5),
    ),
    child: Icon(isLeader ? Icons.emoji_events : Icons.check, size: 10, color: Colors.white),
  );
}

Widget _memberAvatar(_TeamMember m, Uint8List? selfAvatar) {
  if (m.isSelf) {
    return ClipOval(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: kqwPrimary, width: 2),
        ),
        child: selfAvatar != null
            ? Image.memory(selfAvatar, width: 52, height: 52, fit: BoxFit.cover)
            : Image.asset('assets/avatar.jpeg', width: 52, height: 52),
      ),
    );
  }
  final color = TeamTab._avatarPalette[m.name.codeUnitAt(0) % TeamTab._avatarPalette.length];
  return CircleAvatar(
    radius: 26,
    backgroundColor: color,
    child: Text(
      m.name.substring(0, 1),
      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
    ),
  );
}

Widget _emptySeat() {
  return Column(
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFF5F7FA),
          border: Border.all(color: const Color(0xFFE3E8F0), width: 1.5),
        ),
        child: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFFB6BFCE), size: 22),
      ),
      const SizedBox(height: 6),
      const Text('空位', style: TextStyle(fontSize: 12, color: Color(0xFFB6BFCE))),
      const SizedBox(height: 2),
      const Text('—', style: TextStyle(fontSize: 12, color: Color(0xFFD5DBE5))),
    ],
  );
}

/// 展开后的成员明细：座位号 + 贡献值降序（进行中 / 已完成卡片共用）
Widget _memberDetailList(List<_TeamMember> members) {
  final ranked = [
    for (var i = 0; i < members.length; i++)
      (seat: i + 1, member: members[i]),
  ]..sort((a, b) => b.member.contribution.compareTo(a.member.contribution));
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Divider(height: 1),
      const SizedBox(height: 6),
      for (final r in ranked)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              _miniAvatar(r.member),
              const SizedBox(width: 8),
              Text(r.member.name,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1F2430))),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF1F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('${r.seat}号位',
                    style: const TextStyle(fontSize: 11, color: kqwTextSecondary)),
              ),
              const Spacer(),
              if (r.member.done)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_circle, size: 14, color: kqwPrimary),
                ),
              Text('贡献值 ${r.member.contribution}', style: pointsTextStyle(size: 12)),
            ],
          ),
        ),
    ],
  );
}

/// 进行中队伍卡片：点击展开成员明细（座位号 + 贡献值降序）
class _InProgressCard extends StatefulWidget {
  const _InProgressCard({required this.team, this.selfAvatar});

  final _Team team;
  final Uint8List? selfAvatar;

  @override
  State<_InProgressCard> createState() => _InProgressCardState();
}

class _InProgressCardState extends State<_InProgressCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    final total = team.members.fold(0, (s, m) => s + m.contribution);
    final progress = (total / TeamTab._maxContribution).clamp(0.0, 1.0);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('队伍 #${team.number}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        _statusChip(true),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '开始 ${team.startTime}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: kqwTextSecondary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: kqwTextSecondary),
                ],
              ),
              const SizedBox(height: 16),
              _memberTree(team, widget.selfAvatar),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('队伍贡献值',
                      style: TextStyle(fontSize: 12, color: kqwTextSecondary)),
                  const SizedBox(width: 8),
                  Text('$total / ${TeamTab._maxContribution} 点',
                      style: pointsTextStyle(size: 13)),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      '进房 ${team.reward} 积分',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF5A623)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFEEF1F6),
                  valueColor: const AlwaysStoppedAnimation<Color>(kqwPrimary),
                ),
              ),
              if (_expanded) ...[
                const SizedBox(height: 12),
                _memberDetailList(team.members),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 状态徽标：进行中 = 渐变，已完成 = 浅灰
Widget _statusChip(bool inProgress) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      gradient: inProgress
          ? const LinearGradient(colors: [kqwPrimary, Color(0xFF00A9E8)])
          : null,
      color: inProgress ? null : const Color(0xFFF2F4F8),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      inProgress ? '进行中' : '已完成',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: inProgress ? Colors.white : kqwTextSecondary,
      ),
    ),
  );
}

/// 成员头像叠放：最多 4 个 + 「+N」，相邻重叠 10px（整体占位精确，不会挤压同行内容）
Widget _overlapAvatars(List<_TeamMember> members) {
  final show = members.take(4).toList();
  final more = members.length - show.length;
  const double size = 24;
  const double overlap = 10;
  final total = show.isEmpty
      ? 0.0
      : size + (show.length - 1) * (size - overlap) + (more > 0 ? size - overlap : 0.0);
  return SizedBox(
    width: total,
    height: size,
    child: Stack(
      alignment: Alignment.centerLeft,
      children: [
        for (var i = 0; i < show.length; i++)
          Positioned(
            left: i * (size - overlap),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _miniAvatar(show[i]),
            ),
          ),
        if (more > 0)
          Positioned(
            left: show.length * (size - overlap),
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8ECF3)),
              alignment: Alignment.center,
              child: Text('+$more',
                  style: const TextStyle(fontSize: 10, color: kqwTextSecondary)),
            ),
          ),
      ],
    ),
  );
}

/// 成员首字头像（24px，按名字取色）
Widget _miniAvatar(_TeamMember m) {
  final color =
      TeamTab._avatarPalette[m.name.codeUnitAt(0) % TeamTab._avatarPalette.length];
  return Container(
    width: 24,
    height: 24,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    alignment: Alignment.center,
    child: Text(
      m.name.substring(0, 1),
      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

/// 已完成队伍卡片：点击可展开查看全部成员明细
class _CompletedCard extends StatefulWidget {
  const _CompletedCard({required this.team});

  final _Team team;

  @override
  State<_CompletedCard> createState() => _CompletedCardState();
}

class _CompletedCardState extends State<_CompletedCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final team = widget.team;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('队伍 #${team.number}',
                            style:
                                const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        _statusChip(false),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '获得 ${team.reward} 积分',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFF5A623)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: kqwTextSecondary),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 13, color: kqwTextSecondary),
                        const SizedBox(width: 4),
                        Text('${team.startTime} → ${team.finishTime}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: kqwTextSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _overlapAvatars(team.members),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 16),
                _memberTree(team, null),
                const SizedBox(height: 8),
                _memberDetailList(team.members),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 队伍成员：姓名 + 贡献值（积分）
class _TeamMember {
  const _TeamMember(this.name, this.contribution, {this.done = false, this.isSelf = false});

  final String name;

  /// 贡献值（0-2 点）
  final int contribution;

  /// 是否已达标
  final bool done;

  /// 是否本人（队长）
  final bool isSelf;
}

/// 队伍：编号 / 状态 / 时间 / 积分 / 成员
class _Team {
  const _Team({
    required this.number,
    required this.inProgress,
    required this.startTime,
    this.finishTime,
    required this.reward,
    required this.members,
  });

  final int number;
  final bool inProgress;
  final String startTime;
  final String? finishTime;

  /// 进行中 = 目标积分；已完成 = 分到的积分
  final int reward;
  final List<_TeamMember> members;
}
