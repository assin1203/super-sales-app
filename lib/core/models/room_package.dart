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
    this.purchased = false,
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

  /// 当前用户是否已购买过该档位礼包（终身一次，依据后端 user_room_package）。
  ///
  /// 后端 `GET /team/room-packages` 已返回该字段（按 token 里的用户计算）；
  /// 已购用户进房不再扣积分，前端据此放行积分不足的情况，并显示「已完成升级」。
  final bool purchased;

  /// 档位 code → 房间等级，与后端 `ROOM_LEVEL_BY_PACKAGE_CODE` 对齐：
  /// `BASIC` = 200 档（lv1）、`ADVANCED` = 600 档（lv2）。新增档位要同步这里。
  static const Map<String, int> _levelByCode = {
    'BASIC': 1,
    'ADVANCED': 2,
  };

  /// 房间等级：200 档 = 1、600 档 = 2；未知档位为 null
  int? get roomLevel => _levelByCode[code];

  /// 600 档（lv2）房间：后端要求先进入过 200 档房间，不允许跳档（错误码 43005）。
  /// 前端只能提前提示，是否满足资格由后端按 `room_op_log` 判定。
  bool get needsBasicRoomFirst => (roomLevel ?? 1) > 1;

  factory RoomPackage.fromJson(Map<String, dynamic> json) => RoomPackage(
        id: '${json['id'] ?? ''}',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        image: json['image'] as String? ?? '',
        entryPoints: (json['entryPoints'] as num?)?.toInt() ?? 0,
        dividendPercent: (json['dividendPercent'] as num?)?.toInt() ?? 0,
        sort: (json['sort'] as num?)?.toInt() ?? 0,
        isDefault: json['isDefault'] as bool? ?? false,
        purchased: json['purchased'] as bool? ?? false,
      );
}
