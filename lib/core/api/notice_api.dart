import '../api_client.dart';
import '../models/page_result.dart';
import '../models/notice_item.dart';

/// 平台公告接口（`/notices`）。
///
/// **公开端点**（与 `/home/banners` 同口径，不要求登录）：只返回已发布且
/// 命中 startAt/endAt 时间窗的公告，拉不到就按空处理，不打断首页首屏。
class NoticeApi {
  NoticeApi({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// 公告列表（分页）。返回结构为 `{list, total, pageNum, pageSize}`。
  Future<PageResult<NoticeItem>> list({
    String? type,
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/notices',
      query: {
        if (type != null && type.isNotEmpty) 'type': type,
        'pageNum': '$pageNum',
        'pageSize': '$pageSize',
      },
    );
    return PageResult.fromJson(json, (e) => NoticeItem.fromJson(e), listKey: 'list');
  }

  /// 公告详情（正文全文）；草稿/未生效/已过期后端统一 404
  Future<NoticeDetail> detail(String id) async {
    final json = await _api.get<Map<String, dynamic>>('/notices/$id');
    return NoticeDetail.fromJson(json);
  }
}

final NoticeApi noticeApi = NoticeApi();
