import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kqw_app/core/api/pos_api.dart';
import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/auth_provider.dart';
import 'package:kqw_app/core/models/machine.dart';
import 'package:kqw_app/core/widgets/region_picker.dart';
import 'package:kqw_app/pages/apply_machine_page.dart';

/// 记录省市区入参的申请接口替身
class _FakePosApi extends PosApi {
  _FakePosApi() : super(client: ApiClient(dio: Dio()));

  int applyCalls = 0;
  String? appliedRegion;
  String? appliedMerchantName;

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
    appliedRegion = region;
    appliedMerchantName = merchantName;
    return const MachineApplyResult(
      applyId: '9001',
      status: 0,
      statusName: '待处理',
    );
  }
}

const _tree = {
  '广东省': {
    '深圳市': ['南山区', '福田区'],
  },
  '北京市': {
    '北京市': ['东城区'],
  },
};

Future<void> _openPage(WidgetTester tester, PosApi api) async {
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
  setUp(() => RegionData.overrideForTest(RegionData.fromMap(_tree)));
  tearDown(() => RegionData.overrideForTest(null));

  testWidgets('申请页不再出现「门店名称」', (tester) async {
    await _openPage(tester, _FakePosApi());

    expect(find.text('门店名称'), findsNothing);
    expect(find.text('所在地区'), findsOneWidget);
    expect(find.byType(RegionPickerField), findsOneWidget);
    // 门店名称隐掉后，选填项文案里也不该再提便利店
    expect(find.textContaining('便利店'), findsNothing);
  });

  testWidgets('选完省市区后，申请带上拼串的地区', (tester) async {
    final api = _FakePosApi();
    await _openPage(tester, api);
    await _fillRequired(tester);

    await tester.tap(find.byType(RegionPickerField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('广东省'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深圳市'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('南山区'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('广东省深圳市南山区'), findsOneWidget);

    await tester.tap(find.text('提交申请'));
    await tester.pumpAndSettle();

    expect(api.applyCalls, 1);
    expect(api.appliedRegion, '广东省深圳市南山区');
    // 门店名称已隐藏，不该再传该字段
    expect(api.appliedMerchantName, isNull);
  });

  testWidgets('不选地区也能提交（选填）', (tester) async {
    final api = _FakePosApi();
    await _openPage(tester, api);
    await _fillRequired(tester);

    await tester.tap(find.text('提交申请'));
    await tester.pumpAndSettle();

    expect(api.applyCalls, 1);
    expect(api.appliedRegion ?? '', isEmpty);
  });
}
