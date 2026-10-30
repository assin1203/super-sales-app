/// 后端统一分页信封：`{items, total, pageNum, pageSize}`。
///
/// C 端所有分页接口（订单、积分流水、邀请记录、房间、成员、机器）同一口径，
/// 由服务端归一化 pageNum/pageSize 后返回。
class PageResult<T> {
  const PageResult({
    required this.items,
    required this.total,
    required this.pageNum,
    required this.pageSize,
  });

  final List<T> items;
  final int total;
  final int pageNum;
  final int pageSize;

  /// [listKey]：列表字段名，默认 `items`；公告接口用的是 `list`
  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse, {
    String listKey = 'items',
  }) {
    final raw = json[listKey];
    final list = raw is List ? raw : const <dynamic>[];
    return PageResult<T>(
      items: list
          .whereType<Map>()
          .map((e) => parse(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? list.length,
      pageNum: (json['pageNum'] as num?)?.toInt() ?? 1,
      pageSize: (json['pageSize'] as num?)?.toInt() ?? list.length,
    );
  }

  /// 兼容不分页的 `{items, total}` 响应（banner / 礼包 / 任务 / 地址 / 候补）
  factory PageResult.fromListJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) {
    final raw = json['items'];
    final list = raw is List ? raw : const <dynamic>[];
    return PageResult<T>(
      items: list
          .whereType<Map>()
          .map((e) => parse(e.cast<String, dynamic>()))
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? list.length,
      pageNum: 1,
      pageSize: list.length,
    );
  }

  bool get isEmpty => items.isEmpty;

  PageResult<E> map<E>(E Function(T) convert) => PageResult<E>(
        items: items.map(convert).toList(),
        total: total,
        pageNum: pageNum,
        pageSize: pageSize,
      );
}
