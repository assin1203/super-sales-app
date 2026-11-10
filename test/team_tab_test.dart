import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kqw_app/core/api/team_api.dart';
import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/theme.dart';
import 'package:kqw_app/features/team/team_tab.dart';

/// 打桩 HTTP 适配器：按 path 返回预置 JSON。
class _Adapter implements HttpClientAdapter {
  _Adapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

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

Map<String, dynamic> _seat(int seatNo, {String? nickname}) => {
      'seatNo': seatNo,
      'userId': nickname == null ? null : '$seatNo',
      'nickname': nickname,
      'avatar': null,
      'phone': nickname == null ? '' : '1380000000$seatNo',
      'contribution': nickname == null ? '0' : '2',
      'isSelf': false,
      'isLeader': seatNo == 1,
      'joinedAt': nickname == null ? null : '2026-11-01T10:00:00Z',
    };

Map<String, dynamic> _room({
  required int id,
  required int status,
  required int? level,
  String? endedAt,
}) =>
    {
      'id': '$id',
      'roomNo': 'R$id',
      'status': status,
      'statusName': switch (status) {
        0 => '筹备中',
        1 => '进行中',
        _ => '已结束',
      },
      'round': 1,
      'level': level,
      'leaderNickname': '队长',
      'memberCount': 1,
      'rewardPool': '1200',
      'myPosition': 1,
      if (endedAt != null) 'endedAt': endedAt,
      'positions': [_seat(1, nickname: '队长'), _seat(2)],
    };

/// 渲染团队页并推进到数据就绪（真实 dio + 打桩 adapter）。
///
/// 用 360dp 宽 / 2400dp 高的画布：与真机最小宽度一致，便于同时断言
/// 溢出与「上下顺序」，不用在测试里反复滚动。
Future<void> _pumpTeamTab(
  WidgetTester tester,
  List<Map<String, dynamic>> rooms, {
  List<Map<String, dynamic>> waitQueue = const [],
}) async {
  tester.view.physicalSize = const Size(360, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final adapter = _Adapter((options) {
    switch (options.uri.path) {
      case '/team/rooms':
        return _json({
          'items': rooms,
          'total': rooms.length,
          'pageNum': 1,
          'pageSize': 100,
        });
      case '/team/wait-queue':
        return _json({'items': waitQueue, 'total': waitQueue.length});
      default:
        return _json(
          {'code': 40000, 'message': 'unexpected ${options.uri.path}'},
          status: 404,
        );
    }
  });

  final api = TeamApi(
    client: ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'http://test.local'))
        ..httpClientAdapter = adapter,
    ),
  );

  await tester.pumpWidget(
    MaterialApp(theme: kqwTheme, home: TeamTab(api: api)),
  );
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  testWidgets('L1 选项卡：筹备中在上，已结束按结束时间倒序', (tester) async {
    await _pumpTeamTab(tester, [
      _room(id: 11, status: 0, level: 1),
      _room(id: 12, status: 2, level: 1, endedAt: '2026-11-09T12:00:00Z'),
      _room(id: 10, status: 2, level: 1, endedAt: '2026-11-01T12:00:00Z'),
    ]);

    // 两个等级选项卡
    expect(find.widgetWithText(Tab, 'L1'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'L2'), findsOneWidget);

    // 分区标题 + 房间都在（「已结束」= 分区标题 1 + 两间房的状态标签 2）
    expect(find.text('我筹备中的房间'), findsOneWidget);
    expect(find.text('已结束'), findsNWidgets(3));
    expect(find.text('房间 R11'), findsOneWidget);
    expect(find.text('房间 R12'), findsOneWidget);
    expect(find.text('房间 R10'), findsOneWidget);

    // 筹备中在已结束之上
    expect(_top(tester, '房间 R11'), lessThan(_top(tester, '房间 R12')));
    // 已结束按结束时间倒序：11-09 在 11-01 之前
    expect(_top(tester, '房间 R12'), lessThan(_top(tester, '房间 R10')));
    // 已结束房间带结束时间行
    expect(find.textContaining('结束于'), findsNWidgets(2));

    // 360dp 窄屏渲染不溢出
    expect(tester.takeException(), isNull);
  });

  testWidgets('切换 L2 选项卡只显示 L2 的房间', (tester) async {
    await _pumpTeamTab(tester, [
      _room(id: 11, status: 0, level: 1),
      _room(id: 20, status: 0, level: 2),
    ]);

    expect(find.text('房间 R11'), findsOneWidget);
    expect(find.text('房间 R20'), findsNothing);

    await tester.tap(find.widgetWithText(Tab, 'L2'));
    await tester.pumpAndSettle();

    expect(find.text('房间 R20'), findsOneWidget);
    expect(find.text('房间 R11'), findsNothing);
  });

  testWidgets('已结束房间缺结束时间时按 id 倒序', (tester) async {
    await _pumpTeamTab(tester, [
      _room(id: 19, status: 2, level: 1),
      _room(id: 21, status: 2, level: 1),
    ]);

    expect(find.text('房间 R21'), findsOneWidget);
    expect(find.text('房间 R19'), findsOneWidget);
    expect(_top(tester, '房间 R21'), lessThan(_top(tester, '房间 R19')));
    // 没有结束时间就明确提示，不假装有
    expect(find.text('结束时间未记录'), findsNWidgets(2));
  });

  testWidgets('未定级房间落进「其他」选项卡，不会凭空消失', (tester) async {
    await _pumpTeamTab(tester, [
      _room(id: 11, status: 0, level: 1),
      _room(id: 30, status: 0, level: null),
    ]);

    expect(find.widgetWithText(Tab, '其他'), findsOneWidget);
    expect(find.text('房间 R30'), findsNothing);

    await tester.tap(find.widgetWithText(Tab, '其他'));
    await tester.pumpAndSettle();

    expect(find.text('房间 R30'), findsOneWidget);
    expect(find.text('房间 R11'), findsNothing);
  });

  testWidgets('进行中的房间不在这两个分区里出现', (tester) async {
    await _pumpTeamTab(tester, [
      _room(id: 11, status: 0, level: 1),
      _room(id: 40, status: 1, level: 1),
    ]);

    expect(find.text('房间 R11'), findsOneWidget);
    expect(find.text('房间 R40'), findsNothing);
  });

  testWidgets('接口失败给出错误态与重试，不白屏', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final adapter = _Adapter(
      (options) => _json(
        {'code': 50001, 'message': '服务繁忙，请稍后再试'},
        status: 500,
      ),
    );
    final api = TeamApi(
      client: ApiClient(
        dio: Dio(BaseOptions(baseUrl: 'http://test.local'))
          ..httpClientAdapter = adapter,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(theme: kqwTheme, home: TeamTab(api: api)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('加载失败'), findsOneWidget);
    expect(find.textContaining('服务繁忙'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('候补队列卡保留在选项卡内容底部', (tester) async {
    await _pumpTeamTab(
      tester,
      [_room(id: 11, status: 0, level: 1)],
      waitQueue: [
        {
          'position': 1,
          'userId': '7',
          'nickname': '候补A',
          'avatar': null,
          'level': 2,
          'queuedAt': '2026-11-09T10:00:00Z',
          'estimatedAt': null,
        },
      ],
    );

    expect(find.text('候补队列'), findsOneWidget);
    expect(find.text('候补A'), findsOneWidget);
    expect(find.text('1 人排队'), findsOneWidget);
  });
}
