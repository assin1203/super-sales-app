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
import 'package:kqw_app/core/theme.dart';

import 'support/memory_secure_store.dart';

/// 桩消息列表/详情、已读、升级提示与升级二选一，其余接口 500。
class _InviteAdapter implements HttpClientAdapter {
  _InviteAdapter({this.prompt, this.upgradeMessage = true});

  /// 升级提示数据；null = 后端返回空体（条件已消失）
  Map<String, dynamic>? prompt;

  /// true = 列表里那条消息是 UPGRADE_PROMPT，false = 普通系统通知
  bool upgradeMessage;

  final List<RequestOptions> requests = [];
  int listCalls = 0;
  final List<String> readIds = [];

  Iterable<RequestOptions> get choiceRequests =>
      requests.where((r) => r.path.endsWith('/team/upgrade-prompt/choice'));

  Map<String, dynamic> get _message => {
        'id': '9',
        'type': upgradeMessage ? 'UPGRADE_PROMPT' : 'SYSTEM',
        'typeName': upgradeMessage ? '升级邀请' : '系统通知',
        'title': upgradeMessage ? '您有一份升级邀请' : '系统维护通知',
        'content': '查看并选择是否升级到更高档位房间',
        'read': false,
        'createdAt': DateTime(2026, 11, 21, 9).toIso8601String(),
      };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final headers = {Headers.contentTypeHeader: [Headers.jsonContentType]};
    final path = options.path;

    // choice 必须先判：它的路径是 prompt 的子路径
    if (path.endsWith('/team/upgrade-prompt/choice')) {
      prompt = null; // 处理完就不再给提示
      return ResponseBody.fromString(
        jsonEncode({
          'choice': 'upgrade',
          'unfrozenRewards': 2,
          'toReferrer': 0,
          'toSelf': 0,
          'message': '升级成功，2 台机器的冻结奖励已发放到您的账户',
        }),
        200,
        headers: headers,
      );
    }
    if (path.endsWith('/team/upgrade-prompt')) {
      if (prompt == null) return ResponseBody.fromString('', 200, headers: headers);
      return ResponseBody.fromString(jsonEncode(prompt), 200, headers: headers);
    }
    if (path.endsWith('/message/list')) {
      listCalls++;
      return ResponseBody.fromString(
        jsonEncode({
          'list': [_message],
          'total': 1,
          'pageNum': 1,
          'pageSize': 20,
          'unread': 1,
        }),
        200,
        headers: headers,
      );
    }
    if (path.endsWith('/message/unread-count')) {
      return ResponseBody.fromString(jsonEncode({'unread': 1}), 200, headers: headers);
    }
    if (path.endsWith('/message/read')) {
      final body = (options.data as Map).cast<String, dynamic>();
      readIds.addAll((body['ids'] as List).cast<String>());
      return ResponseBody.fromString(jsonEncode({'ok': true}), 200, headers: headers);
    }
    if (path.endsWith('/message/9')) {
      return ResponseBody.fromString(jsonEncode(_message), 200, headers: headers);
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

Map<String, dynamic> _prompt() => {
      'level': 0,
      'targetLevel': 1,
      'packageId': '1',
      'packageCode': 'BASIC',
      'packageName': '200 档',
      'entryPoints': 200,
      'balance': 300,
      'pendingRewardPoints': 200,
      'pendingMachines': 2,
      'canUpgrade': true,
      'shortfall': 0,
    };

_InviteAdapter _useAdapter(WidgetTester tester, _InviteAdapter adapter) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final original = api.dio.httpClientAdapter;
  api.dio.httpClientAdapter = adapter;
  addTearDown(() => api.dio.httpClientAdapter = original);
  return adapter;
}

/// 登录态 + 真路由，直接落在消息列表或详情上。
Future<void> _pumpRoute(WidgetTester tester, String location) async {
  SharedPreferences.setMockInitialValues({
    'kqw.access_token': 'test-access',
    'kqw.refresh_token': 'test-refresh',
    'kqw.user': jsonEncode({'id': '1', 'phone': '13800000001', 'nickname': null, 'level': 1}),
  });
  final auth = AuthProvider(secureStore: MemorySecureStore());
  await auth.init();

  // 自动弹窗默认关闭，这里只验证「点消息才弹」的链路
  final router = appRouter(auth);
  router.go(location);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(theme: kqwTheme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('列表里升级邀请用 typeName 标签与「去选择」，不是普通「查看详情」', (tester) async {
    _useAdapter(tester, _InviteAdapter(prompt: _prompt()));
    await _pumpRoute(tester, '/messages');

    expect(find.text('升级邀请'), findsOneWidget);
    expect(find.text('去选择'), findsOneWidget);
    expect(find.text('查看详情'), findsNothing);
    expect(find.text('您有一份升级邀请'), findsOneWidget);
  });

  testWidgets('普通系统通知保持原样：标签与「查看详情」', (tester) async {
    _useAdapter(tester, _InviteAdapter(prompt: _prompt(), upgradeMessage: false));
    await _pumpRoute(tester, '/messages');

    expect(find.text('系统通知'), findsOneWidget);
    expect(find.text('查看详情'), findsOneWidget);
    expect(find.text('去选择'), findsNothing);
  });

  testWidgets('点升级邀请：现拉提示再弹窗，提交 upgrade 后标记已读并刷新列表', (tester) async {
    final adapter = _useAdapter(tester, _InviteAdapter(prompt: _prompt()));
    await _pumpRoute(tester, '/messages');
    final listCallsBefore = adapter.listCalls;

    await tester.tap(find.text('您有一份升级邀请'));
    await tester.pumpAndSettle();

    // 点击时现拉一次提示，而不是用消息里带的快照
    expect(
      adapter.requests.where((r) => r.path.endsWith('/team/upgrade-prompt')),
      isNotEmpty,
    );
    expect(find.text('是否升级'), findsOneWidget);

    await tester.tap(find.text('立即升级'));
    await tester.pumpAndSettle();

    expect((adapter.choiceRequests.single.data as Map)['choice'], 'upgrade');
    expect(find.text('是否升级'), findsNothing, reason: '提交后关闭弹窗');
    expect(adapter.readIds, contains('9'), reason: '处理完把这条消息标记已读');
    expect(adapter.listCalls, listCallsBefore + 1, reason: '处理完刷新消息列表');
  });

  testWidgets('点升级邀请但提示为空：不弹窗，提示已失效并刷新列表', (tester) async {
    final adapter = _useAdapter(tester, _InviteAdapter()); // prompt 为 null
    await _pumpRoute(tester, '/messages');
    final listCallsBefore = adapter.listCalls;

    await tester.tap(find.text('您有一份升级邀请'));
    await tester.pumpAndSettle();

    expect(find.text('是否升级'), findsNothing, reason: '条件已消失不弹空窗');
    expect(find.text('升级条件已变化，这条消息已失效'), findsOneWidget);
    expect(adapter.choiceRequests, isEmpty);
    expect(adapter.readIds, contains('9'));
    expect(adapter.listCalls, listCallsBefore + 1);
  });

  testWidgets('详情页显示升级邀请徽标与「立即处理」，点击同样弹窗', (tester) async {
    _useAdapter(tester, _InviteAdapter(prompt: _prompt()));
    await _pumpRoute(tester, '/messages/9');

    expect(find.text('升级邀请'), findsOneWidget);
    expect(find.text('立即处理（升级 / 放弃）'), findsOneWidget);

    await tester.tap(find.text('立即处理（升级 / 放弃）'));
    await tester.pumpAndSettle();

    expect(find.text('是否升级'), findsOneWidget);
  });
}
