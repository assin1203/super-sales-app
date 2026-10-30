import '../api_client.dart';
import '../models/machine.dart';
import '../models/page_result.dart';

/// POS 机器接口（`/pos/*`）。
///
/// 新手任务状态 0 未开始 / 1 进行中 / 2 审核中 / 3 已完成；
/// 装机申请为公开提交流程（需 app token，userId 由后端从 JWT 取）。
class PosApi {
  PosApi({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// 我的机器列表（需 app token）
  Future<PageResult<Machine>> machines({
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
    return PageResult.fromJson(json, Machine.fromJson);
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
}

final PosApi posApi = PosApi();
