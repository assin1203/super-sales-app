import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kqw_app/core/api/team_api.dart';
import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/auth_provider.dart';
import 'package:kqw_app/core/models/team_room.dart';
import 'package:kqw_app/core/theme.dart';
import 'package:kqw_app/features/team/room_detail_view.dart';
import 'package:kqw_app/features/team/team_tab.dart';

import 'support/memory_secure_store.dart';

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
  String? startedAt,
  String? firstContributionUserId,
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
      if (startedAt != null) 'startedAt': startedAt,
      if (firstContributionUserId != null)
        'firstContributionUserId': firstContributionUserId,
      'positions': [_seat(1, nickname: '队长'), _seat(2)],
    };

/// 用本地用户快照造登录态：`kqw.user` 在 [AuthProvider.init] 里直接恢复，
/// 不需要网络与平台通道（安全存储注入内存实现）。
Future<AuthProvider> _authWithUser(Map<String, dynamic>? user) async {
  SharedPreferences.setMockInitialValues(
    user == null ? {} : {'kqw.user': jsonEncode(user)},
  );
  final auth = AuthProvider(secureStore: MemorySecureStore());
  await auth.init();
  return auth;
}

/// 渲染团队页并推进到数据就绪（真实 dio + 打桩 adapter）。
///
/// 用 360dp 宽 / 2400dp 高的画布：与真机最小宽度一致，便于同时断言
/// 溢出与「上下顺序」，不用在测试里反复滚动。
Future<void> _pumpTeamTab(
  WidgetTester tester,
  List<Map<String, dynamic>> rooms, {
  List<Map<String, dynamic>> waitQueue = const [],
  Map<String, dynamic>? user,
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

  final client = ApiClient(
    dio: Dio(BaseOptions(baseUrl: 'http://test.local'))
      ..httpClientAdapter = adapter,
  );

  final auth = await _authWithUser(user);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(theme: kqwTheme, home: TeamTab(api: TeamApi(client: client))),
    ),
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
      _room(
        id: 12,
        status: 2,
        level: 1,
        startedAt: '2026-11-01T02:00:00Z',
        endedAt: '2026-11-09T12:00:00Z',
      ),
      _room(
        id: 10,
        status: 2,
        level: 1,
        startedAt: '2026-10-20T02:00:00Z',
        endedAt: '2026-11-01T12:00:00Z',
      ),
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
    // 已结束房间同时给出开始与完成两个时间
    expect(find.textContaining('开始于'), findsNWidgets(2));
    expect(find.textContaining('完成于'), findsNWidgets(2));

    // 360dp 窄屏渲染不溢出
    expect(tester.takeException(), isNull);
  });

  testWidgets('L1/L2 选项卡带上各自上线昵称', (tester) async {
    await _pumpTeamTab(
      tester,
      [_room(id: 11, status: 0, level: 1)],
      user: {
        'id': '1',
        'phone': '13800000001',
        'nickname': '我',
        'level': 1,
        'lv1ReferrerNickname': '张三',
        'lv2ReferrerNickname': '李四',
      },
    );

    expect(find.widgetWithText(Tab, 'L1 张三'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'L2 李四'), findsOneWidget);
  });

  testWidgets('上线没有昵称时选项卡退回纯 L1/L2', (tester) async {
    await _pumpTeamTab(
      tester,
      [_room(id: 11, status: 0, level: 1)],
      user: {'id': '1', 'phone': '13800000001', 'level': 1},
    );

    expect(find.widgetWithText(Tab, 'L1'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'L2'), findsOneWidget);
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
    // 没有时间就明确提示，不假装有
    expect(find.text('开始时间未记录'), findsNWidgets(2));
    expect(find.text('完成时间未记录'), findsNWidgets(2));
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

  testWidgets('已结束房间：最先拿到贡献值的成员头像带皇冠', (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Map<String, dynamic> seat(int seatNo, String contribution) => {
          'seatNo': seatNo,
          'userId': '$seatNo',
          'nickname': '成员$seatNo',
          'avatar': null,
          'phone': '138000000$seatNo',
          'contribution': contribution,
          'isSelf': false,
          'isLeader': seatNo == 1,
          'joinedAt': '2026-11-01T10:00:00Z',
        };

    final room = TeamRoom.fromJson({
      'id': '12',
      'roomNo': 'R12',
      'status': 2,
      'statusName': '已结束',
      'round': 1,
      'level': 1,
      'leaderNickname': '成员1',
      'memberCount': 3,
      'rewardPool': '900',
      'myPosition': 1,
      'startedAt': '2026-11-01T02:00:00Z',
      'endedAt': '2026-11-09T12:00:00Z',
      // 座位 2 虽然后来的贡献值更高，但最早一条分红归座位 2 之外的人
      'firstContributionUserId': '3',
      'positions': [seat(1, '5'), seat(2, '9'), seat(3, '1')],
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: kqwTheme,
        home: Scaffold(
          body: SingleChildScrollView(child: RoomDetailView(room: room)),
        ),
      ),
    );
    await tester.pump();

    // 只有「最先拿到贡献值」的那一个座位带皇冠，不是贡献值最高的座位
    expect(find.text('👑'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('未结束房间不加皇冠（后端也不会下发该标识）', (tester) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final room = TeamRoom.fromJson({
      'id': '11',
      'roomNo': 'R11',
      'status': 0,
      'statusName': '筹备中',
      'round': 1,
      'level': 1,
      'memberCount': 1,
      'rewardPool': '300',
      'positions': [
        {
          'seatNo': 1,
          'userId': '1',
          'nickname': '成员1',
          'contribution': '5',
          'isSelf': false,
          'isLeader': true,
        },
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: kqwTheme,
        home: Scaffold(
          body: SingleChildScrollView(child: RoomDetailView(room: room)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('👑'), findsNothing);
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

    final auth = await _authWithUser(null);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(theme: kqwTheme, home: TeamTab(api: api)),
      ),
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
