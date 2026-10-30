/// 收货地址（`/user/addresses` 系列）。
///
/// 单用户上限 20 条、同一用户仅一条默认；`id` 为 BigInt 字符串。
class AddressItem {
  const AddressItem({
    required this.id,
    required this.receiver,
    required this.phone,
    required this.province,
    required this.city,
    required this.district,
    required this.detail,
    this.isDefault = false,
    this.createdAt,
  });

  final String id;
  final String receiver;
  final String phone;
  final String province;
  final String city;
  final String district;
  final String detail;
  final bool isDefault;
  final DateTime? createdAt;

  factory AddressItem.fromJson(Map<String, dynamic> json) => AddressItem(
        id: '${json['id'] ?? ''}',
        receiver: json['receiver'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        province: json['province'] as String? ?? '',
        city: json['city'] as String? ?? '',
        district: json['district'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
        isDefault: json['isDefault'] == true,
        createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
      );

  /// 省市区合并展示（空段自动跳过）
  String get region =>
      [province, city, district].where((e) => e.isNotEmpty).join(' ');

  String get fullAddress => region.isEmpty ? detail : '$region $detail';

  /// 手机号脱敏：138****0001
  String get maskedPhone => phone.length >= 7
      ? '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}'
      : phone;

  /// 提交给后端的补丁体（新增/编辑共用）
  Map<String, dynamic> toJson() => {
        'receiver': receiver,
        'phone': phone,
        'province': province,
        'city': city,
        'district': district,
        'detail': detail,
        'isDefault': isDefault,
      };
}
