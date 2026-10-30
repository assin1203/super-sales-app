import '../api_client.dart';
import '../models/points_package.dart';
import '../request_no.dart';

/// 支付接口（`/payment/*`），需 app token。
///
/// 金额与积分数一律由后端计算，前端只传 bizType + bizId；
/// 回调按 out_trade_no 幂等，前端轮询 `GET /payment/order/{id}` 拿最终态。
class PaymentApi {
  PaymentApi({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// 下单：bizType 1 积分礼包 / 2 商城付费商品 / 3 会员费
  Future<PayOrder> createOrder({
    required int bizType,
    required String bizId,
    int payChannel = 1,
    String? requestNo,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/payment/order',
      body: {
        'bizType': bizType,
        'bizId': bizId,
        'payChannel': payChannel,
        'requestNo': requestNo ?? newRequestNo(),
      },
    );
    return PayOrder.fromJson(json);
  }

  /// 查询支付状态（payStatus / pointsBalance）
  Future<Map<String, dynamic>> getOrder(String id) =>
      _api.get<Map<String, dynamic>>('/payment/order/$id');
}

final PaymentApi paymentApi = PaymentApi();
