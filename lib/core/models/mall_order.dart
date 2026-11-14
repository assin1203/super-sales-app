/// 商城兑换订单（`/mall/orders` 与 `/mall/exchange`）。
///
/// 状态已在服务端映射为前端码：0 待发货 / 1 已发货 / 2 已完成 / 3 已取消，
/// 同时下发 `statusName`，前端直接展示不再自己维护文案。

/// 订单列表项（GET /mall/orders 的 items）
class OrderItem {
  const OrderItem({
    required this.id,
    required this.orderNo,
    required this.productId,
    required this.productName,
    required this.pointsCost,
    required this.buyCount,
    required this.status,
    required this.statusName,
    required this.deliveryType,
    this.productCover = '',
    this.createdAt,
    this.expressCompany,
    this.expressNo = '',
    this.shippedAt,
  });

  final String id;
  final String orderNo;
  final String productId;
  final String productName;
  final String productCover;

  /// 本单消耗积分（BigInt 字符串）
  final String pointsCost;
  final int buyCount;

  /// 0 待发货 / 1 已发货 / 2 已完成 / 3 已取消
  final int status;
  final String statusName;

  /// 1 实物 / 2 虚拟
  final int deliveryType;
  final DateTime? createdAt;

  /// 快递公司与单号（发货后服务端只下发这两项 + 订单号）
  final String? expressCompany;
  final String expressNo;
  final DateTime? shippedAt;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        id: '${json['id'] ?? ''}',
        orderNo: json['orderNo'] as String? ?? '',
        productId: '${json['productId'] ?? ''}',
        productName: json['productName'] as String? ?? '',
        productCover: json['productCover'] as String? ?? '',
        pointsCost: '${json['pointsCost'] ?? '0'}',
        buyCount: (json['buyCount'] as num?)?.toInt() ?? 1,
        status: (json['status'] as num?)?.toInt() ?? 0,
        statusName: json['statusName'] as String? ?? '',
        deliveryType: (json['deliveryType'] as num?)?.toInt() ?? 1,
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
        expressCompany: json['expressCompany'] as String?,
        expressNo: json['expressNo'] as String? ?? '',
        shippedAt: DateTime.tryParse('${json['shippedAt'] ?? ''}'),
      );

  bool get isVirtual => deliveryType == 2;

  /// 实物单已发货/已完成：服务端不再下发商品与积分，卡片按「订单号 + 物流」精简展示
  bool get fulfilled => !isVirtual && (status == 1 || status == 2);

  /// 有快递单号才展示物流行
  bool get hasLogistics => expressNo.isNotEmpty;

  /// 待发货 + 实物单才能取消（与后端可取消口径一致）
  bool get cancellable => status == 0 && !isVirtual;

  /// 仅已发货可确认收货
  bool get confirmable => status == 1;
}

/// 地址快照（订单详情内嵌）
class OrderAddress {
  const OrderAddress({
    required this.receiver,
    required this.phone,
    required this.province,
    required this.city,
    required this.district,
    required this.detail,
  });

  final String receiver;
  final String phone;
  final String province;
  final String city;
  final String district;
  final String detail;

  factory OrderAddress.fromJson(Map<String, dynamic> json) => OrderAddress(
        receiver: json['receiver'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        province: json['province'] as String? ?? '',
        city: json['city'] as String? ?? '',
        district: json['district'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
      );

  String get region =>
      [province, city, district].where((e) => e.isNotEmpty).join(' ');

  String get fullAddress => region.isEmpty ? detail : '$region $detail';
}

/// 订单详情（GET /mall/orders/{id}）
class OrderDetail extends OrderItem {
  const OrderDetail({
    required super.id,
    required super.orderNo,
    required super.productId,
    required super.productName,
    required super.pointsCost,
    required super.buyCount,
    required super.status,
    required super.statusName,
    required super.deliveryType,
    super.productCover,
    super.createdAt,
    super.expressCompany,
    super.expressNo,
    super.shippedAt,
    this.address,
    this.virtualContent,
    this.finishedAt,
    this.cancelledAt,
    this.cancelReason,
  });

  final OrderAddress? address;

  /// 虚拟商品卡密
  final String? virtualContent;
  final DateTime? finishedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final item = OrderItem.fromJson(json);
    final rawAddress = json['address'];
    return OrderDetail(
      id: item.id,
      orderNo: item.orderNo,
      productId: item.productId,
      productName: item.productName,
      productCover: item.productCover,
      pointsCost: item.pointsCost,
      buyCount: item.buyCount,
      status: item.status,
      statusName: item.statusName,
      deliveryType: item.deliveryType,
      createdAt: item.createdAt,
      expressCompany: item.expressCompany,
      expressNo: item.expressNo,
      shippedAt: item.shippedAt,
      address: rawAddress is Map
          ? OrderAddress.fromJson(rawAddress.cast<String, dynamic>())
          : null,
      virtualContent: json['virtualContent'] as String?,
      finishedAt: DateTime.tryParse('${json['finishedAt'] ?? ''}'),
      cancelledAt: DateTime.tryParse('${json['cancelledAt'] ?? ''}'),
      cancelReason: json['cancelReason'] as String?,
    );
  }
}

/// 兑换结果（POST /mall/exchange，201）
class ExchangeResult {
  const ExchangeResult({
    required this.orderId,
    required this.orderNo,
    required this.pointsCost,
    required this.pointsBalance,
    required this.status,
    required this.statusName,
    required this.deliveryType,
    this.virtualContent,
  });

  final String orderId;
  final String orderNo;
  final String pointsCost;

  /// 兑换后剩余积分
  final String pointsBalance;
  final int status;
  final String statusName;
  final int deliveryType;
  final String? virtualContent;

  factory ExchangeResult.fromJson(Map<String, dynamic> json) => ExchangeResult(
        orderId: '${json['orderId'] ?? ''}',
        orderNo: json['orderNo'] as String? ?? '',
        pointsCost: '${json['pointsCost'] ?? '0'}',
        pointsBalance: '${json['pointsBalance'] ?? '0'}',
        status: (json['status'] as num?)?.toInt() ?? 0,
        statusName: json['statusName'] as String? ?? '',
        deliveryType: (json['deliveryType'] as num?)?.toInt() ?? 1,
        virtualContent: json['virtualContent'] as String?,
      );
}

/// 取消订单结果（POST /mall/orders/{id}/cancel）
class CancelOrderResult {
  const CancelOrderResult({
    required this.id,
    required this.status,
    required this.statusName,
    required this.pointsRefunded,
    this.cancelledAt,
  });

  final String id;
  final int status;
  final String statusName;

  /// 退回积分
  final String pointsRefunded;
  final DateTime? cancelledAt;

  factory CancelOrderResult.fromJson(Map<String, dynamic> json) =>
      CancelOrderResult(
        id: '${json['id'] ?? ''}',
        status: (json['status'] as num?)?.toInt() ?? 3,
        statusName: json['statusName'] as String? ?? '',
        pointsRefunded: '${json['pointsRefunded'] ?? '0'}',
        cancelledAt: DateTime.tryParse('${json['cancelledAt'] ?? ''}'),
      );
}
