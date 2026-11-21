import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/app_router.dart';
import 'package:kqw_app/core/auth_provider.dart';
import 'package:kqw_app/core/models/machine.dart';
import 'package:kqw_app/core/theme.dart';

import 'support/memory_secure_store.dart';

/// 只桩 /pos/machines：首页其他区块（banner/公告/档位）一律失败走空态，
/// 不影响「机器达标监控」的断言；用 500 而非 401，避免触发 token 刷新/登出。
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.payload);

  final Map<String, dynamic> payload;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final headers = {Headers.contentTypeHeader: [Headers.jsonContentType]};
    if (options.path.contains('/pos/machines')) {
      return ResponseBody.fromString(jsonEncode(payload), 200, headers: headers);
    }
    return ResponseBody.fromString(
      jsonEncode({'message': 'not stubbed'}),
      500,
      headers: headers,
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 按 pageNum 返回不同页：用来验证首页不会只看第一页
class _PagingAdapter implements HttpClientAdapter {
  _PagingAdapter(this.pages);

  final Map<int, Map<String, dynamic>> pages;
  final List<int> requested = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final headers = {Headers.contentTypeHeader: [Headers.jsonContentType]};
    if (!options.path.contains('/pos/machines')) {
      return ResponseBody.fromString(
        jsonEncode({'message': 'not stubbed'}),
        500,
        headers: headers,
      );
    }
    final pageNum =
        int.tryParse('${options.queryParameters['pageNum'] ?? 1}') ?? 1;
    requested.add(pageNum);
    return ResponseBody.fromString(
      jsonEncode(pages[pageNum] ?? {'items': <dynamic>[], 'total': 0}),
      200,
      headers: headers,
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 起首页：只桩 /pos/machines，其余接口一律 500 走空态
Future<void> _pumpHome(WidgetTester tester, HttpClientAdapter adapter) async {
  final original = api.dio.httpClientAdapter;
  api.dio.httpClientAdapter = adapter;
  addTearDown(() => api.dio.httpClientAdapter = original);

  SharedPreferences.setMockInitialValues({
    'kqw.access_token': 'test-access',
    'kqw.refresh_token': 'test-refresh',
    'kqw.user': jsonEncode({
      'id': '1',
      'phone': '13800000001',
      'nickname': null,
      'level': 1,
    }),
  });
  final auth = AuthProvider(secureStore: MemorySecureStore());
  await auth.init();
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(theme: kqwTheme, routerConfig: appRouter(auth)),
    ),
  );
  await tester.pumpAndSettle();
}

String _iso(DateTime t) => t.toUtc().toIso8601String();

void main() {
  group('Machine 达标监控字段', () {
    test('解析门店名称、窗口天数、达标积分等新字段', () {
      final machine = Machine.fromJson({
        'sn': '000007392545844555',
        'model': '电签机',
        'merchantName': ' 沈阳君临百货商店 ',
        'installedAt': '2026-11-15T14:55:37.000Z',
        'dueAt': '2026-12-10T14:55:37.000Z',
        'windowDays': 25,
        'taskSelfPoints': '100',
        'newbieStatus': 2,
        'newbieStatusName': '审核中',
        'progress': {'amount': '0.00', 'target': '1000.00', 'daysLeft': 25},
      });
      expect(machine.merchantName, '沈阳君临百货商店');
      expect(machine.windowDays, 25);
      expect(machine.taskSelfPoints, '100');
      expect(machine.installedAt, isNotNull);
      expect(machine.dueAt, isNotNull);
    });

    test('门店名缺失/空串按无处理', () {
      final machine = Machine.fromJson({
        'sn': 'A',
        'model': '电签机',
        'merchantName': '  ',
        'progress': {'amount': '0', 'target': '1000'},
      });
      expect(machine.merchantName, isNull);
    });

    test('未达标且窗口未过期才进监控列表', () {
      Machine build({
        String amount = '0',
        String target = '1000',
        bool expired = false,
        int newbieStatus = 1,
      }) =>
          Machine.fromJson({
            'sn': 'A',
            'model': '电签机',
            'newbieStatus': newbieStatus,
            'progress': {
              'amount': amount,
              'target': target,
              'expired': expired,
            },
          });

      expect(build().needsMonitor, isTrue, reason: '没刷够、窗口内 → 监控');
      expect(build(amount: '1000').needsMonitor, isFalse, reason: '已刷满 → 不再监控');
      expect(build(expired: true).needsMonitor, isFalse, reason: '窗口已过期 → 不再监控');
      // 人工结算过但流水没到门槛：不排除会永久占一张「0天 / 累计0元」的卡
      expect(build(newbieStatus: 3).needsMonitor, isFalse, reason: '已完成 → 不再监控');
      // 历史机器没挂任务窗口时 target 下发为 0：既不算达标，也不该占监控位
      expect(build(target: '0').needsMonitor, isFalse, reason: '无门槛 → 不再监控');
      expect(build(target: '0').reachedTarget, isFalse, reason: '无门槛不算达标');
    });

    test('剩余天数按截止时间实时算，过期归 0', () {
      Machine withDue(DateTime due) => Machine.fromJson({
            'sn': 'A',
            'model': '电签机',
            'newbieStatus': 1,
            'dueAt': _iso(due),
            'windowDays': 25,
            'progress': {'amount': '0', 'target': '1000', 'daysLeft': 25},
          });

      // 接口下发 daysLeft=25 是响应时刻的快照，页面打开时按 dueAt 重算
      expect(withDue(DateTime.now().add(const Duration(days: 10))).daysLeftToReach, 10);
      expect(withDue(DateTime.now().subtract(const Duration(days: 1))).daysLeftToReach, 0);
    });

    test('无截止时间时按装机日 + 窗口天数推算，都缺才退回接口值', () {
      final installed = Machine.fromJson({
        'sn': 'A',
        'model': '电签机',
        'newbieStatus': 1,
        'installedAt': _iso(DateTime.now().add(const Duration(seconds: 1))),
        'windowDays': 25,
        'progress': {'amount': '0', 'target': '1000', 'daysLeft': 99},
      });
      expect(installed.daysLeftToReach, 25);

      final legacy = Machine.fromJson({
        'sn': 'A',
        'model': '电签机',
        'newbieStatus': 1,
        'progress': {'amount': '0', 'target': '1000', 'daysLeft': 7},
      });
      expect(legacy.daysLeftToReach, 7, reason: '历史机器没挂窗口，退回接口下发值');
    });

    test('MachineDetail 一并转发新增字段，避免子类与基类漂移', () {
      final detail = MachineDetail.fromJson({
        'sn': 'A',
        'model': '电签机',
        'merchantName': '沈阳君临百货商店',
        'installedAt': '2026-11-15T14:55:37.000Z',
        'dueAt': '2026-12-10T14:55:37.000Z',
        'windowDays': 25,
        'taskSelfPoints': '100',
        'newbieStatus': 2,
        'newbieStatusName': '审核中',
        'progress': {'amount': '0.00', 'target': '1000.00', 'daysLeft': 25},
      });
      expect(detail.merchantName, '沈阳君临百货商店');
      expect(detail.windowDays, 25);
      expect(detail.taskSelfPoints, '100');
      expect(detail.installedAt, isNotNull);
      expect(detail.dueAt, isNotNull);
      expect(detail.daysLeftToReach, greaterThan(0), reason: '基类的剩余天数口径也要能用');
    });

    test('待确认条目：无门槛不误报已达标，剩余天数与首页同口径', () {
      NewbieConfirmPending build({
        String amount = '0',
        String target = '1000',
        String? dueAt,
      }) =>
          NewbieConfirmPending.fromJson({
            'sn': 'A',
            'model': '电签机',
            if (dueAt != null) 'dueAt': dueAt,
            'amount': amount,
            'target': target,
            'daysLeft': 9,
          });

      expect(build().reachedTarget, isFalse);
      expect(build(amount: '1000').reachedTarget, isTrue);
      // target 缺省时 fromJson 兜成 '0'：0 >= 0 不能算达标，否则会催用户去确认
      expect(build(target: '0').reachedTarget, isFalse);
      expect(build(amount: '0', target: '0').reachedTarget, isFalse);

      expect(build().daysLeftLive, 9, reason: '没有截止时间才退回接口下发值');
      expect(
        build(dueAt: _iso(DateTime.now().add(const Duration(days: 4)))).daysLeftLive,
        4,
      );
      expect(
        build(dueAt: _iso(DateTime.now().subtract(const Duration(days: 2))))
            .daysLeftLive,
        0,
        reason: '已过期归 0，不出现负数天数',
      );
    });
  });

  testWidgets('首页只展示未达标机器，剩余天数按截止时间重算', (tester) async {
    // 卡片较宽：默认 800x600 会把第二张卡挤出构建范围
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final payload = {
      'items': [
        {
          'sn': '000007392545844555',
          'model': '电签机',
          'merchantName': '沈阳君临百货商店',
          'installedAt': _iso(now.subtract(const Duration(days: 15))),
          'dueAt': _iso(now.add(const Duration(days: 10))),
          'windowDays': 25,
          'taskSelfPoints': '100',
          'newbieStatus': 1,
          'newbieStatusName': '进行中',
          // 接口下发的 daysLeft 是旧快照（25），页面应显示重算后的 10 天
          'progress': {
            'amount': '0.00',
            'target': '1000.00',
            'daysLeft': 25,
            'expired': false,
          },
        },
        {
          'sn': '00000739825',
          'model': '电签机',
          'merchantName': '王记便利店',
          'installedAt': _iso(now.subtract(const Duration(days: 42))),
          'dueAt': _iso(now.add(const Duration(days: 3))),
          'windowDays': 45,
          'taskSelfPoints': '800',
          'newbieStatus': 2,
          'newbieStatusName': '审核中',
          'progress': {
            'amount': '500.00',
            'target': '3000.00',
            'daysLeft': 3,
            'expired': false,
          },
        },
        {
          // 已刷满：不显示
          'sn': 'DONE0001',
          'model': '电签机',
          'merchantName': '已达标门店',
          'taskSelfPoints': '100',
          'newbieStatus': 3,
          'newbieStatusName': '已完成',
          'progress': {
            'amount': '1000.00',
            'target': '1000.00',
            'daysLeft': 0,
            'expired': false,
          },
        },
        {
          // 窗口过期未达标：也不显示
          'sn': 'EXPIRED001',
          'model': '电签机',
          'merchantName': '过期门店',
          'taskSelfPoints': '100',
          'newbieStatus': 1,
          'newbieStatusName': '进行中',
          'progress': {
            'amount': '0.00',
            'target': '1000.00',
            'daysLeft': 0,
            'expired': true,
          },
        },
      ],
      'applies': <dynamic>[],
      'total': 4,
    };

    await _pumpHome(tester, _StubAdapter(payload));

    // 两张未达标卡各自编号，达标/过期的机器不占位
    expect(find.text('机器达标监控（1）'), findsOneWidget);
    expect(find.text('机器达标监控（2）'), findsOneWidget);
    expect(find.text('机器达标监控（3）'), findsNothing);
    expect(find.text('已达标门店'), findsNothing);
    expect(find.text('过期门店'), findsNothing);

    // 门店名 + 机号
    expect(find.text('沈阳君临百货商店'), findsOneWidget);
    expect(find.text('000007392545844555'), findsOneWidget);
    expect(find.text('王记便利店'), findsOneWidget);

    // 剩余天数按 dueAt 重算（第一台接口下发 25 天，实际还剩 10 天）
    expect(find.text('10天'), findsOneWidget);
    expect(find.text('3天'), findsOneWidget);

    // 底部达标规则文案取自机器快照
    expect(find.text('从装机之日起25天内刷卡累计1000元奖励100积分'), findsOneWidget);
    expect(find.text('从装机之日起45天内刷卡累计3000元奖励800积分'), findsOneWidget);
  });

  testWidgets('空态文案区分未绑定、全部达标与窗口已结束', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Map<String, dynamic> machine({
      required String sn,
      String amount = '0.00',
      bool expired = false,
    }) =>
        {
          'sn': sn,
          'model': '电签机',
          'merchantName': '门店$sn',
          'newbieStatus': 1,
          'newbieStatusName': '进行中',
          'windowDays': 25,
          'progress': {
            'amount': amount,
            'target': '1000.00',
            'daysLeft': expired ? 0 : 25,
            'expired': expired,
          },
        };

    // 1) 一台都没有
    await _pumpHome(
      tester,
      _StubAdapter({'items': <dynamic>[], 'total': 0}),
    );
    expect(find.text('未绑定机器'), findsOneWidget);

    // 2) 有机器且都刷满了
    await _pumpHome(
      tester,
      _StubAdapter({
        'items': [machine(sn: 'REACHED', amount: '1000.00')],
        'total': 1,
      }),
    );
    expect(find.text('机器均已达标'), findsOneWidget);

    // 3) 窗口过期但没达标：不能说成「均已达标」（那等于把丢了奖励说成好消息）
    await _pumpHome(
      tester,
      _StubAdapter({
        'items': [machine(sn: 'EXPIRED', expired: true)],
        'total': 1,
      }),
    );
    expect(find.text('达标窗口已结束'), findsOneWidget);
    expect(find.text('机器均已达标'), findsNothing);
  });

  testWidgets('机器超过一页时按 total 续页收齐', (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Map<String, dynamic> card(String sn) => {
          'sn': sn,
          'model': '电签机',
          'merchantName': '门店$sn',
          'newbieStatus': 1,
          'newbieStatusName': '进行中',
          'windowDays': 25,
          'progress': {
            'amount': '0.00',
            'target': '1000.00',
            'daysLeft': 25,
            'expired': false,
          },
        };

    final adapter = _PagingAdapter({
      1: {
        'items': [for (var i = 1; i <= 20; i++) card('SN$i')],
        'total': 21,
      },
      2: {
        'items': [card('SN21')],
        'total': 21,
      },
    });
    await _pumpHome(tester, adapter);

    // 第 21 台只在第二页：不续页就会静默漏掉这台机器的达标窗口
    expect(adapter.requested, [1, 2]);
    // 页面上有两个 ListView（外层首页 + 内层监控卡），要显式指定外层再滚
    await tester.dragUntilVisible(
      find.text('机器达标监控（21）'),
      find.byType(ListView).first,
      const Offset(0, -300),
    );
    expect(find.text('机器达标监控（21）'), findsOneWidget);
  });
}
