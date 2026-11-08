import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kqw_app/core/api/points_api.dart';
import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/theme.dart';
import 'package:kqw_app/pages/points_center_page.dart';
import 'package:kqw_app/pages/points_transfer_page.dart';

/// 打桩的 HTTP 适配器：按 path 返回预置 JSON，并记录每次请求。
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  List<RequestOptions> get transferRequests =>
      requests.where((r) => r.uri.path == '/points/transfers').toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object payload, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

ApiClient _client(_FakeAdapter adapter) => ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'http://test.local'))
        ..httpClientAdapter = adapter,
    );

/// 请求走真实 dio + 打桩 adapter，结果在若干微任务后到；
/// 页面有 loading 动画不能 pumpAndSettle，这里小步多帧推进。
Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// 积分中心：概览 + 最近流水必须真渲染出接口数据。
void main() {
  testWidgets('积分中心渲染余额、等级与最近流水', (tester) async {
    final adapter = _FakeAdapter((options) {
      switch (options.uri.path) {
        case '/user/points':
          return _json({
            'balance': '880',
            'frozen': '20',
            'totalEarned': '1200',
            'totalSpent': '300',
            'level': 2,
            'levelName': '银卡会员',
          });
        case '/points/flows':
          return _json({
            'items': [
              {
                'id': '1',
                'flowType': 4,
                'typeName': '任务奖励',
                'delta': '100',
                'balanceAfter': '880',
                'bizNo': 'B1',
                'remark': '完成签到任务',
                'createdAt': '2026-10-27T10:00:00.000Z',
              },
              {
                'id': '2',
                'flowType': 5,
                'typeName': '商城兑换扣减',
                'delta': '-200',
                'balanceAfter': '780',
                'bizNo': 'B2',
                'remark': '兑换商品',
                'createdAt': '2026-10-26T10:00:00.000Z',
              },
            ],
            'total': 2,
            'pageNum': 1,
            'pageSize': 5,
          });
      }
      return _json({});
    });

    await tester.pumpWidget(MaterialApp(
      theme: kqwTheme,
      home: PointsCenterPage(api: PointsApi(client: _client(adapter))),
    ));
    await _pumpUntilLoaded(tester);

    expect(find.text('880'), findsOneWidget);
    expect(find.text('银卡会员'), findsOneWidget);
    expect(find.text('任务奖励'), findsOneWidget);
    expect(find.text('商城兑换扣减'), findsOneWidget);
    // 收入带符号、支出保留负号
    expect(find.text('+100'), findsOneWidget);
    expect(find.text('-200'), findsOneWidget);
    // 最近流水只预览，点「全部」才进完整列表
    expect(find.text('全部'), findsOneWidget);
  });

  testWidgets('积分中心请求失败时展示错误与重试', (tester) async {
    final adapter = _FakeAdapter((options) => _json(
          {'code': 60001, 'message': '积分服务暂不可用'},
          status: 500,
        ));

    await tester.pumpWidget(MaterialApp(
      theme: kqwTheme,
      home: PointsCenterPage(api: PointsApi(client: _client(adapter))),
    ));
    await _pumpUntilLoaded(tester);

    expect(find.text('重试'), findsOneWidget);
    // 失败时余额走空态兜底，不抛异常
    expect(find.text('0'), findsWidgets);
  });

  testWidgets('送积分提交手机号/积分/备注，成功后返回上一页', (tester) async {
    final adapter = _FakeAdapter((options) {
      switch (options.uri.path) {
        case '/user/points':
          return _json({
            'balance': '200',
            'frozen': '0',
            'totalEarned': '200',
            'totalSpent': '0',
          });
        case '/points/transfers':
          return _json({
            'transferNo': 'T20261027001',
            'toPhone': '13800138000',
            'toNickname': '小明',
            'points': '50',
            'balanceAfter': '150',
            'idempotent': false,
            'createdAt': '2026-10-27T10:00:00.000Z',
          });
      }
      return _json({});
    });
    final api = PointsApi(client: _client(adapter));

    await _openTransfer(tester, api);
    await _fillForm(tester, phone: '13800138000', points: '50', remark: '加油');
    await _submit(tester);

    final body = adapter.transferRequests.single.data as Map;
    expect(body['toPhone'], '13800138000');
    expect(body['points'], 50);
    expect(body['remark'], '加油');
    // 幂等键必传
    expect(body['requestNo'], isA<String>());
    expect((body['requestNo'] as String).length, greaterThanOrEqualTo(6));
    // 成功后已 pop 回宿主页
    expect(find.byType(PointsTransferPage), findsNothing);
  });

  testWidgets('失败重试复用同一幂等键，改输入后重新生成', (tester) async {
    var fail = true;
    final adapter = _FakeAdapter((options) {
      switch (options.uri.path) {
        case '/user/points':
          return _json({
            'balance': '200',
            'frozen': '0',
            'totalEarned': '200',
            'totalSpent': '0',
          });
        case '/points/transfers':
          if (fail) {
            return _json({'code': 60006, 'message': '可用积分不足'}, status: 400);
          }
          return _json({
            'transferNo': 'T20261027002',
            'toPhone': '13800138000',
            'points': '50',
            'balanceAfter': '150',
            'idempotent': true,
          });
      }
      return _json({});
    });
    final api = PointsApi(client: _client(adapter));

    await _openTransfer(tester, api);
    await _fillForm(tester, phone: '13800138000', points: '50');

    // 第一次：失败，提示后端文案
    await _submit(tester);
    expect(find.text('可用积分不足'), findsOneWidget);

    // 第二次：同参数重试，幂等键必须沿用
    fail = false;
    await _submit(tester);
    final bodies = adapter.transferRequests.map((r) => r.data as Map).toList();
    expect(bodies.length, 2);
    expect(bodies[0]['requestNo'], bodies[1]['requestNo']);

    // 第三次：改了积分，视为新意图 → 新幂等键
    // （成功后页面已 pop 回宿主页，重开一次；居中 Toast 也会盖住输入框，先等它消失）
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await _pumpUntilLoaded(tester);
    await tester.enterText(find.byType(TextFormField).at(0), '13800138000');
    await tester.enterText(find.byType(TextFormField).at(1), '30');
    await tester.pump();
    await _submit(tester);
    final last = adapter.transferRequests.last.data as Map;
    expect(last['requestNo'], isNot(bodies[0]['requestNo']));
    expect(last['points'], 30);
  });

  testWidgets('手机号格式与余额不足在本地就拦下，大额转让不再有单次上限', (tester) async {
    final adapter = _FakeAdapter((options) {
      if (options.uri.path == '/user/points') {
        return _json({
          'balance': '1000',
          'frozen': '0',
          'totalEarned': '1000',
          'totalSpent': '0',
        });
      }
      return _json({});
    });
    final api = PointsApi(client: _client(adapter));

    await _openTransfer(tester, api);

    await _fillForm(tester, phone: '1380013', points: '50');
    await tester.tap(find.widgetWithText(FilledButton, '确认赠送'));
    await tester.pump();
    expect(find.text('手机号格式不正确'), findsOneWidget);

    await _fillForm(tester, phone: '13800138000', points: '5000');
    await tester.tap(find.widgetWithText(FilledButton, '确认赠送'));
    await tester.pump();
    expect(find.textContaining('可用积分不足'), findsOneWidget);

    // 500 积分历史上会被单次上限拦下，现在只受可用余额约束 → 直接进确认弹窗
    await _fillForm(tester, phone: '13800138000', points: '500');
    await tester.tap(find.widgetWithText(FilledButton, '确认赠送'));
    await tester.pump();
    expect(find.text('确认赠送'), findsWidgets);

    // 前端校验阶段一个转让请求都没发出去
    expect(adapter.transferRequests, isEmpty);
  });
}

/// 从宿主页 push 送积分页（成功后页面自行 pop，需要真实 Navigator 栈）
Future<void> _openTransfer(WidgetTester tester, PointsApi api) async {
  await tester.pumpWidget(MaterialApp(
    theme: kqwTheme,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PointsTransferPage(api: api)),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  // 概览请求是 pending Future，pumpAndSettle 不会等它；余额没到会导致
  // 本地校验误判「可用积分不足」，必须多帧推进到数据渲染。
  await _pumpUntilLoaded(tester);
}

Future<void> _fillForm(
  WidgetTester tester, {
  required String phone,
  required String points,
  String remark = '',
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), phone);
  await tester.enterText(find.byType(TextFormField).at(1), points);
  await tester.enterText(find.byType(TextFormField).at(2), remark);
  await tester.pump();
}

/// 点主按钮 → 确认弹窗 → 确认，走到请求发出
Future<void> _submit(WidgetTester tester) async {
  // 上一次失败的居中 Toast 会盖住主按钮，等它 2s 自动消失再点
  await tester.pump(const Duration(seconds: 3));
  await tester.tap(find.widgetWithText(FilledButton, '确认赠送'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, '确认赠送'));
  await tester.pumpAndSettle();
}
