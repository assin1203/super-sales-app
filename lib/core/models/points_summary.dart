/// 积分概览（`GET /user/points`）。
///
/// 后端 `point_flow` / 钱包余额是 BigInt，统一以字符串下发；
/// 钱包未初始化时后端按 0 返回、`updatedAt` 为 null。
class PointsSummary {
  const PointsSummary({
    required this.balance,
    required this.frozen,
    required this.totalEarned,
    required this.totalSpent,
    this.level = 0,
    this.levelName,
    this.updatedAt,
  });

  /// 可用余额
  final String balance;

  /// 冻结中
  final String frozen;

  /// 累计获得
  final String totalEarned;

  /// 累计消耗
  final String totalSpent;

  final int level;
  final String? levelName;
  final DateTime? updatedAt;

  factory PointsSummary.fromJson(Map<String, dynamic> json) => PointsSummary(
        balance: '${json['balance'] ?? '0'}',
        frozen: '${json['frozen'] ?? '0'}',
        totalEarned: '${json['totalEarned'] ?? '0'}',
        totalSpent: '${json['totalSpent'] ?? '0'}',
        level: (json['level'] as num?)?.toInt() ?? 0,
        levelName: json['levelName'] as String?,
        updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}'),
      );

  static const PointsSummary empty = PointsSummary(
    balance: '0',
    frozen: '0',
    totalEarned: '0',
    totalSpent: '0',
  );

  /// 余额转数字（展示用；超出 int 范围时按 int 上限兜底）
  int get balanceValue => int.tryParse(balance) ?? 0;
}
