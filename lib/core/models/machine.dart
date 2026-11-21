/// POS 机器（`/pos/machines`）。
///
/// 新手任务状态：0 未开始 / 1 进行中 / 2 审核中 / 3 已完成；
/// `progress.amount` 与 `target` 为金额字符串（达标门槛默认 1000 元）。

import 'page_result.dart';

/// 后端对申请单联系电话统一脱敏（`139****7777`）。脱敏值正好匹配本机登录号码时
/// 用完整号码补全，让本人能看到自己的号；不匹配（别人的号）则原样返回。
String revealOwnPhone(String masked, String? selfPhone) {
  if (!masked.contains('*') || selfPhone == null || selfPhone.length < 7) {
    return masked;
  }
  final parts = masked.split('*');
  final head = parts.first;
  final tail = parts.last;
  if (head.isNotEmpty && selfPhone.startsWith(head) && selfPhone.endsWith(tail)) {
    return selfPhone;
  }
  return masked;
}

/// 流水是否达到门槛。
///
/// `target <= 0`（后端未下发门槛 / 历史机器未挂任务窗口）统一视为**未达标**，
/// 与 [MachineProgress.ratio] 同一口径——否则 `0 >= 0` 会把流水为 0 的机器判成达标。
bool ratioReached(String amount, String target) {
  final a = double.tryParse(amount) ?? 0;
  final t = double.tryParse(target) ?? 0;
  if (t <= 0) return false;
  return a >= t;
}

