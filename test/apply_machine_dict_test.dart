import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kqw_app/core/api/pos_api.dart';
import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/auth_provider.dart';
import 'package:kqw_app/core/models/machine.dart';
import 'package:kqw_app/pages/apply_machine_page.dart';

/// 字典 + 申请接口替身：即使后台字典有数据，页面也不该展示这三个下拉
class _FakePosApi extends PosApi {
  _FakePosApi() : super(client: ApiClient(dio: Dio()));

  int brandsCalls = 0;
  int typesCalls = 0;
  int platformsCalls = 0;
  int applyCalls = 0;
  String? appliedBrandId;
  String? appliedTypeId;
  String? appliedPlatformId;

  @override
  Future<List<PosBrandOption>> brands() async {
    brandsCalls++;
    return const [PosBrandOption(id: '1', name: '拉卡拉')];
  }

  @override
  Future<List<PosTypeOption>> types() async {
    typesCalls++;
    return const [PosTypeOption(id: '11', name: '4G 版')];
  }

  @override
  Future<List<PosPlatformOption>> platforms() async {
    platformsCalls++;
    return const [PosPlatformOption(id: '21', name: '乐慧云')];
  }

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
    String? brandId,
    String? typeId,
    String? platformId,
  }) async {
    applyCalls++;
    appliedBrandId = brandId;
    appliedTypeId = typeId;
    appliedPlatformId = platformId;
    return const MachineApplyResult(
      applyId: '9001',
      status: 0,
      statusName: '待处理',
    );
  }
}

Future<void> _openPage(WidgetTester tester, PosApi api) async {
  // 表单项较多：默认 800x600 会把提交按钮挤出 ListView 的构建范围，先放大视口
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

Future<void> _fillRequired(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), '张三');
  await tester.enterText(find.byType(TextFormField).at(1), '13900001111');
}

void main() {
  testWidgets('申请页不展示品牌/类型/所属平台', (tester) async {
    final api = _FakePosApi();
    await _openPage(tester, api);

    expect(find.text('品牌'), findsNothing);
    expect(find.text('类型'), findsNothing);
    expect(find.text('所属平台'), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    // 不渲染下拉，也不该白跑三个字典请求
    expect(api.brandsCalls, 0);
    expect(api.typesCalls, 0);
    expect(api.platformsCalls, 0);
  });

  testWidgets('隐藏后提交照常：申请不带三项，必填校验不受影响', (tester) async {
    final api = _FakePosApi();
    await _openPage(tester, api);
    await _fillRequired(tester);

    await tester.tap(find.text('提交申请'));
    await tester.pumpAndSettle();

    expect(api.applyCalls, 1);
    expect(api.appliedBrandId, isNull);
    expect(api.appliedTypeId, isNull);
    expect(api.appliedPlatformId, isNull);
  });
}
