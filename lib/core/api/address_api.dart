import '../api_client.dart';
import '../models/address.dart';

/// C 端收货地址簿（`/user/addresses`）。
///
/// 单用户上限 20 条（超限 → 11001），同一用户仅一条默认；
/// 非本人地址统一 11002（404），不区分「不存在」与「别人的」。
class AddressApi {
  AddressApi({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// 地址列表（不分页，上限 20 条）
  Future<List<AddressItem>> list() async {
    final json = await _api.get<Map<String, dynamic>>('/user/addresses');
    final items = json['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => AddressItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// 新增地址；isDefault=true 时服务端同事务清其他默认
  Future<AddressItem> create({
    required String receiver,
    required String phone,
    required String province,
    required String city,
    required String district,
    required String detail,
    bool isDefault = false,
  }) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/user/addresses',
      body: {
        'receiver': receiver,
        'phone': phone,
        'province': province,
        'city': city,
        'district': district,
        'detail': detail,
        'isDefault': isDefault,
      },
    );
    return AddressItem.fromJson(json);
  }

  /// 编辑地址（补丁式，只传要改的字段）
  Future<AddressItem> update(
    String id, {
    String? receiver,
    String? phone,
    String? province,
    String? city,
    String? district,
    String? detail,
    bool? isDefault,
  }) async {
    final json = await _api.put<Map<String, dynamic>>(
      '/user/addresses/$id',
      body: {
        if (receiver != null) 'receiver': receiver,
        if (phone != null) 'phone': phone,
        if (province != null) 'province': province,
        if (city != null) 'city': city,
        if (district != null) 'district': district,
        if (detail != null) 'detail': detail,
        if (isDefault != null) 'isDefault': isDefault,
      },
    );
    return AddressItem.fromJson(json);
  }

  /// 删除地址
  Future<void> remove(String id) => _api.deleteVoid('/user/addresses/$id');

  /// 设为默认地址（服务端同事务先清后设）
  Future<void> setDefault(String id) async {
    await _api.post<Map<String, dynamic>>('/user/addresses/$id/default');
  }
}

final AddressApi addressApi = AddressApi();
