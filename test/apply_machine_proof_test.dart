import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kqw_app/core/api/pos_api.dart';
import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/auth_provider.dart';
import 'package:kqw_app/core/models/machine.dart';
import 'package:kqw_app/pages/apply_machine_page.dart';
import 'package:kqw_app/pages/install_guide_page.dart';

/// 打桩的 PosApi：记录申请入参（凭证截图是本次迁移的重点）
class _FakePosApi extends PosApi {
  _FakePosApi() : super(client: ApiClient(dio: Dio()));

  int applyCalls = 0;
  List<String>? appliedProofImages;
  String? appliedPhone;

  @override
  Future<MachineApplyResult> apply({
    required String contactName,
    required String phone,
    int? useType,
    String? merchantName,
    String? region,
    String? address,
    String? remark,
    List<String>? proofImages,
  }) async {
    applyCalls++;
    appliedPhone = phone;
    appliedProofImages = proofImages;
    return const MachineApplyResult(
      applyId: '9001',
      status: 0,
      statusName: '待处理',
    );
  }
}

/// 打开申请页：外层留一个可 pop 的路由，提交成功的 pop 才是真实路径
Future<void> _openPage(WidgetTester tester, PosApi api) async {
  // 表单项多：默认 800x600 会把提交按钮挤出 ListView 的构建范围，先放大视口
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: AuthProvider(),
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => ApplyMachinePage(api: api)),
              ),
              child: const Text('打开申请页'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开申请页'));
  await tester.pumpAndSettle();
}

/// 填必填项（联系人 + 手机号）后提交
Future<void> _fillAndSubmit(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), '张三');
  await tester.enterText(find.byType(TextFormField).at(1), '13900001111');
  await tester.tap(find.text('提交申请'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('申请页有凭证截图区（选填，最多 4 张）', (tester) async {
    await _openPage(tester, _FakePosApi());

    expect(find.text('装机凭证截图'), findsOneWidget);
    expect(find.text('选填，最多 4 张。不清楚传哪张？看截图示例'), findsOneWidget);
    expect(find.text('0/4'), findsOneWidget);
  });

  testWidgets('点「查看 ›」进上传说明页', (tester) async {
    await _openPage(tester, _FakePosApi());

    await tester.tap(find.text('查看 ›'));
    await tester.pumpAndSettle();

    expect(find.byType(InstallGuidePage), findsOneWidget);
    expect(find.text('装机凭证上传说明'), findsOneWidget);
    expect(find.text('① 在「我的」页点「我是商户」'), findsOneWidget);
  });

  testWidgets('没选凭证截图时，申请不带 proofImages', (tester) async {
    final api = _FakePosApi();
    await _openPage(tester, api);
    await _fillAndSubmit(tester);

    expect(api.applyCalls, 1);
    expect(api.appliedPhone, '13900001111');
    // 未选图时上传结果为空列表，PosApi.apply 不会把它写进请求体
    expect(api.appliedProofImages ?? const <String>[], isEmpty);
  });
}
