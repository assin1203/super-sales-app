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

  factory Machine.fromJson(Map<String, dynamic> json) {
    final rawProgress = json['progress'];
    final rawReferrer = json['referredBy'];
    final rawReason = (json['newbieRejectReason'] as String?)?.trim() ?? '';
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
        progress: progress,
      );

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
