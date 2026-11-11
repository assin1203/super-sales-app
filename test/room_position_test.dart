import 'package:flutter_test/flutter_test.dart';

import 'package:kqw_app/core/models/team_room.dart';

/// 座位展示字段：脱敏手机号、入房时间、空位兜底。
void main() {
  RoomPosition parse(Map<String, dynamic> json) =>
      RoomPosition.fromJson({'seatNo': 2, 'contribution': '1', ...json});

  test('解析手机号与入房时间，时间按本地时间格式化', () {
    final seat = parse({
      'userId': '7',
      'nickname': '祝桂荣',
      'phone': '159****0403',
      'joinedAt': '2026-01-22T16:45:37',
      'contribution': '1',
    });

    expect(seat.occupied, isTrue);
    expect(seat.displayPhone, '159****0403');
    expect(seat.joinedAtText, '2026-01-22 16:45:37');
  });

  test('后端返回明文时本地再脱敏一层', () {
    final seat = parse({'userId': '7', 'phone': '13812348001'});
    expect(seat.displayPhone, '138****8001');
  });

  test('本人座位展示完整号码，他人仍脱敏', () {
    final self = parse({'userId': '7', 'phone': '13812348001', 'isSelf': true});
    expect(self.phoneText, '13812348001');

    final other = parse({'userId': '8', 'phone': '13812348001'});
    expect(other.phoneText, '138****8001');
  });

  test('空位：无手机号、无入房时间', () {
    final seat = parse({'userId': null});
    expect(seat.occupied, isFalse);
    expect(seat.displayPhone, '');
    expect(seat.joinedAtText, '');
    expect(seat.displayName, '成员');
  });

  test('入房时间字段缺失或非法时不崩溃', () {
    final seat = parse({'userId': '7', 'joinedAt': 'not-a-date'});
    expect(seat.joinedAt, isNull);
    expect(seat.joinedAtText, '');
  });
}
