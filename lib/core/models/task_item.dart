/// C 端任务中心（`/tasks`）。
///
/// `category`：1 新手任务 / 2 日常任务；`period`：DAY / WEEK / MONTH / ONCE；
/// `status`：0 未完成 / 1 可领取 / 2 已领取；进度与奖励点数均为字符串。

class TaskProgress {
  const TaskProgress({required this.current, required this.target});

  final String current;
  final String target;

  factory TaskProgress.fromJson(Map<String, dynamic> json) => TaskProgress(
        current: '${json['current'] ?? '0'}',
        target: '${json['target'] ?? '0'}',
      );

  double get ratio {
    final t = int.tryParse(target) ?? 0;
    final c = int.tryParse(current) ?? 0;
    if (t <= 0) return 0;
    return (c / t).clamp(0.0, 1.0);
  }
}

class TaskItem {
  const TaskItem({
    required this.code,
    required this.name,
    required this.category,
    required this.categoryName,
    required this.period,
    required this.rewardPoints,
    required this.progress,
    required this.status,
    required this.statusName,
    this.description = '',
    this.claimedAt,
    this.expireAt,
  });

  final String code;
  final String name;

  /// 1 新手 / 2 日常
  final int category;
  final String categoryName;

  /// DAY / WEEK / MONTH / ONCE
  final String period;
  final String description;

  /// 奖励积分（BigInt 字符串）
  final String rewardPoints;
  final TaskProgress progress;

  /// 0 未完成 / 1 可领取 / 2 已领取
  final int status;
  final String statusName;
  final DateTime? claimedAt;
  final DateTime? expireAt;

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final rawProgress = json['progress'];
    return TaskItem(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: (json['category'] as num?)?.toInt() ?? 2,
      categoryName: json['categoryName'] as String? ?? '',
      period: json['period'] as String? ?? 'ONCE',
      description: json['description'] as String? ?? '',
      rewardPoints: '${json['rewardPoints'] ?? '0'}',
      progress: rawProgress is Map
          ? TaskProgress.fromJson(rawProgress.cast<String, dynamic>())
          : const TaskProgress(current: '0', target: '0'),
      status: (json['status'] as num?)?.toInt() ?? 0,
      statusName: json['statusName'] as String? ?? '',
      claimedAt: DateTime.tryParse('${json['claimedAt'] ?? ''}'),
      expireAt: DateTime.tryParse('${json['expireAt'] ?? ''}'),
    );
  }

  bool get claimable => status == 1;
  bool get claimed => status == 2;
  bool get isNewbie => category == 1;

  String get periodLabel => switch (period) {
        'DAY' => '每日',
        'WEEK' => '每周',
        'MONTH' => '每月',
        _ => '一次性',
      };
}

/// 任务完成记录
class TaskRecord {
  const TaskRecord({required this.event, this.at});

  final DateTime? at;
  final String event;

  factory TaskRecord.fromJson(Map<String, dynamic> json) => TaskRecord(
        at: DateTime.tryParse('${json['at'] ?? ''}'),
        event: json['event'] as String? ?? '',
      );
}

/// 任务详情（GET /tasks/{code}）：列表结构 + 规则文案 + 最近完成记录
class TaskDetail extends TaskItem {
  const TaskDetail({
    required super.code,
    required super.name,
    required super.category,
    required super.categoryName,
    required super.period,
    required super.rewardPoints,
    required super.progress,
    required super.status,
    required super.statusName,
    super.description,
    super.claimedAt,
    super.expireAt,
    this.rule = '',
    this.records = const [],
  });

  final String rule;
  final List<TaskRecord> records;

  factory TaskDetail.fromJson(Map<String, dynamic> json) {
    final base = TaskItem.fromJson(json);
    final rawRecords = json['records'];
    return TaskDetail(
      code: base.code,
      name: base.name,
      category: base.category,
      categoryName: base.categoryName,
      period: base.period,
      description: base.description,
      rewardPoints: base.rewardPoints,
      progress: base.progress,
      status: base.status,
      statusName: base.statusName,
      claimedAt: base.claimedAt,
      expireAt: base.expireAt,
      rule: json['rule'] as String? ?? '',
      records: rawRecords is List
          ? rawRecords
              .whereType<Map>()
              .map((e) => TaskRecord.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }
}

/// 领取结果（POST /tasks/{code}/claim）
class TaskClaimResult {
  const TaskClaimResult({
    required this.code,
    required this.rewardPoints,
    required this.pointsBalance,
    this.claimedAt,
  });

  final String code;
  final String rewardPoints;

  /// 领取后余额
  final String pointsBalance;
  final DateTime? claimedAt;

  factory TaskClaimResult.fromJson(Map<String, dynamic> json) =>
      TaskClaimResult(
        code: json['code'] as String? ?? '',
        rewardPoints: '${json['rewardPoints'] ?? '0'}',
        pointsBalance: '${json['pointsBalance'] ?? '0'}',
        claimedAt: DateTime.tryParse('${json['claimedAt'] ?? ''}'),
      );
}
