/// 升级提示（`GET /team/upgrade-prompt`）。
///
/// 后端只在「有待定冻结奖励 + 积分够进下一档房间 + 还不是 L2」时返回数据，
/// 其余情况返回空体（App 侧解析成 null，不弹窗）。
///
/// 冻结奖励来源：装机奖励积分在装机时冻结，达标结算后进入 30 天窗口 ——
/// 弹窗让用户当场二选一：升级进房（解冻给自己）或放弃（立刻转给推荐人）。
class UpgradePrompt {
  const UpgradePrompt({
    this.level = 0,
    this.targetLevel = 1,
    this.packageId = '',
    this.packageCode = '',
    this.packageName = '',
    this.entryPoints = 0,
    this.balance = 0,
    this.pendingRewardPoints = 0,
    this.pendingMachines = 0,
    this.canUpgrade = false,
    this.shortfall = 0,
  });

  /// 当前会员等级（0 / 1；L2 不会返回提示）
  final int level;

  /// 本次升级能到达的房间等级（1 = 200 档 / 2 = 600 档）
  final int targetLevel;

  /// 目标档位 id（进房时原样回传）
  final String packageId;
  final String packageCode;

  /// 目标档位名称（如「200 档」）
  final String packageName;

  /// 本次进房要扣的积分；已买过该档位礼包时为 0
  final int entryPoints;

  /// 当前可用积分
  final int balance;

  /// 待定冻结奖励合计积分（升级 / 放弃两种选择都针对它）
  final int pendingRewardPoints;

  /// 待定冻结奖励的机器台数
  final int pendingMachines;

  /// 可用积分是否够本次升级（够了才弹）
  final bool canUpgrade;

  /// 不够时还差多少积分
  final int shortfall;

  /// 升级后达到的等级文案
  String get targetLevelName => targetLevel >= 2 ? 'L2' : 'L1';

  /// 本次是否要扣积分进房（已购该档礼包时是 0）
  bool get freeEntry => entryPoints <= 0;

  factory UpgradePrompt.fromJson(Map<String, dynamic> json) => UpgradePrompt(
        level: (json['level'] as num?)?.toInt() ?? 0,
        targetLevel: (json['targetLevel'] as num?)?.toInt() ?? 1,
        packageId: '${json['packageId'] ?? ''}',
        packageCode: json['packageCode'] as String? ?? '',
        packageName: json['packageName'] as String? ?? '',
        entryPoints: (json['entryPoints'] as num?)?.toInt() ?? 0,
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        pendingRewardPoints: (json['pendingRewardPoints'] as num?)?.toInt() ?? 0,
        pendingMachines: (json['pendingMachines'] as num?)?.toInt() ?? 0,
        canUpgrade: json['canUpgrade'] as bool? ?? false,
        shortfall: (json['shortfall'] as num?)?.toInt() ?? 0,
      );
}

/// 升级二选一的结果（`POST /team/upgrade-prompt/choice`）。
class UpgradeChoiceResult {
  const UpgradeChoiceResult({
    this.choice = 'decline',
    this.unfrozenRewards = 0,
    this.toReferrer = 0,
    this.toSelf = 0,
    this.message = '',
  });

  /// upgrade = 已进房升级；decline = 已放弃升级
  final String choice;

  /// upgrade：本次解冻给本人的机台数
  final int unfrozenRewards;

  /// decline：已转给直接推荐人的台数
  final int toReferrer;

  /// decline：无推荐人时兜底解冻给本人的台数
  final int toSelf;

  /// 后端给的一句话结论，直接展示
  final String message;

  bool get upgraded => choice == 'upgrade';

  factory UpgradeChoiceResult.fromJson(Map<String, dynamic> json) => UpgradeChoiceResult(
        choice: json['choice'] as String? ?? 'decline',
        unfrozenRewards: (json['unfrozenRewards'] as num?)?.toInt() ?? 0,
        toReferrer: (json['toReferrer'] as num?)?.toInt() ?? 0,
        toSelf: (json['toSelf'] as num?)?.toInt() ?? 0,
        message: json['message'] as String? ?? '',
      );
}
