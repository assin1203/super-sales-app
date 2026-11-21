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

/// 桩 /pos/newbie/confirmations 与 /pos/newbie/confirm：
/// 其它接口（首页 banner/公告/机器等）一律 500 走空态，且不触发 401 刷新/登出。
class _ConfirmAdapter implements HttpClientAdapter {
  _ConfirmAdapter({List<Map<String, dynamic>>? pending}) : pending = pending ?? [];

  /// 可变：确认成功后清空，模拟「自己确认过的机器后端不再返回」
  List<Map<String, dynamic>> pending;

  Map<String, dynamic> confirmResponse = const {
    'items': [],
    'settled': 2,
    'message': '已确认 2 台，2 台达标通过',
  };

  final List<RequestOptions> requests = [];

  Iterable<RequestOptions> get confirmRequests =>
      requests.where((r) => r.path.endsWith('/pos/newbie/confirm'));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final headers = {Headers.contentTypeHeader: [Headers.jsonContentType]};
    if (options.path.endsWith('/pos/newbie/confirmations')) {
      return ResponseBody.fromString(jsonEncode(pending), 200, headers: headers);
    }
    if (options.path.endsWith('/pos/newbie/confirm')) {
      pending = [];
      return ResponseBody.fromString(jsonEncode(confirmResponse), 200, headers: headers);
    }
    return ResponseBody.fromString(jsonEncode({'message': 'not stubbed'}), 500, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _item(String sn, String store, {String amount = '1280.00'}) => {
      'sn': sn,
      'model': '电签机',
      'merchantName': store,
      'amount': amount,
      'target': '1000.00',
      'dueAt': DateTime.now().add(const Duration(days: 7)).toUtc().toIso8601String(),
      'daysLeft': 7,
      'role': 'owner',
      'counterpartConfirmed': false,
    };

/// 登录态 + 主壳（ShellLayout 挂在 / 的 ShellRoute 上，冷启动即触发待确认检查）
Future<void> _pumpShell(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({
    'kqw.access_token': 'test-access',
    'kqw.refresh_token': 'test-refresh',
    'kqw.user': jsonEncode({'id': '1', 'phone': '13800000001', 'nickname': null, 'level': 1}),
  });
  final auth = AuthProvider(secureStore: MemorySecureStore());
  await auth.init();
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(theme: kqwTheme, routerConfig: appRouter(auth, enableDialogs: true)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('冷启动有多台待确认：弹多选框，默认全选，确认后按 sn 批量提交', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final original = api.dio.httpClientAdapter;
    final adapter = _ConfirmAdapter(pending: [_item('SN-A', '小李家便利店'), _item('SN-B', '王记超市')]);
    api.dio.httpClientAdapter = adapter;
    addTearDown(() => api.dio.httpClientAdapter = original);

    await _pumpShell(tester);

    expect(find.text('机器达标确认'), findsOneWidget);
    expect(find.text('小李家便利店 · SN-A'), findsOneWidget);
    expect(find.text('王记超市 · SN-B'), findsOneWidget);
    expect(find.text('确认所选（2）'), findsOneWidget);

    // 流水已达门槛：不出现提示色文案
    expect(find.textContaining('流水未达门槛'), findsNothing);

    await tester.tap(find.text('确认所选（2）'));
    await tester.pumpAndSettle();

    final posted = adapter.confirmRequests.toList();
    expect(posted, hasLength(1));
    expect((posted.single.data as Map)['sns'], ['SN-A', 'SN-B']);
    expect(find.text('机器达标确认'), findsNothing, reason: '确认后关闭弹窗');
    expect(find.text('已确认 2 台，2 台达标通过'), findsOneWidget, reason: '汇总用后端 message');
  });

  testWidgets('取消勾选一台：只提交剩下那台', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final original = api.dio.httpClientAdapter;
    final adapter = _ConfirmAdapter(pending: [_item('SN-A', '小李家便利店'), _item('SN-B', '王记超市')]);
    api.dio.httpClientAdapter = adapter;
    addTearDown(() => api.dio.httpClientAdapter = original);

    await _pumpShell(tester);

    await tester.tap(find.text('王记超市 · SN-B'));
    await tester.pumpAndSettle();
    expect(find.text('确认所选（1）'), findsOneWidget);

    await tester.tap(find.text('确认所选（1）'));
    await tester.pumpAndSettle();

    expect((adapter.confirmRequests.single.data as Map)['sns'], ['SN-A']);
  });

  testWidgets('没有待确认机器：不弹窗', (tester) async {
    final original = api.dio.httpClientAdapter;
    final adapter = _ConfirmAdapter();
    api.dio.httpClientAdapter = adapter;
    addTearDown(() => api.dio.httpClientAdapter = original);

    await _pumpShell(tester);

    expect(find.text('机器达标确认'), findsNothing);
    expect(adapter.confirmRequests, isEmpty);
    expect(adapter.requests.where((r) => r.path.endsWith('/pos/newbie/confirmations')), isNotEmpty,
        reason: '冷启动要查一次');
  });

  testWidgets('点「稍后再说」：不发确认请求，回前台也不再弹（后端已过滤）', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final original = api.dio.httpClientAdapter;
    final adapter = _ConfirmAdapter(pending: [_item('SN-A', '小李家便利店')]);
    api.dio.httpClientAdapter = adapter;
    addTearDown(() => api.dio.httpClientAdapter = original);

    await _pumpShell(tester);
    expect(find.text('机器达标确认'), findsOneWidget);

    await tester.tap(find.text('稍后再说'));
    await tester.pumpAndSettle();
    expect(find.text('机器达标确认'), findsNothing);
    expect(adapter.confirmRequests, isEmpty);

    // 模拟用户自己已确认过：后端不再返回该机器，回前台也不该再弹
    adapter.pending = [];
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('机器达标确认'), findsNothing);
  });

  testWidgets('流水未达门槛：弹窗直接标出，确认后仍按后端口径提示', (tester) async {
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final original = api.dio.httpClientAdapter;
    final adapter = _ConfirmAdapter(pending: [_item('SN-A', '小李家便利店', amount: '128.00')]);
    adapter.confirmResponse = const {
      'items': [
        {'sn': 'SN-A', 'confirmed': true, 'settled': false, 'reason': 'not_reached', 'message': '双方已确认，但累计流水未达门槛，暂不通过'},
      ],
      'settled': 0,
      'message': '已确认 1 台，等待对方确认后自动达标',
    };
    api.dio.httpClientAdapter = adapter;
    addTearDown(() => api.dio.httpClientAdapter = original);

    await _pumpShell(tester);

    expect(find.textContaining('流水未达门槛'), findsOneWidget);

    await tester.tap(find.text('确认所选（1）'));
    await tester.pumpAndSettle();

    expect(find.text('机器达标确认'), findsNothing);
    expect(find.textContaining('未达门槛'), findsOneWidget);
  });
}
