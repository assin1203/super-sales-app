/// 积分礼包（`GET /points/packages`）。
///
/// 积分与金额都是字符串（积分为 BigInt，金额为 DECIMAL(10,2) 两位小数字符串），
/// 下单走 `POST /points/packages/{id}/order` 拿微信/支付宝支付参数。
class PointsPackage {
  const PointsPackage({
    required this.id,
    required this.name,
    required this.points,
    required this.priceAmount,
    this.bonusPoints = '0',
    this.tag = '',
    this.sort = 0,
    this.status = 1,
  });

  final String id;
  final String name;

  /// 基础积分
  final String points;

  /// 赠送积分
  final String bonusPoints;

  /// 售价（"19.90"）
  final String priceAmount;
  final String tag;
  final int sort;
  final int status;

  factory PointsPackage.fromJson(Map<String, dynamic> json) => PointsPackage(
        id: '${json['id'] ?? ''}',
        name: json['name'] as String? ?? '',
        points: '${json['points'] ?? '0'}',
        bonusPoints: '${json['bonusPoints'] ?? '0'}',
        priceAmount: '${json['priceAmount'] ?? '0.00'}',
        tag: json['tag'] as String? ?? '',
        sort: (json['sort'] as num?)?.toInt() ?? 0,
        status: (json['status'] as num?)?.toInt() ?? 1,
      );

  /// 到账总积分（基础 + 赠送）
  String get totalPoints {
    final base = int.tryParse(points) ?? 0;
    final bonus = int.tryParse(bonusPoints) ?? 0;
    return '${base + bonus}';
  }

  bool get hasBonus => (int.tryParse(bonusPoints) ?? 0) > 0;
}

/// 支付参数（微信 App 所需字段；支付宝返回对应 method）
class PayParams {
  const PayParams({
    this.appId = '',
    this.partnerId = '',
    this.prepayId = '',
    this.package = '',
    this.nonceStr = '',
    this.timeStamp = '',
    this.sign = '',
  });

  final String appId;
  final String partnerId;
  final String prepayId;
  final String package;
  final String nonceStr;
  final String timeStamp;
  final String sign;

  factory PayParams.fromJson(Map<String, dynamic> json) => PayParams(
        appId: json['appId'] as String? ?? '',
        partnerId: json['partnerId'] as String? ?? '',
        prepayId: json['prepayId'] as String? ?? '',
        package: json['package'] as String? ?? '',
        nonceStr: json['nonceStr'] as String? ?? '',
        timeStamp: json['timeStamp'] as String? ?? '',
        sign: json['sign'] as String? ?? '',
      );

  /// 参数是否齐全（缺字段时不该唤起支付 SDK）
  bool get complete =>
      prepayId.isNotEmpty && nonceStr.isNotEmpty && timeStamp.isNotEmpty;
}

/// 下单结果（POST /payment/order、POST /points/packages/{id}/order）
class PayOrder {
  const PayOrder({
    required this.orderId,
    required this.orderNo,
    required this.payAmount,
    required this.payStatus,
    this.points = '0',
    this.payChannel = 1,
    this.payParams,
  });

  final String orderId;
  final String orderNo;
  final String payAmount;

  /// 入账积分
  final String points;

  /// 1 微信 App / 2 支付宝 App
  final int payChannel;

  /// 支付状态：0 待支付 / 1 已支付 ...
  final int payStatus;
  final PayParams? payParams;

  factory PayOrder.fromJson(Map<String, dynamic> json) {
    final rawParams = json['payParams'];
    return PayOrder(
      orderId: '${json['orderId'] ?? ''}',
      orderNo: json['orderNo'] as String? ?? '',
      payAmount: '${json['payAmount'] ?? '0.00'}',
      points: '${json['points'] ?? '0'}',
      payChannel: (json['payChannel'] as num?)?.toInt() ?? 1,
      payStatus: (json['payStatus'] as num?)?.toInt() ?? 0,
      payParams: rawParams is Map
          ? PayParams.fromJson(rawParams.cast<String, dynamic>())
          : null,
    );
  }
}
