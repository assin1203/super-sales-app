/// 入房回执（`POST /team/rooms/enter`，对应后端 EnterRoomVO）。
///
/// 口径（后端判定，前端只展示）：
/// - 一个用户终身只能买一个档位礼包，首次入房才扣 `entryPoints` 积分；
///   已购过则 `purchased = false`、`entryPoints = 0`，进房不再扣费。
/// - `captain` 表示占到 1 号位（自建房间当队长）。
/// - `uplineId` 是贡献值记给谁：沿推荐链命中的有房上线；自建房间为 null。
/// - `rebound` 表示直接上级没进房、改挂到更上层上线。
class EnterRoomResult {
  const EnterRoomResult({
    required this.roomId,
    required this.posNo,
    required this.packageId,
    this.entryPoints = 0,
    this.purchased = false,
    this.captain = false,
    this.uplineId,
    this.rebound = false,
  });

  /// 进入的房间 id
  final String roomId;

  /// 落座席位号（1~7，1+2+4 三排，从上到下、从左到右）
  final int posNo;

  /// 本次使用的档位 id（入房费 = 分红基数）
  final String packageId;

  /// 本次购买礼包扣掉的积分；已购过礼包时为 0
  final int entryPoints;

  /// 本次是否新购礼包（首次入房）
  final bool purchased;

  /// 是否占的是 1 号位（队长位）
  final bool captain;

  /// 贡献值记给的上线；自建房间为 null
  final String? uplineId;

  /// 是否因直接上级没进房而改挂了推荐关系
  final bool rebound;

  factory EnterRoomResult.fromJson(Map<String, dynamic> json) {
    final upline = json['uplineId'];
    return EnterRoomResult(
      roomId: '${json['roomId'] ?? ''}',
      posNo: (json['posNo'] as num?)?.toInt() ?? 0,
      packageId: '${json['packageId'] ?? ''}',
      entryPoints: (json['entryPoints'] as num?)?.toInt() ?? 0,
      purchased: json['purchased'] == true,
      captain: json['captain'] == true,
      uplineId: upline == null ? null : '$upline',
      rebound: json['rebound'] == true,
    );
  }

  /// 入房成功给用户看的一句话，例如
  /// 「已入房 · 3 号位（首次购买礼包，消耗 199 积分）」
  String get summary {
    final seat = '已入房 · $posNo 号位';
    final tail = <String>[
      if (purchased && entryPoints > 0) '首次购买礼包，消耗 $entryPoints 积分',
      if (captain) '队长位',
    ];
    return tail.isEmpty ? seat : '$seat（${tail.join('，')}）';
  }
}
