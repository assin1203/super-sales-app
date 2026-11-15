import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kqw_app/core/api/pos_api.dart';
import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/auth_provider.dart';
import 'package:kqw_app/core/models/machine.dart';
import 'package:kqw_app/pages/apply_machine_page.dart';

/// 字典 + 申请接口替身：三个下拉的数据源都能注入，提交时记录收到的 ID
class _FakePosApi extends PosApi {
  _FakePosApi({this.emptyDict = false}) : super(client: ApiClient(dio: Dio()));

  /// true 模拟后台字典还没配数据：三项都应为空、禁用
  final bool emptyDict;

  int applyCalls = 0;
  String? appliedBrandId;
  String? appliedTypeId;
  String? appliedPlatformId;

  @override
  Future<List<PosBrandOption>> brands() async => emptyDict
      ? const []
      : const [
          PosBrandOption(id: '1', name: '拉卡拉'),
          PosBrandOption(id: '2', name: '新大陆'),
        ];

  @override
  Future<List<PosTypeOption>> types() async =>
      emptyDict ? const [] : const [PosTypeOption(id: '11', name: '4G 版')];

  @override
  Future<List<PosPlatformOption>> platforms() async =>
      emptyDict ? const [] : const [PosPlatformOption(id: '21', name: '乐慧云')];

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

Future<void> _pick(
    WidgetTester tester, int index, String optionText) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).at(index));
  await tester.pumpAndSettle();
  await tester.tap(find.text(optionText).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('申请页有品牌/类型/所属平台三个下拉', (tester) async {
    await _openPage(tester, _FakePosApi());

    expect(find.text('品牌'), findsOneWidget);
    expect(find.text('类型'), findsOneWidget);
    expect(find.text('所属平台'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
  });

  testWidgets('选中三项后提交，申请带上各自的字典 ID', (tester) async {
    final api = _FakePosApi();
    await _openPage(tester, api);
    await _fillRequired(tester);

    await _pick(tester, 0, '拉卡拉');
    await _pick(tester, 1, '4G 版');
    await _pick(tester, 2, '乐慧云');

    await tester.tap(find.text('提交申请'));
    await tester.pumpAndSettle();

    expect(api.applyCalls, 1);
    expect(api.appliedBrandId, '1');
    expect(api.appliedTypeId, '11');
    expect(api.appliedPlatformId, '21');
  });

  testWidgets('三项都是选填：不选也能提交，ID 为空', (tester) async {
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

  testWidgets('字典为空时提示「暂无可选」并禁用，不阻断提交', (tester) async {
    final api = _FakePosApi(emptyDict: true);
    await _openPage(tester, api);

    expect(find.text('暂无可选品牌'), findsOneWidget);
    expect(find.text('暂无可选类型'), findsOneWidget);
    expect(find.text('暂无可选平台'), findsOneWidget);

    await _fillRequired(tester);
    await tester.tap(find.text('提交申请'));
    await tester.pumpAndSettle();

    expect(api.applyCalls, 1);
    expect(api.appliedBrandId, isNull);
  });
}
