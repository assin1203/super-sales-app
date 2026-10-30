import '../api_client.dart';
import '../models/mall_order.dart';
import '../models/page_result.dart';
import '../models/product.dart';
import '../request_no.dart';

/// 积分商城接口（`/mall/*`）。
///
/// 商品列表：`GET /mall/products`（公开），返回上架商品数组，字段见 [Product]；
/// 服务端只按上架 + sort 返回，等级池（min_level）由 App 按登录用户等级再筛。
/// 订单/兑换已是真实实现（扣库存 + 扣积分 + 流水同事务）。
class MallApi {
  MallApi({ApiClient? client}) : _api = client ?? ApiClient();

  final ApiClient _api;

  /// 商品列表（公开端点，无需 token）
  Future<List<Product>> products() async {
    final list = await _api.get<List<dynamic>>('/mall/products');
    return list
        .whereType<Map>()
        .map((e) => Product.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 我的兑换订单（需 app token）
  ///
  /// [status] 0 待发货 / 1 已发货 / 2 已完成 / 3 已取消，null 为全部。
  Future<PageResult<OrderItem>> orders({
    int? status,
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/mall/orders',
      query: {
        if (status != null) 'status': '$status',
        'pageNum': '$pageNum',
        'pageSize': '$pageSize',
      },
    );
    return PageResult.fromJson(json, OrderItem.fromJson);
  }

  /// 订单详情（非本人订单按 40001 返回，不泄露存在性）
  Future<OrderDetail> orderDetail(String id) async {
    final json = await _api.get<Map<String, dynamic>>('/mall/orders/$id');
    return OrderDetail.fromJson(json);
  }

  /// 取消订单：仅待发货 + 实物单，退积分与改状态同事务
  Future<CancelOrderResult> cancelOrder(String id, {String? reason}) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/mall/orders/$id/cancel',
      body: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
    return CancelOrderResult.fromJson(json);
  }

  /// 确认收货：仅已发货可用
  Future<void> confirmOrder(String id) async {
    await _api.post<Map<String, dynamic>>('/mall/orders/$id/confirm');
  }

  /// 积分兑换（需 app token）：扣库存 + 建单 + 扣积分 + 流水同事务；
  /// [requestNo] 为幂等键，同一 key 重放返回首次结果，不重复扣分。
  ///
  /// [addressId] 实物商品必填，虚拟商品忽略。
  Future<ExchangeResult> exchange(
    String productId, {
    int buyCount = 1,
    String? addressId,
    String? requestNo,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/mall/exchange',
      body: {
        'productId': productId,
        'buyCount': buyCount,
        if (addressId != null && addressId.isNotEmpty) 'addressId': addressId,
        'requestNo': requestNo ?? newRequestNo(),
      },
    );
    return ExchangeResult.fromJson(json);
  }
}

final MallApi mallApi = MallApi(client: api);
