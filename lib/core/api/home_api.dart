import '../api_client.dart';
import '../models/banner_item.dart';

/// 首页接口（`/home/*`）。
///
/// banner 是**公开端点**（未登录也要出首屏），items 为空时前端用本地兜底图，
/// 不算错误，因此这里不抛异常、也不补假数据。
class HomeApi {
  HomeApi({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// [position]：HOME_TOP 首页轮播（默认）/ HOME_AD 腰封
  Future<List<BannerItem>> banners({String position = 'HOME_TOP'}) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/home/banners',
      query: {'position': position},
    );
    final items = json['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => BannerItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}

final HomeApi homeApi = HomeApi();
