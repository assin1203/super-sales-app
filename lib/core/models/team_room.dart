/// 团队房间（`/team/rooms`）。
///
/// 房间状态：0 筹备中 / 1 进行中 / 2 已结束；
/// `positions` 空位也会返回，前端按 `seatNo` 定位 1+2+4 布局。

class RoomPosition {
  const RoomPosition({
    required this.seatNo,
    required this.contribution,
    this.userId,
    this.nickname,
    this.avatar,
    this.phone,
    this.joinedAt,
    this.isSelf = false,
    this.isLeader = false,
  });

  final int seatNo;
  final String? userId;
  final String? nickname;
  final String? avatar;

  /// 手机号：后端已按「本人明文、他人脱敏」返回，空位为 null
  final String? phone;

  /// 入房（占位）时间，空位为 null
  final DateTime? joinedAt;

  /// 贡献值（BigInt 字符串）
  final String contribution;
  final bool isSelf;
  final bool isLeader;

  factory RoomPosition.fromJson(Map<String, dynamic> json) => RoomPosition(
        seatNo: (json['seatNo'] as num?)?.toInt() ?? 0,
        userId: json['userId'] as String?,
        nickname: json['nickname'] as String?,
        avatar: json['avatar'] as String?,
        phone: json['phone'] as String?,
        joinedAt: DateTime.tryParse('${json['joinedAt'] ?? ''}')?.toLocal(),
        contribution: '${json['contribution'] ?? '0'}',
        isSelf: json['isSelf'] == true,
        isLeader: json['isLeader'] == true,
      );

  bool get occupied => userId != null;

  String get displayName {
    final n = nickname?.trim();
    return n != null && n.isNotEmpty ? n : '成员';
  }

  /// 展示用手机号：中间 4 位打码（138****8001）。
  /// 后端对他人已脱敏，这里再兜一层，保证本页一律按脱敏样式展示。
  String get displayPhone {
    final p = (phone ?? '').trim();
    if (p.length != 11) return p;
    if (p.contains('*')) return p;
    return '${p.substring(0, 3)}****${p.substring(7)}';
  }

  /// 座位上展示的手机号：本人用后端返回的明文，他人仍按脱敏样式
  String get phoneText => isSelf ? (phone ?? '').trim() : displayPhone;

  /// 入房时间 `2025-12-23 13:39:24`；未知返回空串
  String get joinedAtText {
    final t = joinedAt;
    if (t == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

class TeamRoom {
  const TeamRoom({
    required this.id,
    required this.roomNo,
    required this.status,
    required this.statusName,
    required this.round,
    required this.memberCount,
    required this.rewardPool,
    required this.positions,
    this.level,
    this.leaderNickname,
    this.myPosition,
    this.endedAt,
  });

  final String id;
  final String roomNo;

  /// 0 筹备中 / 1 进行中 / 2 已结束
  final int status;
  final String statusName;

  /// 轮次
  final int round;
  final int? level;
  final String? leaderNickname;
  final int memberCount;

  /// 奖池（BigInt 字符串）
  final String rewardPool;

  /// 本人所在座位号（不在房间内为 null）
  final int? myPosition;

  /// 结束（归档）时间，未结束或后端未下发时为 null。
  ///
  /// 后端库内字段是 `room.last_dividend_at`（归档时写入），C 端接口目前
  /// 不下发；这里兼容 `endedAt` / `lastDividendAt` 两种写法，缺省按 null
  /// 处理，排序回落到 [idValue] 倒序。
  final DateTime? endedAt;

  final List<RoomPosition> positions;

  factory TeamRoom.fromJson(Map<String, dynamic> json) {
    final rawPositions = json['positions'];
    return TeamRoom(
      id: '${json['id'] ?? ''}',
      roomNo: json['roomNo'] as String? ?? '',
      status: (json['status'] as num?)?.toInt() ?? 0,
      statusName: json['statusName'] as String? ?? '',
      round: (json['round'] as num?)?.toInt() ?? 0,
      level: (json['level'] as num?)?.toInt(),
      leaderNickname: json['leaderNickname'] as String?,
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      rewardPool: '${json['rewardPool'] ?? '0'}',
      myPosition: (json['myPosition'] as num?)?.toInt(),
      endedAt: DateTime.tryParse(
        '${json['endedAt'] ?? json['lastDividendAt'] ?? ''}',
      )?.toLocal(),
      positions: rawPositions is List
          ? rawPositions
              .whereType<Map>()
              .map((e) => RoomPosition.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }

  bool get isMember => myPosition != null;

  String get levelLabel => level == null ? '未定级' : 'L$level';

  /// id 数值化：已结束房间按「最近结束在前」近似排序用
  /// （后端归档后 id 不变，但 id 越大创建越晚，可作结束时间的降级序）
  BigInt get idValue => BigInt.tryParse(id) ?? BigInt.zero;

  /// 结束时间 `2026-11-09 20:31`；未下发返回空串
  String get endedAtText {
    final t = endedAt;
    if (t == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }
}

/// 房间成员（GET /team/rooms/{id}/members）
class RoomMember {
  const RoomMember({
    required this.userId,
    required this.phone,
    required this.level,
    required this.seatNo,
    required this.contribution,
    this.nickname,
    this.avatar,
    this.isLeader = false,
    this.joinedAt,
  });

  final String userId;
  final String? nickname;
  final String? avatar;

  /// 脱敏手机号
  final String phone;
  final int level;
  final int seatNo;
  final String contribution;
  final bool isLeader;
  final DateTime? joinedAt;

  factory RoomMember.fromJson(Map<String, dynamic> json) => RoomMember(
        userId: '${json['userId'] ?? ''}',
        nickname: json['nickname'] as String?,
        avatar: json['avatar'] as String?,
        phone: json['phone'] as String? ?? '',
        level: (json['level'] as num?)?.toInt() ?? 0,
        seatNo: (json['seatNo'] as num?)?.toInt() ?? 0,
        contribution: '${json['contribution'] ?? '0'}',
        isLeader: json['isLeader'] == true,
        joinedAt: DateTime.tryParse('${json['joinedAt'] ?? ''}'),
      );

  String get displayName {
    final n = nickname?.trim();
    return n != null && n.isNotEmpty ? n : phone;
  }

  String get levelLabel => 'L$level';
}

/// 候补队列条目（GET /team/wait-queue）
class WaitQueueItem {
  const WaitQueueItem({
    required this.position,
    required this.userId,
    required this.level,
    this.nickname,
    this.avatar,
    this.queuedAt,
    this.estimatedAt,
  });

  final int position;
  final String userId;
  final String? nickname;
  final String? avatar;
  final int level;
  final DateTime? queuedAt;
  final DateTime? estimatedAt;

  factory WaitQueueItem.fromJson(Map<String, dynamic> json) => WaitQueueItem(
        position: (json['position'] as num?)?.toInt() ?? 0,
        userId: '${json['userId'] ?? ''}',
        nickname: json['nickname'] as String?,
        avatar: json['avatar'] as String?,
        level: (json['level'] as num?)?.toInt() ?? 0,
        queuedAt: DateTime.tryParse('${json['queuedAt'] ?? ''}'),
        estimatedAt: DateTime.tryParse('${json['estimatedAt'] ?? ''}'),
      );

  String get displayName {
    final n = nickname?.trim();
    return n != null && n.isNotEmpty ? n : '用户$position';
  }

  String get levelLabel => 'L$level';
}
