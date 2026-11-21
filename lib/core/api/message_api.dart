import '../api_client.dart';
import '../models/message_item.dart';

/// App 站内消息接口（`/message/*`，需登录）
///
/// 后端身份一律取自 JWT，前端不传 userId；越权读别人的消息 id 会直接 404。
class MessageApi {
  MessageApi({ApiClient? client}) : _api = client ?? api;

  final ApiClient _api;

  /// 我的消息列表（`unreadOnly` 只看未读），返回列表 + 未读总数
  Future<MessagePage> list({
    bool unreadOnly = false,
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/message/list',
      query: {
        if (unreadOnly) 'unread': '1',
        'pageNum': '$pageNum',
        'pageSize': '$pageSize',
      },
    );
    return MessagePage.fromJson(json);
  }

  /// 未读数（首页 / 「我的」红点）
  Future<int> unreadCount() async {
    final json =
        await _api.get<Map<String, dynamic>>('/message/unread-count');
    return (json['unread'] as num?)?.toInt() ?? 0;
  }

  /// 消息详情：后端在首次打开时会自动标记已读，并带回关联装机申请
  Future<MessageDetail> detail(String id) async {
    final json =
        await _api.get<Map<String, dynamic>>('/message/$id');
    return MessageDetail.fromJson(json);
  }

  /// 批量标记已读（列表页一次清多条）
  Future<void> markRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await _api.post<Map<String, dynamic>>(
      '/message/read',
      body: {'ids': ids},
    );
  }

  /// 全部标记已读
  Future<void> markAllRead() async {
    await _api.post<Map<String, dynamic>>('/message/read-all');
  }
}

final MessageApi messageApi = MessageApi();
