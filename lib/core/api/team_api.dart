import '../api_client.dart';
import '../models/enter_room_result.dart';
import '../models/page_result.dart';
import '../models/room_package.dart';
import '../models/team_room.dart';

/// 团队接口（`/team/*`），全部需 app token。
///
/// 房间状态 0 筹备中 / 1 进行中 / 2 已结束；
/// `positions` 空位也会返回，前端按 seatNo 排 1+2+4 座位。
class TeamApi {
  TeamApi({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// 房间列表（分页）
  Future<PageResult<TeamRoom>> rooms({
    int? status,
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/team/rooms',
      query: {
        if (status != null) 'status': '$status',
        'pageNum': '$pageNum',
        'pageSize': '$pageSize',
      },
    );
    return PageResult.fromJson(json, TeamRoom.fromJson);
  }

  /// 房间详情（含座位布局）
  Future<TeamRoom> roomDetail(String id) async {
    final json = await _api.get<Map<String, dynamic>>('/team/rooms/$id');
    return TeamRoom.fromJson(json);
  }

  /// 房间成员（分页）
  Future<PageResult<RoomMember>> members(
    String id, {
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/team/rooms/$id/members',
      query: {'pageNum': '$pageNum', 'pageSize': '$pageSize'},
    );
    return PageResult.fromJson(json, RoomMember.fromJson);
  }

  /// 候补队列（不分页，`{items, total}`）
  Future<List<WaitQueueItem>> waitQueue() async {
    final json = await _api.get<Map<String, dynamic>>('/team/wait-queue');
    final items = json['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => WaitQueueItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 入房档位列表（不分页，`{items, total}`）：只含启用档，sort 升序，首项为默认档
  Future<List<RoomPackage>> roomPackages() async {
    final json = await _api.get<Map<String, dynamic>>('/team/room-packages');
    final items = json['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => RoomPackage.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 进入房间（选档进房）：后端负责资格校验、首次扣积分、沿推荐链找房、
  /// 占位与贡献值结算；前端只按返回结果跳详情。
  ///
  /// [packageId] 缺省走默认档（启用档 sort 升序首条）。已购过礼包时后端会
  /// 强制用已购档位，传别的档位会返回 400。
  Future<EnterRoomResult> enterRoom({String? packageId}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/team/rooms/enter',
      body: {
        if (packageId != null && packageId.isNotEmpty) 'packageId': packageId,
      },
    );
    return EnterRoomResult.fromJson(json);
  }
}

final TeamApi teamApi = TeamApi();
