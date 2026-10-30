/// 入房档位（`GET /team/room-packages`，需 app token）。
///
/// 后端只返回启用档（room_package.status=1），按 sort 升序，首项 isDefault=true。
/// 入房消耗的是积分（entryPoints），不再有金额字段。
class RoomPackage {
  const RoomPackage({
    required this.id,
    required this.code,
    required this.name,
    required this.entryPoints,
    this.image = '',
    this.dividendPercent = 0,
    this.sort = 0,
    this.isDefault = false,
  });

  final String id;
  final String code;
  final String name;
  final String image;

  /// 入房消耗积分
  final int entryPoints;

  /// 分账比例（百分比整数，200 = 按入房积分的 200% 分账）
  final int dividendPercent;
  final int sort;

  /// 默认档（列表首项）
  final bool isDefault;

  factory RoomPackage.fromJson(Map<String, dynamic> json) => RoomPackage(
        id: '${json['id'] ?? ''}',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        image: json['image'] as String? ?? '',
        entryPoints: (json['entryPoints'] as num?)?.toInt() ?? 0,
        dividendPercent: (json['dividendPercent'] as num?)?.toInt() ?? 0,
        sort: (json['sort'] as num?)?.toInt() ?? 0,
        isDefault: json['isDefault'] as bool? ?? false,
      );
}
