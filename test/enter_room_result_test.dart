import 'package:flutter_test/flutter_test.dart';

import 'package:kqw_app/core/models/enter_room_result.dart';

/// EnterRoomVO 解析：字段齐全 / 缺字段兜底 / 回执文案。
void main() {
  test('解析完整入房回执', () {
    final r = EnterRoomResult.fromJson({
      'roomId': 12,
      'posNo': 3,
      'packageId': '2',
      'entryPoints': 199,
      'purchased': true,
      'captain': false,
      'uplineId': 88,
      'rebound': true,
    });

    expect(r.roomId, '12');
    expect(r.posNo, 3);
    expect(r.packageId, '2');
    expect(r.entryPoints, 199);
    expect(r.purchased, isTrue);
    expect(r.captain, isFalse);
    expect(r.uplineId, '88');
    expect(r.rebound, isTrue);
    expect(r.summary, '已入房 · 3 号位（首次购买礼包，消耗 199 积分）');
  });

  test('缺字段时兜底：空 roomId、posNo 0、未购买', () {
    final r = EnterRoomResult.fromJson(const {});

    expect(r.roomId, '');
    expect(r.posNo, 0);
    expect(r.packageId, '');
    expect(r.entryPoints, 0);
    expect(r.purchased, isFalse);
    expect(r.captain, isFalse);
    expect(r.uplineId, isNull);
    expect(r.rebound, isFalse);
    expect(r.summary, '已入房 · 0 号位');
  });

  test('已购礼包再进房：不重复扣分，回执不带消耗', () {
    final r = EnterRoomResult.fromJson({
      'roomId': '9',
      'posNo': 1,
      'packageId': '1',
      'entryPoints': 0,
      'purchased': false,
      'captain': true,
      'uplineId': null,
    });

    expect(r.summary, '已入房 · 1 号位（队长位）');
  });
}
