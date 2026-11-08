import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kqw_app/core/api/app_version_api.dart';
import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/app_update.dart';
import 'package:kqw_app/core/models/app_version_info.dart';

import 'support/fake_http_adapter.dart';

/// 版本更新提示：`GET /common/app/version` 返回最新版本 → 冷启动比对 versionCode
/// → 有新版本弹窗（强更不可关闭），点「立即更新」跳下载地址。
void main() {
  FakeAdapter adapterFor(Object? payload, {int statusCode = 200}) =>
      FakeAdapter((options, attempt) async => jsonResponse(payload, statusCode));

  AppUpdateChecker buildChecker(
    FakeAdapter adapter, {
    int installedCode = 1,
    String installedName = '0.1.0',
    List<Uri>? opened,
  }) {
    final client = ApiClient();
    client.dio.httpClientAdapter = adapter;
    return AppUpdateChecker(
      api: AppVersionApi(client: client),
      loadVersion: () async => InstalledVersion(
        versionName: installedName,
        versionCode: installedCode,
      ),
      openUrl: (uri) async {
        opened?.add(uri);
        return true;
      },
    );
  }

  /// 用页面里的按钮触发检查（模拟冷启动首帧回调 / 「检查更新」入口）
  Future<void> runCheck(
    WidgetTester tester,
    AppUpdateChecker checker, {
    bool manual = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => checker.check(context, manual: manual),
              child: const Text('check'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('check'));
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> newerPayload({bool force = false, int code = 2}) => {
        'versionName': '0.2.0',
        'versionCode': code,
        'downloadUrl': 'https://dl.example.com/kqw-0.2.0.apk',
        'releaseNotes': '修复装机提交偶发失败',
        'forceUpdate': force,
      };

  testWidgets('有新版本：弹窗展示版本与说明，可稍后再说', (tester) async {
    final adapter = adapterFor(newerPayload());
    final opened = <Uri>[];
    await runCheck(tester, buildChecker(adapter, opened: opened));

    expect(find.text('发现新版本 v0.2.0'), findsOneWidget);
    expect(find.text('修复装机提交偶发失败'), findsOneWidget);
    expect(find.text('当前版本 v0.1.0'), findsOneWidget);
    expect(find.text('稍后再说'), findsOneWidget);

    // 请求带上本地 versionCode，后端据此决定下发哪个版本
    final request = adapter.requests.single;
    expect(request.path, '/common/app/version');
    expect(request.queryParameters['versionCode'], '1');
    expect(request.queryParameters['platform'], updatePlatform);

    await tester.tap(find.text('稍后再说'));
    await tester.pumpAndSettle();
    expect(find.text('发现新版本 v0.2.0'), findsNothing);
    expect(opened, isEmpty, reason: '「稍后再说」不能拉起下载页');
  });

  testWidgets('点「立即更新」打开后端下发的下载地址', (tester) async {
    final opened = <Uri>[];
    await runCheck(tester, buildChecker(adapterFor(newerPayload()), opened: opened));

    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(opened.single.toString(), 'https://dl.example.com/kqw-0.2.0.apk');
    expect(find.text('发现新版本 v0.2.0'), findsNothing);
  });

  testWidgets('强更：没有「稍后再说」，点遮罩也关不掉', (tester) async {
    await runCheck(tester, buildChecker(adapterFor(newerPayload(force: true))));

    expect(find.text('发现新版本 v0.2.0'), findsOneWidget);
    expect(find.text('稍后再说'), findsNothing);
    expect(find.text('本次为必要更新，完成后才能继续使用'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('发现新版本 v0.2.0'), findsOneWidget,
        reason: '强更弹窗不能通过点遮罩消失');
  });

  testWidgets('minSupportedVersionCode 高于本地版本时也按强更处理', (tester) async {
    await runCheck(
      tester,
      buildChecker(
        adapterFor({
          'versionName': '0.2.0',
          'versionCode': 5,
          'minSupportedVersionCode': 2,
        }),
        installedCode: 1,
      ),
    );

    expect(find.text('稍后再说'), findsNothing);
    expect(find.text('本次为必要更新，完成后才能继续使用'), findsOneWidget);
    // 没有下载地址时不静默失败：点了给出提示，弹窗照常关掉
    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();
    expect(find.text('下载地址暂不可用，请稍后重试'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('服务端版本不高于本地：冷启动不弹窗', (tester) async {
    await runCheck(
      tester,
      buildChecker(adapterFor({'versionName': '0.1.0', 'versionCode': 1})),
    );

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('接口不可用（404）：冷启动静默放行，不弹窗不拦截', (tester) async {
    final adapter = FakeAdapter(
      (options, attempt) async =>
          jsonResponse({'code': -1, 'message': 'Not Found'}, 404),
    );
    await runCheck(tester, buildChecker(adapter));

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('手动检查且已是最新：给出提示、不弹窗', (tester) async {
    await runCheck(
      tester,
      buildChecker(adapterFor({'versionName': '0.1.0', 'versionCode': 1})),
      manual: true,
    );

    expect(find.text('当前已是最新版本 v0.1.0'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    // 等 SnackBar 自己消失，避免测试结束时留下未完成的定时器
    await tester.pump(const Duration(seconds: 3));
  });

  group('AppVersionInfo 解析', () {
    test('versionCode 兼容后端 BigInt 字符串，forceUpdate 兼容 1', () {
      final info = AppVersionInfo.fromJson({
        'versionName': '1.2.0',
        'versionCode': '12',
        'forceUpdate': 1,
        'minSupportedVersionCode': '10',
      });

      expect(info.versionCode, 12);
      expect(info.forceUpdate, isTrue);
      expect(info.minSupportedVersionCode, 10);
      expect(
        info.requiresForceUpdate(
            const InstalledVersion(versionName: '1.0.0', versionCode: 9)),
        isTrue,
      );
      expect(
        info.requiresForceUpdate(
            const InstalledVersion(versionName: '1.2.0', versionCode: 12)),
        isFalse,
      );
    });

    test('按 versionCode 比较，0.10.0 不会被当成比 0.9.0 小', () {
      final info = AppVersionInfo.fromJson({
        'versionName': '0.10.0',
        'versionCode': 10,
      });
      const installed = InstalledVersion(versionName: '0.9.0', versionCode: 9);

      expect(info.versionCode > installed.versionCode, isTrue,
          reason: '字符串比较会把 0.9.0 判成更新，必须用 versionCode');
    });

    test('缺 versionCode 视为无版本信息', () {
      final info = AppVersionInfo.fromJson({'versionName': 'x'});
      expect(info.versionCode, 0);
    });
  });
}
