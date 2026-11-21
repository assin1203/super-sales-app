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

/// 桩 /team/upgrade-prompt、/team/upgrade-prompt/choice 与 /pos/newbie/confirmations：
/// 其余接口（首页 banner/公告/机器等）一律 500 走空态，不触发 401 刷新/登出。
class _UpgradeAdapter implements HttpClientAdapter {
  _UpgradeAdapter({this.prompt, this.confirmPending});

  /// 升级提示数据；null = 后端返回空体（不弹）
  Map<String, dynamic>? prompt;

  /// 待确认机器；null = 接口不 stub（500）
  List<Map<String, dynamic>>? confirmPending;

  Map<String, dynamic> choiceResponse = const {
    'choice': 'upgrade',
    'unfrozenRewards': 2,
    'toReferrer': 0,
    'toSelf': 0,
    'message': '升级成功，2 台机器的冻结奖励已发放到您的账户',
  };

  final List<RequestOptions> requests = [];

  Iterable<RequestOptions> get choiceRequests =>
      requests.where((r) => r.path.endsWith('/team/upgrade-prompt/choice'));

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final headers = {Headers.contentTypeHeader: [Headers.jsonContentType]};

    // choice 必须在 prompt 之前判断：前者路径是后者的子路径
    if (options.path.endsWith('/team/upgrade-prompt/choice')) {
      prompt = null; // 处理完不再弹
      return ResponseBody.fromString(jsonEncode(choiceResponse), 200, headers: headers);
    }
    if (options.path.endsWith('/team/upgrade-prompt')) {
      if (prompt == null) return ResponseBody.fromString('', 200, headers: headers);
      return ResponseBody.fromString(jsonEncode(prompt), 200, headers: headers);
    }
    if (options.path.endsWith('/pos/newbie/confirmations')) {
      if (confirmPending == null) {
        return ResponseBody.fromString(jsonEncode({'message': 'not stubbed'}), 500, headers: headers);
      }
      return ResponseBody.fromString(jsonEncode(confirmPending), 200, headers: headers);
    }
    return ResponseBody.fromString(jsonEncode({'message': 'not stubbed'}), 500, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _prompt({
  int pendingMachines = 2,
  int pendingRewardPoints = 200,
  int entryPoints = 200,
  int balance = 300,
  bool canUpgrade = true,
  int shortfall = 0,
  int targetLevel = 1,
  String packageName = '200 档',
}) =>
    {
      'level': 0,
      'targetLevel': targetLevel,
      'packageId': '$targetLevel',
      'packageCode': targetLevel == 1 ? 'BASIC' : 'ADVANCED',
      'packageName': packageName,
      'entryPoints': entryPoints,
      'balance': balance,
      'pendingRewardPoints': pendingRewardPoints,
      'pendingMachines': pendingMachines,
      'canUpgrade': canUpgrade,
      'shortfall': shortfall,
    };

Map<String, dynamic> _machine(String sn, String store) => {
      'sn': sn,
      'model': '电签机',
      'merchantName': store,
      'amount': '1280.00',
      'target': '1000.00',
      'dueAt': DateTime.now().add(const Duration(days: 7)).toUtc().toIso8601String(),
      'daysLeft': 7,
      'role': 'owner',
      'counterpartConfirmed': false,
    };

/// 登录态 + 主壳（ShellLayout 挂在 / 的 ShellRoute 上，冷启动即触发两个检查）
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

_UpgradeAdapter _useAdapter(WidgetTester tester, _UpgradeAdapter adapter) {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final original = api.dio.httpClientAdapter;
  api.dio.httpClientAdapter = adapter;
  addTearDown(() => api.dio.httpClientAdapter = original);
  return adapter;
}

void main() {
  testWidgets('冷启动有待定冻结奖励且积分够：弹升级提示，点「立即升级」提 upgrade', (tester) async {
    final adapter = _useAdapter(tester, _UpgradeAdapter(prompt: _prompt()));
    await _pumpShell(tester);

    expect(find.text('是否升级'), findsOneWidget);
    expect(find.textContaining('2 台机器'), findsOneWidget);
    expect(find.textContaining('合计 200 分'), findsOneWidget);
    expect(find.textContaining('进入「200 档」房间'), findsOneWidget);
    expect(find.textContaining('需消耗 200 积分'), findsOneWidget);

    await tester.tap(find.text('立即升级'));
    await tester.pumpAndSettle();

    final posted = adapter.choiceRequests.single;
    expect((posted.data as Map)['choice'], 'upgrade');
    expect(find.text('是否升级'), findsNothing, reason: '提交后关闭弹窗');
    expect(find.text('升级成功，2 台机器的冻结奖励已发放到您的账户'), findsOneWidget);
  });

  testWidgets('点「暂不升级」要二次确认，确认后提 decline', (tester) async {
    final adapter = _useAdapter(tester, _UpgradeAdapter(prompt: _prompt()));
    adapter.choiceResponse = const {
      'choice': 'decline',
      'unfrozenRewards': 0,
      'toReferrer': 2,
      'toSelf': 0,
      'message': '已放弃升级，2 台机器的冻结奖励已转给您的直接推荐人',
    };
    await _pumpShell(tester);

    await tester.tap(find.text('暂不升级'));
    await tester.pumpAndSettle();
    expect(find.text('放弃升级'), findsOneWidget);
    expect(find.textContaining('无法撤回'), findsOneWidget);
    expect(adapter.choiceRequests, isEmpty, reason: '确认前不发请求');

    await tester.tap(find.text('确定放弃'));
    await tester.pumpAndSettle();

    expect((adapter.choiceRequests.single.data as Map)['choice'], 'decline');
    expect(find.text('放弃升级'), findsNothing);
    expect(find.text('已放弃升级，2 台机器的冻结奖励已转给您的直接推荐人'), findsOneWidget);
  });

  testWidgets('二次确认点「取消」：不发请求，弹窗保持', (tester) async {
    final adapter = _useAdapter(tester, _UpgradeAdapter(prompt: _prompt()));
    await _pumpShell(tester);

    await tester.tap(find.text('暂不升级'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(adapter.choiceRequests, isEmpty);
    expect(find.text('是否升级'), findsOneWidget);
  });

  testWidgets('点「稍后再说」：不发请求，回前台仍会再弹', (tester) async {
    final adapter = _useAdapter(tester, _UpgradeAdapter(prompt: _prompt()));
    await _pumpShell(tester);
    expect(find.text('是否升级'), findsOneWidget);

    await tester.tap(find.text('稍后再说'));
    await tester.pumpAndSettle();
    expect(find.text('是否升级'), findsNothing);
    expect(adapter.choiceRequests, isEmpty);

    // 回到前台再查一次：后端仍返回提示，所以继续问
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('是否升级'), findsOneWidget);
  });

  testWidgets('后端返回空体（已 L2 / 无待定奖励）：不弹', (tester) async {
    final adapter = _useAdapter(tester, _UpgradeAdapter());
    await _pumpShell(tester);

    expect(find.text('是否升级'), findsNothing);
    expect(adapter.choiceRequests, isEmpty);
    expect(
      adapter.requests.where((r) => r.path.endsWith('/team/upgrade-prompt')),
      isNotEmpty,
      reason: '冷启动要查一次',
    );
  });

  testWidgets('canUpgrade=false（积分不够）：前端也不弹', (tester) async {
    _useAdapter(tester, _UpgradeAdapter(prompt: _prompt(canUpgrade: false, balance: 80, shortfall: 120)));
    await _pumpShell(tester);

    expect(find.text('是否升级'), findsNothing);
  });

  testWidgets('已购该档礼包：文案显示本次不再扣积分', (tester) async {
    _useAdapter(tester, _UpgradeAdapter(prompt: _prompt(entryPoints: 0, balance: 0)));
    await _pumpShell(tester);

    expect(find.textContaining('不再扣积分'), findsOneWidget);
  });

  testWidgets('升级提示先弹，处理完才弹达标确认', (tester) async {
    final adapter = _useAdapter(
      tester,
      _UpgradeAdapter(prompt: _prompt(), confirmPending: [_machine('SN-A', '小李家便利店')]),
    );
    await _pumpShell(tester);

    expect(find.text('是否升级'), findsOneWidget);
    expect(find.text('机器达标确认'), findsNothing, reason: '两个框不叠在一起');

    await tester.tap(find.text('立即升级'));
    await tester.pumpAndSettle();

    expect(find.text('是否升级'), findsNothing);
    expect(find.text('机器达标确认'), findsOneWidget);
    expect((adapter.choiceRequests.single.data as Map)['choice'], 'upgrade');
  });
}
