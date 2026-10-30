/// 平台公告（`GET /notices`，公开端点：未登录也要能看到系统通知）。
///
/// 服务端只返回「已发布 + 命中时间窗」的公告，排序固定为
/// 「置顶 → sort 升序 → id 升序」，列表项只带摘要（正文走详情接口）。
class NoticeItem {
  const NoticeItem({
    required this.id,
    required this.title,
    this.summary = '',
    this.type = 'SYSTEM',
    this.isTop = false,
    this.sort = 0,
    this.startAt,
    this.endAt,
    this.createdAt,
  });

  final String id;
  final String title;

  /// 正文摘要（服务端截断到 100 字）
  final String summary;

  /// SYSTEM / ACTIVITY / MAINTENANCE
  final String type;
  final bool isTop;
  final int sort;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? createdAt;

  factory NoticeItem.fromJson(Map<String, dynamic> json) => NoticeItem(
        id: '${json['id'] ?? ''}',
        title: json['title'] as String? ?? '',
        summary: json['summary'] as String? ?? '',
        type: json['type'] as String? ?? 'SYSTEM',
        // 库内 int(0/1)，兼容后端可能下发的 bool
        isTop: json['isTop'] == true || (json['isTop'] as num?)?.toInt() == 1,
        sort: (json['sort'] as num?)?.toInt() ?? 0,
        startAt: DateTime.tryParse('${json['startAt'] ?? ''}'),
        endAt: DateTime.tryParse('${json['endAt'] ?? ''}'),
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
      );

  /// 列表展示日期：优先展示发布时间
  DateTime? get displayAt => createdAt ?? startAt;

  /// 类型标签（首页只区分活动/维护，其余统一按系统处理）
  String get typeLabel => switch (type) {
        'ACTIVITY' => '活动',
        'MAINTENANCE' => '维护',
        _ => '公告',
      };
}

/// 公告详情（`GET /notices/{id}`）：带完整正文
class NoticeDetail {
  const NoticeDetail({
    required this.id,
    required this.title,
    this.content = '',
    this.type = 'SYSTEM',
    this.isTop = false,
    this.createdAt,
  });

  final String id;
  final String title;
  final String content;
  final String type;
  final bool isTop;
  final DateTime? createdAt;

  factory NoticeDetail.fromJson(Map<String, dynamic> json) => NoticeDetail(
        id: '${json['id'] ?? ''}',
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        type: json['type'] as String? ?? 'SYSTEM',
        isTop: json['isTop'] == true || (json['isTop'] as num?)?.toInt() == 1,
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
      );
}
