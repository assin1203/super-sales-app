import '../api_client.dart';
import '../models/machine.dart';

/// POS 机器接口（`/pos/*`）。
///
/// 新手任务状态 0 未开始 / 1 进行中 / 2 审核中 / 3 已完成；
/// 装机申请为公开提交流程（需 app token，userId 由后端从 JWT 取）。
class PosApi {
  PosApi({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// 我的机器列表（需 app token）：已装机机器分页 + 申请中的新增机器（同一用户可多台）
  Future<MachineList> machines({
    int? newbieStatus,
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/pos/machines',
      query: {
        if (newbieStatus != null) 'newbieStatus': '$newbieStatus',
        'pageNum': '$pageNum',
        'pageSize': '$pageSize',
      },
    );
    return MachineList.fromJson(json);
  }

  /// 机器详情（含时间线与奖励状态）
  Future<MachineDetail> machineDetail(String sn) async {
    final json = await _api.get<Map<String, dynamic>>('/pos/machines/$sn');
    return MachineDetail.fromJson(json);
  }

  /// 提交装机申请（同手机号 7 天内重复申请会被拦截）
  Future<MachineApplyResult> apply({
    required String contactName,
    required String phone,
    String? merchantName,
    String? region,
    String? address,
    String? remark,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/pos/apply',
      body: {
        'contactName': contactName,
        'phone': phone,
        if (merchantName != null && merchantName.isNotEmpty)
          'merchantName': merchantName,
        if (region != null && region.isNotEmpty) 'region': region,
        if (address != null && address.isNotEmpty) 'address': address,
        if (remark != null && remark.isNotEmpty) 'remark': remark,
      },
    );
    return MachineApplyResult.fromJson(json);
  }

  /// 新手任务提交审核
  Future<Map<String, dynamic>> submitNewbie(String sn) =>
      _api.post<Map<String, dynamic>>('/pos/newbie/submit', body: {'sn': sn});

  /// 品牌下拉（后台 /admin/pos/brands 维护，仅返回启用项，sort 升序）
  Future<List<PosBrandOption>> brands() async {
    final json = await _api.get<Map<String, dynamic>>('/pos/brands');
    final items = json['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => PosBrandOption.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 类型下拉（后台 /admin/pos/types 维护）
  Future<List<PosTypeOption>> types() async {
    final json = await _api.get<Map<String, dynamic>>('/pos/types');
    final items = json['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => PosTypeOption.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 新增机器：机号全局唯一（重复 → 41009），机号能查到归属用户则绑定客户
  Future<MachineAddResult> addMachine({
    required String machineNo,
    required String customerPhone,
    String? brandId,
    String? typeId,
    String? trafficFeeRemark,
    DateTime? bootTime,
    String? remark,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/pos/machines',
      body: {
        'machineNo': machineNo,
        'customerPhone': customerPhone,
        if (brandId != null && brandId.isNotEmpty) 'brandId': brandId,
        if (typeId != null && typeId.isNotEmpty) 'typeId': typeId,
        if (trafficFeeRemark != null && trafficFeeRemark.isNotEmpty)
          'trafficFeeRemark': trafficFeeRemark,
        if (bootTime != null) 'bootTime': _dateText(bootTime),
        if (remark != null && remark.isNotEmpty) 'remark': remark,
      },
    );
    return MachineAddResult.fromJson(json);
  }

  /// 日期参数统一 yyyy-MM-dd（后端 DATE 列按此格式校验）
  static String _dateText(DateTime date) =>
      '${date.year}-${_two(date.month)}-${_two(date.day)}';

  static String _two(int value) => value.toString().padLeft(2, '0');
}

final PosApi posApi = PosApi();
