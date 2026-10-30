import '../api_client.dart';
import '../models/page_result.dart';
import '../models/points_flow.dart';
import '../models/points_package.dart';
import '../models/points_summary.dart';
import '../models/points_transfer_result.dart';
import '../request_no.dart';

/// 积分中心接口（`/points/*`）。
///
/// - 流水：`GET /points/flows`，`flowType` 1~10，支持日期区间
/// - 礼包：`GET /points/packages`，下单 `POST /points/packages/{id}/order`
class PointsApi {
  PointsApi({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// 积分概览（`GET /user/points`，钱包未初始化时后端按 0 返回）
  Future<PointsSummary> summary() async {
    final json = await _api.get<Map<String, dynamic>>('/user/points');
    return PointsSummary.fromJson(json);
  }

  /// 积分流水（需 app token；userId 由后端从 JWT 取）
  Future<PageResult<PointsFlowItem>> flows({
    int? flowType,
    String? startDate,
    String? endDate,
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/points/flows',
      query: {
        if (flowType != null) 'flowType': '$flowType',
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        'pageNum': '$pageNum',
        'pageSize': '$pageSize',
      },
    );
    return PageResult.fromJson(json, PointsFlowItem.fromJson);
  }

  /// 积分礼包列表（公开端点，无需 token）
  Future<List<PointsPackage>> packages() async {
    final json = await _api.get<Map<String, dynamic>>('/points/packages');
    final items = json['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => PointsPackage.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 礼包下单（需 app token）：返回支付参数，前端再唤起微信/支付宝
  ///
  /// [payChannel] 1 微信 App（默认）/ 2 支付宝 App；[requestNo] 幂等键。
  Future<PayOrder> createPackageOrder(
    String packageId, {
    int payChannel = 1,
    String? requestNo,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/points/packages/$packageId/order',
      body: {
        'payChannel': payChannel,
        'requestNo': requestNo ?? newRequestNo(),
      },
    );
    return PayOrder.fromJson(json);
  }

  /// 积分转让（需 app token，FR-8.3 会员互赠）
  ///
  /// 接收方按手机号指定；单次上限 100、每日 5 次由后端判定（60007 / 60008）。
  /// [requestNo] 为幂等键：同一 key 重放回放首次结果，网络超时后重试要复用它，
  /// 否则可能重复扣款。
  Future<PointsTransferResult> transfer({
    required String toPhone,
    required int points,
    String? remark,
    String? requestNo,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/points/transfers',
      body: {
        'toPhone': toPhone,
        'points': points,
        if (remark != null && remark.trim().isNotEmpty) 'remark': remark.trim(),
        'requestNo': requestNo ?? newRequestNo(),
      },
    );
    return PointsTransferResult.fromJson(json);
  }
}

final PointsApi pointsApi = PointsApi();
