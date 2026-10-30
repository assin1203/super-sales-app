/// 积分商城商品（`GET /mall/products`）。
///
/// 字段与后台 `AdminProductCreateDto` 同源，C 端只读取展示所需的部分；
/// 后端 `id` / 金额类字段为 BigInt → 字符串，这里按需转换。
class Product {
  const Product({
    required this.id,
    required this.name,
    this.cover,
    this.detail,
    this.pricePoints = 0,
    this.stock = 0,
    this.minLevel = 0,
    this.deliveryType = 1,
    this.status = 1,
  });

  final String id;
  final String name;
  final String? cover;
  final String? detail;

  /// 纯积分价格
  final int pricePoints;

  final int stock;

  /// 可兑最低等级（0=L0 体验池）
  final int minLevel;

  /// 发货方式：1 实物 / 2 虚拟
  final int deliveryType;

  /// 1 上架 / 0 下架
  final int status;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: '${json['id'] ?? ''}',
      name: json['name'] as String? ?? '未命名商品',
      cover: json['cover'] as String?,
      detail: json['detail'] as String?,
      pricePoints: (json['pricePoints'] as num?)?.toInt() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      minLevel: (json['minLevel'] as num?)?.toInt() ?? 0,
      deliveryType: (json['deliveryType'] as num?)?.toInt() ?? 1,
      status: (json['status'] as num?)?.toInt() ?? 1,
    );
  }

  bool get isVirtual => deliveryType == 2;

  /// 等级池标签：L0 / L1 ...
  String get levelLabel => 'L$minLevel';

  /// 兑换接口要 number 类型，非数字 id 视为不可兑换
  int? get numericId => int.tryParse(id);
}
