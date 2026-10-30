/// POS 机器（`/pos/machines`）。
///
/// 新手任务状态：0 未开始 / 1 进行中 / 2 审核中 / 3 已完成；
/// `progress.amount` 与 `target` 为金额字符串（达标门槛默认 1000 元）。

/// 推荐人（手机号后端脱敏，仅暴露等级）
class MachineReferrer {
  const MachineReferrer({required this.phone, required this.level});

  final String phone;
  final int level;

  factory MachineReferrer.fromJson(Map<String, dynamic> json) =>
      MachineReferrer(
        phone: json['phone'] as String? ?? '',
        level: (json['level'] as num?)?.toInt() ?? 0,
      );

  String get levelLabel => 'L$level';
}

class MachineProgress {
  const MachineProgress({
    required this.amount,
    required this.target,
    required this.daysLeft,
    this.submittedAt,
    this.reviewedAt,
  });

  /// 已累计交易额
  final String amount;

  /// 达标门槛
  final String target;

  /// 剩余天数
  final int daysLeft;

  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  factory MachineProgress.fromJson(Map<String, dynamic> json) =>
      MachineProgress(
        amount: '${json['amount'] ?? '0'}',
        target: '${json['target'] ?? '0'}',
        daysLeft: (json['daysLeft'] as num?)?.toInt() ?? 0,
        submittedAt: DateTime.tryParse('${json['submittedAt'] ?? ''}'),
        reviewedAt: DateTime.tryParse('${json['reviewedAt'] ?? ''}'),
      );

  double get ratio {
    final t = double.tryParse(target) ?? 0;
    final a = double.tryParse(amount) ?? 0;
    if (t <= 0) return 0;
    return (a / t).clamp(0.0, 1.0);
  }
}

class Machine {
  const Machine({
    required this.sn,
    required this.model,
    required this.newbieStatus,
    required this.newbieStatusName,
    required this.progress,
    this.bootedAt,
    this.referredBy,
  });

  final String sn;
  final String model;
  final DateTime? bootedAt;
  final MachineReferrer? referredBy;

  /// 0 未开始 / 1 进行中 / 2 审核中 / 3 已完成
  final int newbieStatus;
  final String newbieStatusName;
  final MachineProgress progress;

  factory Machine.fromJson(Map<String, dynamic> json) {
    final rawProgress = json['progress'];
    final rawReferrer = json['referredBy'];
    return Machine(
      sn: json['sn'] as String? ?? '',
      model: json['model'] as String? ?? '',
      bootedAt: DateTime.tryParse('${json['bootedAt'] ?? ''}'),
      referredBy: rawReferrer is Map
          ? MachineReferrer.fromJson(rawReferrer.cast<String, dynamic>())
          : null,
      newbieStatus: (json['newbieStatus'] as num?)?.toInt() ?? 0,
      newbieStatusName: json['newbieStatusName'] as String? ?? '',
      progress: rawProgress is Map
          ? MachineProgress.fromJson(rawProgress.cast<String, dynamic>())
          : const MachineProgress(amount: '0', target: '0', daysLeft: 0),
    );
  }

  bool get finished => newbieStatus == 3;
}

/// 机器时间线条目
class MachineTimelineItem {
  const MachineTimelineItem({required this.event, this.at});

  final DateTime? at;
  final String event;

  factory MachineTimelineItem.fromJson(Map<String, dynamic> json) =>
      MachineTimelineItem(
        at: DateTime.tryParse('${json['at'] ?? ''}'),
        event: json['event'] as String? ?? '',
      );
}

/// 机器详情（GET /pos/machines/{sn}）
class MachineDetail extends Machine {
  const MachineDetail({
    required super.sn,
    required super.model,
    required super.newbieStatus,
    required super.newbieStatusName,
    required super.progress,
    super.bootedAt,
    super.referredBy,
    this.qualifiedAt,
    this.rewardPoints = '0',
    this.rewardStatus = 0,
    this.timeline = const [],
  });

  final DateTime? qualifiedAt;
  final String rewardPoints;

  /// 奖励状态：后端原始码，0 未发 / 1 已发
  final int rewardStatus;
  final List<MachineTimelineItem> timeline;

  factory MachineDetail.fromJson(Map<String, dynamic> json) {
    final base = Machine.fromJson(json);
    final rawTimeline = json['timeline'];
    return MachineDetail(
      sn: base.sn,
      model: base.model,
      bootedAt: base.bootedAt,
      referredBy: base.referredBy,
      newbieStatus: base.newbieStatus,
      newbieStatusName: base.newbieStatusName,
      progress: base.progress,
      qualifiedAt: DateTime.tryParse('${json['qualifiedAt'] ?? ''}'),
      rewardPoints: '${json['rewardPoints'] ?? '0'}',
      rewardStatus: (json['rewardStatus'] as num?)?.toInt() ?? 0,
      timeline: rawTimeline is List
          ? rawTimeline
              .whereType<Map>()
              .map((e) =>
                  MachineTimelineItem.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }
}

/// 装机申请结果（POST /pos/apply）
class MachineApplyResult {
  const MachineApplyResult({
    required this.applyId,
    required this.status,
    required this.statusName,
    this.submittedAt,
  });

  final String applyId;
  final int status;
  final String statusName;
  final DateTime? submittedAt;

  factory MachineApplyResult.fromJson(Map<String, dynamic> json) =>
      MachineApplyResult(
        applyId: '${json['applyId'] ?? ''}',
        status: (json['status'] as num?)?.toInt() ?? 0,
        statusName: json['statusName'] as String? ?? '',
        submittedAt: DateTime.tryParse('${json['submittedAt'] ?? ''}'),
      );
}

/// 品牌下拉项（GET /pos/brands，后台可配，仅下发启用项）
class PosBrandOption {
  const PosBrandOption({required this.id, required this.name, this.logo = ''});

  final String id;
  final String name;
  final String logo;

  factory PosBrandOption.fromJson(Map<String, dynamic> json) => PosBrandOption(
        id: '${json['id'] ?? ''}',
        name: json['name'] as String? ?? '',
        logo: json['logo'] as String? ?? '',
      );
}

/// 类型下拉项（GET /pos/types）
class PosTypeOption {
  const PosTypeOption({required this.id, required this.name});

  final String id;
  final String name;

  factory PosTypeOption.fromJson(Map<String, dynamic> json) => PosTypeOption(
        id: '${json['id'] ?? ''}',
        name: json['name'] as String? ?? '',
      );
}

/// 新增机器结果（POST /pos/machines）
///
/// [customerUserId] 为 null 表示机号没查到归属用户，后端按"空着"处理。
class MachineAddResult {
  const MachineAddResult({
    required this.applyId,
    required this.machineNo,
    required this.status,
    required this.statusName,
    this.customerUserId,
    this.submittedAt,
  });

  final String applyId;
  final String machineNo;
  final String? customerUserId;
  final int status;
  final String statusName;
  final DateTime? submittedAt;

  factory MachineAddResult.fromJson(Map<String, dynamic> json) {
    final raw = json['customerUserId'];
    return MachineAddResult(
      applyId: '${json['applyId'] ?? ''}',
      machineNo: json['machineNo'] as String? ?? '',
      customerUserId: raw == null ? null : '$raw',
      status: (json['status'] as num?)?.toInt() ?? 0,
      statusName: json['statusName'] as String? ?? '',
      submittedAt: DateTime.tryParse('${json['submittedAt'] ?? ''}'),
    );
  }

  /// 是否已绑定到已有客户
  bool get bound => customerUserId != null;
}