/// 截止时间 → 剩余天数：向上取整（不足 1 天按 1 天），已过期归 0。
///
/// [Machine.daysLeftToReach] 与 `NewbieConfirmPending.daysLeftLive` 共用这一份取整规则，
/// 避免首页卡片与确认弹窗对同一台机器给出不同的天数。
int reachDaysLeft(DateTime due, {DateTime? now}) {
  final remain = due.difference(now ?? DateTime.now());
  if (remain.isNegative) return 0;
  return (remain.inSeconds / Duration.secondsPerDay).ceil();
}

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
    this.expired = false,
    this.submittedAt,
    this.reviewedAt,
  });

  /// 已累计交易额
  final String amount;

  /// 达标门槛
  final String target;

  /// 剩余天数
  final int daysLeft;

  /// 任务窗口是否已过期（后端判定；未挂任务窗口的历史机器恒为 false）
  final bool expired;

  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  factory MachineProgress.fromJson(Map<String, dynamic> json) =>
      MachineProgress(
        amount: '${json['amount'] ?? '0'}',
        target: '${json['target'] ?? '0'}',
        daysLeft: (json['daysLeft'] as num?)?.toInt() ?? 0,
        expired: json['expired'] == true,
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
    this.newbieRejectReason,
    this.merchantName,
    this.installedAt,
    this.dueAt,
    this.windowDays = 0,
    this.taskSelfPoints = '0',
  });

  final String sn;
  final String model;
  final DateTime? bootedAt;
  final MachineReferrer? referredBy;

  /// 0 未开始 / 1 进行中 / 2 审核中 / 3 已完成
  final int newbieStatus;
  final String newbieStatusName;
  final MachineProgress progress;

  /// 新手任务最近一次驳回原因（仅驳回后、重新提交前有值）
  final String? newbieRejectReason;

  /// 门店名称：申请单 merchant_name 快照（自装机或未填写为 null）
  final String? merchantName;

  /// 装机时间：达标窗口起点（历史脏数据可能为空）
  final DateTime? installedAt;

  /// 达标截止时间：剩余天数以它为准实时重算
  final DateTime? dueAt;

  /// 任务窗口天数快照（0 表示历史机器未挂任务窗口）
  final int windowDays;

  /// 达标可得积分快照（字符串，避免前端浮点误差）
  final String taskSelfPoints;

  factory Machine.fromJson(Map<String, dynamic> json) {
    final rawProgress = json['progress'];
    final rawReferrer = json['referredBy'];
    final rawReason = (json['newbieRejectReason'] as String?)?.trim() ?? '';
    final rawMerchant = (json['merchantName'] as String?)?.trim() ?? '';
    return Machine(
      sn: json['sn'] as String? ?? '',
      model: json['model'] as String? ?? '',
      bootedAt: DateTime.tryParse('${json['bootedAt'] ?? ''}'),
      referredBy: rawReferrer is Map
          ? MachineReferrer.fromJson(rawReferrer.cast<String, dynamic>())
          : null,
      newbieStatus: (json['newbieStatus'] as num?)?.toInt() ?? 0,
      newbieStatusName: json['newbieStatusName'] as String? ?? '',
      newbieRejectReason: rawReason.isEmpty ? null : rawReason,
      merchantName: rawMerchant.isEmpty ? null : rawMerchant,
      installedAt: DateTime.tryParse('${json['installedAt'] ?? ''}'),
      dueAt: DateTime.tryParse('${json['dueAt'] ?? ''}'),
      windowDays: (json['windowDays'] as num?)?.toInt() ?? 0,
      taskSelfPoints: '${json['taskSelfPoints'] ?? '0'}',
      progress: rawProgress is Map
          ? MachineProgress.fromJson(rawProgress.cast<String, dynamic>())
          : const MachineProgress(amount: '0', target: '0', daysLeft: 0),
    );
  }

  /// 提交达标后本地更新状态，避免整页重拉
  Machine copyWith({
    int? newbieStatus,
    String? newbieStatusName,
    bool clearRejectReason = false,
  }) =>
      Machine(
        sn: sn,
        model: model,
        bootedAt: bootedAt,
        referredBy: referredBy,
        newbieStatus: newbieStatus ?? this.newbieStatus,
        newbieStatusName: newbieStatusName ?? this.newbieStatusName,
        newbieRejectReason: clearRejectReason ? null : newbieRejectReason,
        merchantName: merchantName,
        installedAt: installedAt,
        dueAt: dueAt,
        windowDays: windowDays,
        taskSelfPoints: taskSelfPoints,
        progress: progress,
      );

  bool get finished => newbieStatus == 3;

  /// 是否已刷满达标金额（审核中的机器也可能已达标，这里只看金额）
  bool get reachedTarget => ratioReached(progress.amount, progress.target);

  /// 是否有有效的达标门槛：`target <= 0` 表示没挂任务窗口（历史机器）
  bool get hasTarget => (double.tryParse(progress.target) ?? 0) > 0;

  /// 首页「机器达标监控」是否收录：未达标、窗口未过期，且确实有任务门槛。
  ///
  /// 除「已达标」「窗口已过期」外还要排掉已完成（人工结算过）与没有门槛的历史机器，
  /// 否则它们会永久占一张「0天 / 累计0元」的告警卡。
  bool get needsMonitor =>
      !finished && hasTarget && !reachedTarget && !progress.expired;

  /// 剩余达标天数：每次打开按当前时间重算，不用接口下发时的快照值
  ///
  /// 优先用截止时间（装机时按任务窗口算好落库的那份），其次按装机日 + 窗口天数推算，
  /// 两者都缺（历史机器未挂窗口）才退回接口下发的 daysLeft。
  int get daysLeftToReach {
    final due = _dueTime;
    if (due == null) return progress.daysLeft;
    return reachDaysLeft(due);
  }

  DateTime? get _dueTime {
    final due = dueAt;
    if (due != null) return due;
    final start = installedAt ?? bootedAt;
    if (start != null && windowDays > 0) {
      return start.add(Duration(days: windowDays));
    }
    return null;
  }
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
    super.newbieRejectReason,
    super.merchantName,
    super.installedAt,
    super.dueAt,
    super.windowDays,
    super.taskSelfPoints,
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
      newbieRejectReason: base.newbieRejectReason,
      merchantName: base.merchantName,
      installedAt: base.installedAt,
      dueAt: base.dueAt,
      windowDays: base.windowDays,
      taskSelfPoints: base.taskSelfPoints,
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

/// 使用人手机号验证结果（POST /pos/apply/verify-phone）
///
/// [registered] 为 true 表示该号码此前没注册，服务端已自动建号并把推广人绑到当前登录用户。
class ApplyPhoneVerifyResult {
  const ApplyPhoneVerifyResult({
    required this.verified,
    required this.registered,
    required this.phone,
    this.userId = '',
  });

  final bool verified;

  /// true = 号码未注册，本次已自动建号（推广人 = 当前用户）
  final bool registered;
  final String phone;
  final String userId;

