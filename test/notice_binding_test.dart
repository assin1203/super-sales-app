import 'package:flutter_test/flutter_test.dart';

import 'package:kqw_app/core/models/notice_item.dart';
import 'package:kqw_app/core/models/page_result.dart';

/// 首页「平台公告」数据绑定：`GET /notices` 返回的是 `{list, total, pageNum, pageSize}`
/// （列表键是 list，不是 items），这里锁住解析口径，避免后端/前端各改一半。
void main() {
  Map<String, dynamic> listPayload() => {
        'list': [
          {
            'id': '12',
            'title': '系统升级通知',
            'summary': '今晚 22:00 起停机维护约 30 分钟',
            'type': 'MAINTENANCE',
            'isTop': 1,
            'sort': 0,
            'startAt': '2026-10-26T10:00:00.000Z',
            'endAt': null,
            'createdAt': '2026-10-26T09:00:00.000Z',
          },
          {
            'id': '11',
            'title': '双十一任务加码',
            'summary': '任务积分翻倍',
            'type': 'ACTIVITY',
            'isTop': 0,
            'sort': 1,
            'createdAt': '2026-10-25T03:00:00.000Z',
          },
        ],
        'total': 2,
        'pageNum': 1,
        'pageSize': 5,
      };

  test('列表按 list 键解析（公告接口不用 items）', () {
    final page =
        PageResult.fromJson(listPayload(), NoticeItem.fromJson, listKey: 'list');

    expect(page.total, 2);
    expect(page.items, hasLength(2));

    final top = page.items.first;
    expect(top.id, '12');
    expect(top.title, '系统升级通知');
    expect(top.summary, contains('停机维护'));
    expect(top.type, 'MAINTENANCE');
    expect(top.isTop, isTrue, reason: '库内 int 1 要能识别成置顶');
    expect(top.typeLabel, '维护');
    expect(top.displayAt, isNotNull);

    expect(page.items[1].isTop, isFalse);
    expect(page.items[1].typeLabel, '活动');
  });

  test('空公告返回空列表（首页走「暂无公告」空态）', () {
    final page = PageResult.fromJson(
      {'list': <dynamic>[], 'total': 0, 'pageNum': 1, 'pageSize': 5},
      NoticeItem.fromJson,
      listKey: 'list',
    );
    expect(page.items, isEmpty);
    expect(page.isEmpty, isTrue);
  });

  test('isTop 兼容 bool 形式', () {
    final item = NoticeItem.fromJson({'id': '1', 'title': 'x', 'isTop': true});
    expect(item.isTop, isTrue);
    final notTop = NoticeItem.fromJson({'id': '2', 'title': 'y', 'isTop': 0});
    expect(notTop.isTop, isFalse);
  });

  test('详情解析完整正文', () {
    final detail = NoticeDetail.fromJson({
      'id': '12',
      'title': '系统升级通知',
      'content': '今晚 22:00 起停机维护约 30 分钟，请提前处理待办。',
      'type': 'MAINTENANCE',
      'isTop': 1,
      'createdAt': '2026-10-26T09:00:00.000Z',
    });
    expect(detail.content, contains('停机维护'));
    expect(detail.isTop, isTrue);
    expect(detail.createdAt, isNotNull);
  });
}
