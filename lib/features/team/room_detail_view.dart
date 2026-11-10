import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/team_room.dart';
import '../../core/theme.dart';

/// 房间详情视图（FR-10.3：1+2+4 布局、权重展示）：
/// 渐变表头（房间号 / 状态 / 轮次 / 等级 / 奖池 / 人数）+ 座位板。
///
/// 房间详情页与「我的团队」页共用同一套渲染，避免两处各写一份座位布局。
class RoomDetailView extends StatelessWidget {
  const RoomDetailView({super.key, required this.room});

  final TeamRoom room;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _roomHeader(room),
        const SizedBox(height: 12),
        _seatBoard(room),
      ],
    );
  }

  Widget _roomHeader(TeamRoom room) {
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
          Row(
            children: [
              Text('房间 ${room.roomNo}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  room.statusName.isEmpty ? '未知状态' : room.statusName,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _headerMetric('第 ${room.round} 轮', '当前轮次'),
              _headerMetric(room.levelLabel, '房间等级'),
              _headerMetric(room.rewardPool, '奖池积分'),
              _headerMetric('${room.memberCount}', '在座人数'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerMetric(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  /// 座位区：红橙渐变底，1+2+4 三排。成员卡展示头像、贡献值角标、
  /// 脱敏手机号与入房时间；空位为白色描边圆形。
  Widget _seatBoard(TeamRoom room) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(6, 18, 6, 18),
      decoration: BoxDecoration(
        gradient: kqwHeaderGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 圆形直径：原 44 放大一倍取 88；4 座一排时按可用宽度收窄，避免窄屏溢出
          final diameter = math.min(88.0, (constraints.maxWidth - 24) / 4);
          return Column(
            children: [
              _seatRow(room, 1, 1, diameter), // 第 1 行：1 人（队长位）
              const SizedBox(height: 16),
              _seatRow(room, 2, 2, diameter), // 第 2 行：2 人
              const SizedBox(height: 16),
              _seatRow(room, 4, 4, diameter), // 第 3 行：4 人
            ],
          );
        },
      ),
    );
  }

  /// 取从 [start] 起的 [count] 个座位（按 seatNo 排序，空位也渲染）
  Widget _seatRow(TeamRoom room, int start, int count, double diameter) {
    final seats = room.positions
        .where((p) => p.seatNo >= start && p.seatNo < start + count)
        .toList()
      ..sort((a, b) => a.seatNo.compareTo(b.seatNo));
    if (seats.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: seats
          .map((seat) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _seatTile(seat, diameter),
                ),
              ))
          .toList(),
    );
  }

  /// 已占座位：头像（自己加粗白边，下缘压贡献值角标）+ 昵称 + 脱敏手机号 + 入房时间
  Widget _seatTile(RoomPosition seat, double diameter) {
    if (!seat.occupied) return _emptySeat(diameter);
    final contribution = int.tryParse(seat.contribution) ?? 0;
    final avatarUrl = (seat.avatar ?? '').trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 头像 + 圆下角角标：角标半压在圆底边上，仍位于昵称之上
        SizedBox(
          height: diameter + 8,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white24,
                  border: Border.all(
                    color: seat.isSelf ? Colors.white : Colors.white70,
                    width: seat.isSelf ? 2 : 1.5,
                  ),
                  image: avatarUrl.isEmpty
                      ? null
                      : DecorationImage(
                          image: NetworkImage(avatarUrl),
                          fit: BoxFit.cover,
                        ),
                ),
                child: avatarUrl.isEmpty
                    ? Icon(Icons.person,
                        color: Colors.white70, size: diameter * 0.5)
                    : null,
              ),
              if (contribution > 0)
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC93C),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      '贡献值$contribution',
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        color: Color(0xFF6B3E00),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                seat.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
            if (seat.isLeader) ...[
              const SizedBox(width: 3),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE0B2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('队长',
                    style: TextStyle(fontSize: 8, color: Color(0xFFB25E00))),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            seat.displayPhone.isEmpty ? '—' : seat.displayPhone,
            maxLines: 1,
            style: const TextStyle(color: Colors.white70, fontSize: 9.5),
          ),
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            seat.joinedAtText.isEmpty ? '入房时间未知' : seat.joinedAtText,
            maxLines: 1,
            style: const TextStyle(color: Colors.white54, fontSize: 8.5),
          ),
        ),
      ],
    );
  }

  /// 空位：白色描边圆形，下方留白与成员信息区等高，保证同排对齐
  Widget _emptySeat(double diameter) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: diameter + 8,
          child: Center(
            child: Container(
              width: diameter,
              height: diameter,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white10,
                border: Border.all(color: Colors.white54, width: 1.5),
              ),
              child: const Text('空位',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ),
          ),
        ),
        const SizedBox(height: 47),
      ],
    );
  }
}