  factory ApplyPhoneVerifyResult.fromJson(Map<String, dynamic> json) =>
      ApplyPhoneVerifyResult(
        verified: json['verified'] == true,
        registered: json['registered'] == true,
        phone: json['phone'] as String? ?? '',
        userId: '${json['userId'] ?? ''}',
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

/// 所属平台下拉项（GET /pos/platforms）
///
/// 与品牌/类型同构：只有 id + name。提交申请时传 id，后端按字典项校验后
/// 把名称写进申请单（`pos_apply.platform` 是文本快照列，无外键）。
class PosPlatformOption {
  const PosPlatformOption({required this.id, required this.name});

  final String id;
  final String name;

  factory PosPlatformOption.fromJson(Map<String, dynamic> json) =>
      PosPlatformOption(
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

/// 新手任务达标提交结果（`POST /pos/newbie/submit`）。
///
/// 提交成功后后端即置「审核中」（[newbieStatus] 为 2），等人工审核发放奖励。
class NewbieSubmitResult {
  const NewbieSubmitResult({
    required this.sn,
    required this.newbieStatus,
    required this.newbieStatusName,
    this.submittedAt,
  });

  final String sn;
  final int newbieStatus;
  final String newbieStatusName;
  final DateTime? submittedAt;

  factory NewbieSubmitResult.fromJson(Map<String, dynamic> json) =>
      NewbieSubmitResult(
        sn: json['sn'] as String? ?? '',
        newbieStatus: (json['newbieStatus'] as num?)?.toInt() ?? 2,
        newbieStatusName: json['newbieStatusName'] as String? ?? '审核中',
        submittedAt: DateTime.tryParse('${json['submittedAt'] ?? ''}'),
      );
}

/// 新手达标待确认机器（`GET /pos/newbie/confirmations`）。
///
/// 归属用户与装机人各自登录都会拿到同一台机器；[counterpartConfirmed] 表示对方是否已确认。
/// 自己确认过的机器不再返回，所以这个列表非空就代表「有我还没确认的机器」。
class NewbieConfirmPending {
  const NewbieConfirmPending({
    required this.sn,
    required this.model,
    this.merchantName,
    this.amount = '0',
    this.target = '0',
    this.dueAt,
    this.daysLeft,
    this.role = 'owner',
    this.counterpartConfirmed = false,
    this.submittedAt,
  });

  final String sn;
  final String model;

  /// 门店名称快照（自装机无申请单时为 null）
  final String? merchantName;

  /// 累计流水 / 达标门槛（后端字符串化，避免浮点误差）
  final String amount;
  final String target;

  /// 达标截止时间：优先用它减去当前时间算剩余天数
  final DateTime? dueAt;

  /// 接口下发的剩余天数快照（仅 [dueAt] 缺失时兜底）
  final int? daysLeft;

  /// 本条记录里当前用户的身份：owner 归属用户 / installer 装机人
  final String role;

  /// 对方是否已确认（无需装机人确认时恒为 true）
  final bool counterpartConfirmed;

  final DateTime? submittedAt;

  /// 卡片标题用的门店名：缺失时退回机器型号
  String get storeLabel {
    final name = merchantName?.trim() ?? '';
    return name.isEmpty ? model : name;
  }

  /// 剩余天数：按 [dueAt] 与当前时间实时重算（接口下发的是响应时刻快照）
  int? get daysLeftLive {
    final due = dueAt;
    if (due == null) return daysLeft;
    return reachDaysLeft(due);
  }

  /// 流水是否已达门槛（只用于文案提示，是否通过始终由后端判定）
  bool get reachedTarget => ratioReached(amount, target);

  factory NewbieConfirmPending.fromJson(Map<String, dynamic> json) =>
      NewbieConfirmPending(
        sn: json['sn'] as String? ?? '',
        model: json['model'] as String? ?? '',
        merchantName: json['merchantName'] as String?,
        amount: '${json['amount'] ?? '0'}',
        target: '${json['target'] ?? '0'}',
        dueAt: DateTime.tryParse('${json['dueAt'] ?? ''}'),
        daysLeft: (json['daysLeft'] as num?)?.toInt(),
        role: json['role'] as String? ?? 'owner',
        counterpartConfirmed: json['counterpartConfirmed'] as bool? ?? false,
        submittedAt: DateTime.tryParse('${json['submittedAt'] ?? ''}'),
      );
}

/// 单台机器的确认结果（`POST /pos/newbie/confirm` 逐台返回）。
class NewbieConfirmResult {
  const NewbieConfirmResult({
    required this.sn,
    this.confirmed = false,
    this.settled = false,
    this.reason,
    this.message = '',
  });

  final String sn;

  /// 本次是否已记录确认（重复提交/此前已确认过也为 true）
  final bool confirmed;

  /// 是否因双方齐全而自动达标
  final bool settled;

  /// 未记录/未通过原因：not_found / qualified / not_submitted / forbidden / not_reached 等
  final String? reason;

  /// 后端给的可直接展示文案（流水不足等口径都在这里）
  final String message;

  factory NewbieConfirmResult.fromJson(Map<String, dynamic> json) =>
      NewbieConfirmResult(
        sn: json['sn'] as String? ?? '',
        confirmed: json['confirmed'] as bool? ?? false,
        settled: json['settled'] as bool? ?? false,
        reason: json['reason'] as String?,
        message: json['message'] as String? ?? '',
      );
}

/// 多选确认出参（逐台结果 + 汇总提示）。
class NewbieConfirmResponse {
  const NewbieConfirmResponse({
    this.items = const [],
    this.settled = 0,
    this.message = '',
  });

  final List<NewbieConfirmResult> items;

  /// 本次确认后自动达标的台数
  final int settled;
  final String message;

  factory NewbieConfirmResponse.fromJson(Map<String, dynamic> json) =>
      NewbieConfirmResponse(
        items: (json['items'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(NewbieConfirmResult.fromJson)
            .toList(),
        settled: (json['settled'] as num?)?.toInt() ?? 0,
        message: json['message'] as String? ?? '',
      );
}

/// 我的装机申请（`GET /pos/applies`）。
///
/// 申请单视角：联系人 [contactName]、联系电话 [customerPhone]（后端已脱敏）、
/// 商户名称 [merchantName]、使用人 [useType]；
/// 同时兼容机器视角字段（[machineNo] / [brandName] / [typeName]）。
/// 审核通过（[approved]）后走 `POST /pos/applies/{id}/install` 装机。
class MachineApply {
  const MachineApply({
    required this.applyId,
    required this.machineNo,
    required this.customerPhone,
    required this.status,
    required this.statusName,
    this.contactName,
    this.merchantName,
    this.useType = 1,
    this.brandId,
    this.typeId,
    this.region,
    this.address,
    this.remark,
    this.trafficFeeRemark,
    this.bootTime,
    this.brandName,
    this.typeName,
    this.customerUserId,
    this.submittedAt,
  });

  final String applyId;
  final String machineNo;

  /// 申请联系电话（后端已脱敏）
  final String customerPhone;

  /// 联系人
  final String? contactName;

  /// 商户名称
  final String? merchantName;

  /// 使用人：1 自己使用 / 2 他人使用
  final int useType;

  /// 品牌 / 类型 ID：申请时没填的，装机接口允许补齐
  final String? brandId;
  final String? typeId;

  /// 申请时填写的门店信息，装机时若为空可补录
  final String? region;
  final String? address;
  final String? remark;
  final String? trafficFeeRemark;

  /// 开机时间（申请已填则装机可省略）
  final DateTime? bootTime;

  /// 0 待处理 / 1 已通过 / 2 已拒绝
  final int status;
  final String statusName;
  final String? brandName;
  final String? typeName;
  final String? customerUserId;
  final DateTime? submittedAt;

  /// 审核通过，可以装机
  bool get approved => status == 1;

  /// 使用人文案（1 自己使用 / 2 他人使用）
  String get useTypeName => useType == 2 ? '他人使用' : '自己使用';

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = '$value';
    return text.isEmpty ? null : text;
  }

  factory MachineApply.fromJson(Map<String, dynamic> json) {
    final rawCustomer = json['customerUserId'];
    return MachineApply(
      applyId: _text(json['applyId']) ?? _text(json['id']) ?? '',
      machineNo: _text(json['machineNo']) ?? '',
      // 申请单视角用 phone，机器视角用 customerPhone
      customerPhone: _text(json['customerPhone']) ?? _text(json['phone']) ?? '',
      contactName: _text(json['contactName']),
      merchantName: _text(json['merchantName']),
      useType: (json['useType'] as num?)?.toInt() ?? 1,
      brandId: _text(json['brandId']),
      typeId: _text(json['typeId']),
      region: _text(json['region']),
      address: _text(json['address']),
      remark: _text(json['remark']),
      trafficFeeRemark: _text(json['trafficFeeRemark']),
      bootTime: DateTime.tryParse('${json['bootTime'] ?? ''}'),
      status: (json['status'] as num?)?.toInt() ?? 0,
      statusName: json['statusName'] as String? ?? '',
      brandName: _text(json['brandName']),
      typeName: _text(json['typeName']),
      customerUserId: _text(rawCustomer),
      submittedAt: DateTime.tryParse(
          '${json['submittedAt'] ?? json['createdAt'] ?? ''}'),
    );
  }
}

/// 我的机器列表：已装机机器分页 + 申请中的新增机器。
///
/// 后端按 pos_task 的 sn 去重，同一台机器不会同时出现在两个列表里。
class MachineList {
  const MachineList({required this.page, this.applies = const []});

  final PageResult<Machine> page;
  final List<MachineApply> applies;

  List<Machine> get items => page.items;
  int get total => page.total;

  factory MachineList.fromJson(Map<String, dynamic> json) {
    final rawApplies = json['applies'];
    return MachineList(
      page: PageResult.fromJson(json, Machine.fromJson),
      applies: rawApplies is List
          ? rawApplies
              .whereType<Map>()
              .map((e) => MachineApply.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }
}

/// 待装机器的一条申请（`GET /pos/applies/pending-by-phone` 的 items）。
///
/// 与 [MachineApply] 不同：这里只出 status=0 待处理记录，字段是装机现场要核对的
/// 一份快照（含单号、来源、机器号），装机时用它填表并对齐到 applyId 精确绑定。
class PendingInstallApply {
  const PendingInstallApply({
    required this.applyId,
    required this.requestNo,
    required this.phone,
    required this.source,
    required this.sourceName,
    required this.useType,
    required this.useTypeName,
    required this.submittedAt,
    this.contactName,
    this.merchantName,
    this.region,
    this.address,
    this.remark,
    this.trafficFeeRemark,
    this.bootTime,
    this.brandName,
    this.typeName,
    this.machineNo,
  });

  final String applyId;

  /// 申请单号（业务员可报给客户核对）
  final String requestNo;

  /// 联系电话（后端已脱敏）
  final String phone;

  /// 来源：1 装机申请 / 2 新增机器
  final int source;
  final String sourceName;

  /// 使用人：1 自己使用 / 2 他人使用
  final int useType;
  final String useTypeName;

  final String? contactName;
  final String? merchantName;
  final String? region;
  final String? address;
  final String? remark;
  final String? trafficFeeRemark;
  final DateTime? bootTime;
  final String? brandName;
  final String? typeName;

  /// 机号（装机申请通常为空，需现场录入）
  final String? machineNo;

  final DateTime? submittedAt;

  /// 选择列表的标题：门店名 → 联系人 → 单号
  String get title {
    for (final text in [merchantName, contactName]) {
      if (text != null && text.trim().isNotEmpty) return text.trim();
    }
    return requestNo.isEmpty ? '装机申请' : '申请单 $requestNo';
  }

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = '$value';
    return text.isEmpty ? null : text;
  }

  factory PendingInstallApply.fromJson(Map<String, dynamic> json) =>
      PendingInstallApply(
        applyId: _text(json['applyId']) ?? '',
        requestNo: _text(json['requestNo']) ?? '',
        phone: _text(json['phone']) ?? '',
        source: (json['source'] as num?)?.toInt() ?? 1,
        sourceName: _text(json['sourceName']) ?? '',
        useType: (json['useType'] as num?)?.toInt() ?? 1,
        useTypeName: _text(json['useTypeName']) ?? '',
        contactName: _text(json['contactName']),
        merchantName: _text(json['merchantName']),
        region: _text(json['region']),
        address: _text(json['address']),
        remark: _text(json['remark']),
        trafficFeeRemark: _text(json['trafficFeeRemark']),
        bootTime: DateTime.tryParse('${json['bootTime'] ?? ''}'),
        brandName: _text(json['brandName']),
        typeName: _text(json['typeName']),
        machineNo: _text(json['machineNo']),
        submittedAt: DateTime.tryParse('${json['submittedAt'] ?? ''}'),
      );
}

/// 按手机号查待装申请的结果（`GET /pos/applies/pending-by-phone`）。
///
/// 查不到不是错误：[found] 为 false 时用 [message] 做提示，不用当异常处理。
/// [items] 先申请的在前，与按号码直接装机选择的那台一致。
class PendingInstallPreview {
  const PendingInstallPreview({
    required this.found,
    required this.phone,
    required this.total,
    required this.message,
    this.items = const [],
  });

  final bool found;

  /// 查询用的手机号（后端已脱敏）
  final String phone;
  final int total;
  final String message;
  final List<PendingInstallApply> items;

  factory PendingInstallPreview.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return PendingInstallPreview(
      found: json['found'] == true,
      phone: '${json['phone'] ?? ''}',
      total: (json['total'] as num?)?.toInt() ?? 0,
      message: json['message'] as String? ?? '',
      items: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => PendingInstallApply.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }
}

/// 机具档案（`GET /pos/machines/:sn/info`）：装机页扫机号后自动带出的机具信息。
///
/// 后端按「台账行 → 申请单 → 已装机机器」的优先级回填，所以品牌/类型可能为空
/// （台账没导入）：[found] 为 false 时页面保持手选品牌/类型，不当异常处理。
class PosMachineProfile {
  const PosMachineProfile({
    required this.found,
    required this.machineNo,
    this.brandId,
    this.brandName,
    this.typeId,
    this.typeName,
    this.model = '',
    this.platform = '',
    this.activity = '',
    this.agentName = '',
    this.feeRate = '',
    this.scanRate = '',
    this.trafficFee = '',
    this.stockStatusLabel = '',
    this.inStock = false,
    this.installed = false,
    this.message = '',
  });

  final bool found;
  final String machineNo;

  /// 品牌/类型 ID 直接用于表单选中（台账没导入时为空，保持手选）
  final String? brandId;
  final String? brandName;
  final String? typeId;
  final String? typeName;

  /// 机具型号（如 NEW6220 / HM600Mp），台账回带，只读展示
  final String model;
  final String platform;
  final String activity;
  final String agentName;
  final String feeRate;
  final String scanRate;

  /// 台账流量费（元，两位小数字符串；台账没填为空串）
  final String trafficFee;

  /// 台账库存状态文案（在库/已出库/已回收/已报废），非台账行为空串
  final String stockStatusLabel;
  final bool inStock;

  /// 该机号是否已装机：true 时页面提示不要重复装机
  final bool installed;

  /// 后端给的提示文案（未命中/已装机/已带出），页面直接展示
  final String message;

  /// 只读展示用：「品牌 · 类型 · 型号 · 平台」只拼非空项
  String get specsLine {
    final parts = <String>[
      if ((brandName ?? '').isNotEmpty) brandName!,
      if ((typeName ?? '').isNotEmpty) typeName!,
      if (model.isNotEmpty) model,
      if (platform.isNotEmpty) platform,
      if (activity.isNotEmpty) activity,
      if (agentName.isNotEmpty) '代理 $agentName',
    ];
    return parts.join(' · ');
  }

  factory PosMachineProfile.fromJson(Map<String, dynamic> json) {
    String text(String key) => '${json[key] ?? ''}';
    String? optionalText(String key) {
      final value = '${json[key] ?? ''}';
      return value.isEmpty || value == 'null' ? null : value;
    }

    return PosMachineProfile(
      found: json['found'] == true,
      machineNo: text('machineNo'),
      brandId: optionalText('brandId'),
      brandName: optionalText('brandName'),
      typeId: optionalText('typeId'),
      typeName: optionalText('typeName'),
      model: text('model'),
      platform: text('platform'),
      activity: text('activity'),
      agentName: text('agentName'),
      feeRate: text('feeRate'),
      scanRate: text('scanRate'),
      trafficFee: text('trafficFee'),
      stockStatusLabel: text('stockStatusLabel'),
      inStock: json['inStock'] == true,
      installed: json['installed'] == true,
      message: text('message'),
    );
  }
}

/// 该客户已装的一台机器：只回机器号与品牌（门店/地址等资料不外泄）
class InstalledMachineItem {
  const InstalledMachineItem({required this.machineNo, this.brandName = ''});

  final String machineNo;
  final String brandName;

  factory InstalledMachineItem.fromJson(Map<String, dynamic> json) {
    return InstalledMachineItem(
      machineNo: '${json['machineNo'] ?? ''}',
      brandName: '${json['brandName'] ?? ''}',
    );
  }
}

/// 按客户实名（姓名 + 身份证号后 6 位）查到的已装机器（`GET /pos/installed-machines`）。
///
/// 装机页在提交前用它做一次核对：查不到不是错误（新客户，或存量申请没录身份证后 6 位），
/// 用 [message] 提示后照常允许继续装机。
class InstalledMachines {
  const InstalledMachines({
    required this.found,
    required this.total,
    required this.message,
    this.items = const [],
  });

  final bool found;
  final int total;
  final String message;
  final List<InstalledMachineItem> items;

  factory InstalledMachines.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return InstalledMachines(
      found: json['found'] == true,
      total: (json['total'] as num?)?.toInt() ?? 0,
      message: '${json['message'] ?? ''}',
      items: raw is List
          ? raw
              .whereType<Map>()
              .map((e) => InstalledMachineItem.fromJson(e.cast<String, dynamic>()))
              .toList()
          : const [],
    );
  }
}
