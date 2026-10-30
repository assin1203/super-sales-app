import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kqw_app/core/api/team_api.dart';
import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/models/room_package.dart';
import 'package:kqw_app/features/team/enter_room_flow.dart';

/// 打桩 HTTP 适配器：按 path 返回预置 JSON，并记录请求。
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  List<RequestOptions> get enterRequests =>
      requests.where((r) => r.uri.path == '/team/rooms/enter').toList();

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

ResponseBody _json(Object payload, {int status = 200}) =>
    ResponseBody.fromString(
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

const _pkg = RoomPackage(
  id: '2',
  code: 'GOLD',
  name: '金牌房',
  entryPoints: 199,
);

/// 请求走真实 dio + 打桩 adapter，需要多帧推进。
Future<void> _pumpUntilLoaded(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// 入口页：触发入房流程，并把返回值写到屏上便于断言。
class _Launcher extends StatefulWidget {
  const _Launcher({required this.api, this.balance});

  final TeamApi api;
  final int? balance;

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  String _result = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () async {
              final r = await enterRoomFlow(
                context,
                pkg: _pkg,
                balance: widget.balance,
                api: widget.api,
              );
              setState(() => _result = r == null ? 'null' : r.roomId);
            },
            child: const Text('去入房'),
          ),
          Text('result=$_result'),
        ],
      ),
    );
  }
}

Widget _app(_FakeAdapter adapter, {int? balance}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) =>
            _Launcher(api: TeamApi(client: _client(adapter)), balance: balance),
      ),
      GoRoute(
        path: '/room/:id',
        builder: (_, state) => Scaffold(
          body: Text('房间详情 ${state.pathParameters['id']}'),
        ),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  testWidgets('确认进入后调 POST /team/rooms/enter 并跳房间详情', (tester) async {
    final adapter = _FakeAdapter(
      (options) => _json({
        'roomId': 9,
        'posNo': 3,
        'packageId': '2',
        'entryPoints': 199,
        'purchased': true,
        'captain': false,
        'uplineId': 88,
        'rebound': false,
      }),
    );
    await tester.pumpWidget(_app(adapter, balance: 880));

    await tester.tap(find.text('去入房'));
    await tester.pumpAndSettle();

    // 弹窗说明首次扣分 + 当前余额
    expect(find.text('进入房间'), findsOneWidget);
    expect(find.textContaining('199 积分'), findsWidgets);
    expect(find.textContaining('当前可用积分：880'), findsOneWidget);

    await tester.tap(find.text('确认进入'));
    await _pumpUntilLoaded(tester);
    await tester.pumpAndSettle();

    final req = adapter.enterRequests.single;
    expect(req.method, 'POST');
    expect((req.data as Map)['packageId'], '2');

    // 跳转 + 回执写回启动页
    expect(find.text('房间详情 9'), findsOneWidget);
    expect(find.text('result=9'), findsNothing); // 已经离开入口页
  });

  testWidgets('余额不足只软提示，仍然可以进入', (tester) async {
    final adapter = _FakeAdapter(
      (options) => _json({
        'roomId': 7,
        'posNo': 5,
        'packageId': '2',
        'entryPoints': 199,
        'purchased': true,
      }),
    );
    await tester.pumpWidget(_app(adapter, balance: 10));

    await tester.tap(find.text('去入房'));
    await tester.pumpAndSettle();

    expect(find.text('积分可能不足'), findsOneWidget);
    expect(find.textContaining('还差 189 积分'), findsOneWidget);

    await tester.tap(find.text('仍然进入'));
    await _pumpUntilLoaded(tester);
    await tester.pumpAndSettle();

    expect(adapter.enterRequests, hasLength(1));
    expect(find.text('房间详情 7'), findsOneWidget);
  });

  testWidgets('接口失败提示后端文案，弹窗不关闭也不跳转', (tester) async {
    final adapter = _FakeAdapter(
      (options) => _json(
        {'code': 40001, 'message': '您已在房间中，请等待本房间结算后再进入'},
        status: 400,
      ),
    );
    await tester.pumpWidget(_app(adapter, balance: 880));

    await tester.tap(find.text('去入房'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认进入'));
    await _pumpUntilLoaded(tester);

    expect(find.textContaining('您已在房间中'), findsOneWidget);
    // 弹窗还在，可再点一次
    expect(find.text('确认进入'), findsOneWidget);
    expect(find.text('房间详情 9'), findsNothing);
  });

  testWidgets('取消不发请求', (tester) async {
    final adapter = _FakeAdapter((options) => _json(const {}));
    await tester.pumpWidget(_app(adapter, balance: 880));

    await tester.tap(find.text('去入房'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(adapter.enterRequests, isEmpty);
    // 取消后流程返回 null，仍停在入口页
    expect(find.text('result=null'), findsOneWidget);
  });
}
