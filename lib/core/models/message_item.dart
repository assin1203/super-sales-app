/// App 站内消息模型（`GET /message/*`）
///
/// 数据源是后台「用户与会员」设置的团队长链路：团队长伞下有人提交装机申请时，
/// 系统给团队长绑定的装机人落一条消息，并同步推企微群提醒。
class MessageItem {
  const MessageItem({
    required this.id,
    required this.type,
    required this.typeName,
    required this.title,
    required this.content,
    required this.read,
    this.readAt,
    this.createdAt,
  });

  final String id;

  /// 后端消息类型，目前只有 `TEAM_MACHINE_APPLY`
  final String type;

  /// 类型中文名（后端下发，前端兜底用 type）
  final String typeName;
  final String title;
  final String content;
  final bool read;
  final DateTime? readAt;
  final DateTime? createdAt;

  factory MessageItem.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] as String?) ?? '';
    return MessageItem(
      id: '${json['id'] ?? ''}',
      type: type,
      typeName: (json['typeName'] as String?)?.trim().isNotEmpty == true
          ? json['typeName'] as String
          : type,
      title: (json['title'] as String?) ?? '',
      content: (json['content'] as String?) ?? '',
      read: json['read'] == true,
      readAt: _parseTime(json['readAt']),
      createdAt: _parseTime(json['createdAt']),
    );
  }
}

/// 消息详情里的关联装机申请（点开后要看到「谁提交的、装哪台」）
class MessageApply {
  const MessageApply({
    required this.applyId,
    required this.requestNo,
    required this.statusName,
    required this.contactName,
    required this.phone,
    required this.merchantName,
    required this.region,
    required this.address,
    required this.machineNo,
    required this.brand,
    required this.typeName,
    required this.submittedAt,
    required this.applicantName,
    required this.applicantPhone,
    required this.applicantLevel,
  });

  final String applyId;
  final String requestNo;
  final String statusName;
  final String contactName;
  final String phone;
  final String merchantName;
  final String region;
  final String address;
  final String machineNo;
  final String brand;
  final String typeName;
  final DateTime? submittedAt;

  /// 提交人（消息的触发者）
  final String applicantName;
  final String applicantPhone;
  final int applicantLevel;

  factory MessageApply.fromJson(Map<String, dynamic> json) {
    final applicant =
        (json['applicant'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MessageApply(
      applyId: '${json['applyId'] ?? ''}',
      requestNo: (json['requestNo'] as String?) ?? '',
      statusName: (json['statusName'] as String?) ?? '',
      contactName: (json['contactName'] as String?) ?? '',
      phone: (json['phone'] as String?) ?? '',
      merchantName: (json['merchantName'] as String?) ?? '',
      region: (json['region'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      machineNo: (json['machineNo'] as String?) ?? '',
      brand: (json['brand'] as String?) ?? '',
      typeName: (json['typeName'] as String?) ?? '',
      submittedAt: _parseTime(json['submittedAt']),
      applicantName: (applicant['nickname'] as String?) ?? '',
      applicantPhone: (applicant['phone'] as String?) ?? '',
      applicantLevel: (applicant['level'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 消息详情：消息本体 + 关联申请（`apply` 为 null 表示该类型没有业务详情可展示）
class MessageDetail {
  const MessageDetail({required this.message, this.apply});

  final MessageItem message;
  final MessageApply? apply;

  factory MessageDetail.fromJson(Map<String, dynamic> json) {
    return MessageDetail(
      message: MessageItem.fromJson(json),
      apply: json['apply'] is Map
          ? MessageApply.fromJson((json['apply'] as Map).cast<String, dynamic>())
          : null,
    );
  }
}

/// 消息分页信封：除标准分页字段外额外带未读总数（一处请求就能刷红点）
class MessagePage {
  const MessagePage({
    required this.items,
    required this.total,
    required this.pageNum,
    required this.pageSize,
    required this.unread,
  });

  final List<MessageItem> items;
  final int total;
  final int pageNum;
  final int pageSize;
  final int unread;

  factory MessagePage.fromJson(Map<String, dynamic> json) {
    final raw = json['list'];
    final list = raw is List ? raw : const <dynamic>[];
    return MessagePage(
      items: list
          .whereType<Map>()
          .map((e) => MessageItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? list.length,
      pageNum: (json['pageNum'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? list.length,
      unread: (json['unread'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 后端时间统一是 ISO 字符串；解析失败按 null 处理（列表不因为一条脏时间崩掉）
DateTime? _parseTime(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
