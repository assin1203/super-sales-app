import 'package:flutter_test/flutter_test.dart';
import 'package:kqw_app/core/models/points_transfer_result.dart';

/// 积分转让（`POST /points/transfers`）返回解析。
///
/// 后端 points / balanceAfter 是 BigInt 字符串，idempotent 为布尔；
/// 幂等重放时 idempotent=true，前端据此提示「已处理过」。
void main() {
  test('首次转让解析', () {
    final r = PointsTransferResult.fromJson({
      'transferNo': 'T20261027001',
      'toPhone': '13800138000',
      'toNickname': '小明',
      'points': '50',
      'balanceAfter': '950',
      'idempotent': false,
      'createdAt': '2026-10-27T10:00:00.000Z',
    });
    expect(r.transferNo, 'T20261027001');
    expect(r.toNickname, '小明');
    expect(r.points, '50');
    expect(r.balanceAfter, '950');
    expect(r.idempotent, isFalse);
    expect(r.createdAt, isNotNull);
  });

  test('幂等重放标记为 true', () {
    final r = PointsTransferResult.fromJson({
      'transferNo': 'T20261027001',
      'toPhone': '13800138000',
      'points': 50,
      'balanceAfter': 950,
      'idempotent': true,
    });
    expect(r.idempotent, isTrue);
    // 数字下发也归一成字符串，避免大数精度问题
    expect(r.points, '50');
    expect(r.balanceAfter, '950');
    expect(r.createdAt, isNull);
  });

  test('字段缺失时走空值兜底', () {
    final r = PointsTransferResult.fromJson(const {});
    expect(r.transferNo, '');
    expect(r.toPhone, '');
    expect(r.toNickname, '');
    expect(r.points, '0');
    expect(r.balanceAfter, '0');
    expect(r.idempotent, isFalse);
  });
}
