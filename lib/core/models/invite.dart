/// 推广中心（`GET /user/invite` 与 `GET /user/invite/records`）。

/// 邀请统计（GET /user/invite）
class InviteSummary {
  const InviteSummary({
    required this.inviteCode,
    required this.inviteUrl,
    required this.invitedCount,
    required this.qualifiedCount,
    required this.levelCounts,
    required this.totalReward,
    required this.monthReward,
  });

  final String inviteCode;
  final String inviteUrl;

  /// 直接下级人数
  final int invitedCount;

  /// 已达标下级数
  final int qualifiedCount;

  /// 各级人数分布：{'L1': n, 'L2': n, 'L3': n}
  final Map<String, int> levelCounts;

  /// 累计推荐奖励积分
  final String totalReward;

  /// 本月推荐奖励积分
  final String monthReward;

  factory InviteSummary.fromJson(Map<String, dynamic> json) {
    final rawCounts = json['levelCounts'];
    final counts = <String, int>{'L1': 0, 'L2': 0, 'L3': 0};
    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        final key = '${entry.key}';
        final value = (entry.value as num?)?.toInt() ?? 0;
        counts[key] = value;
      }
    }
    return InviteSummary(
      inviteCode: json['inviteCode'] as String? ?? '',
      inviteUrl: json['inviteUrl'] as String? ?? '',
      invitedCount: (json['invitedCount'] as num?)?.toInt() ?? 0,
      qualifiedCount: (json['qualifiedCount'] as num?)?.toInt() ?? 0,
      levelCounts: counts,
      totalReward: '${json['totalReward'] ?? '0'}',
      monthReward: '${json['monthReward'] ?? '0'}',
    );
  }

  static const InviteSummary empty = InviteSummary(
    inviteCode: '',
    inviteUrl: '',
    invitedCount: 0,
    qualifiedCount: 0,
    levelCounts: {'L1': 0, 'L2': 0, 'L3': 0},
    totalReward: '0',
    monthReward: '0',
  );

  int levelCount(int level) => levelCounts['L$level'] ?? 0;

  /// 达标率（0~1）
  double get qualifiedRatio =>
      invitedCount <= 0 ? 0 : qualifiedCount / invitedCount;
}

/// 邀请记录条目（GET /user/invite/records 的 items）
class InviteRecord {
  const InviteRecord({
    required this.userId,
    required this.nickname,
    required this.phone,
    required this.level,
    required this.qualified,
    required this.rewardPoints,
    this.registeredAt,
  });

  final String userId;
  final String nickname;

  /// 后端已脱敏
  final String phone;
  final int level;
  final DateTime? registeredAt;
  final bool qualified;

  /// 该下级带来的奖励积分
  final String rewardPoints;

  factory InviteRecord.fromJson(Map<String, dynamic> json) => InviteRecord(
        userId: '${json['userId'] ?? ''}',
        nickname: json['nickname'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        level: (json['level'] as num?)?.toInt() ?? 0,
        registeredAt: DateTime.tryParse('${json['registeredAt'] ?? ''}'),
        qualified: json['qualified'] == true,
        rewardPoints: '${json['rewardPoints'] ?? '0'}',
      );

  String get displayName {
    final n = nickname.trim();
    return n.isNotEmpty ? n : phone;
  }

  String get levelLabel => 'L$level';
  String get statusLabel => qualified ? '已达标' : '未达标';
}
