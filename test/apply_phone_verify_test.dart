import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kqw_app/core/api/pos_api.dart';
import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/auth_provider.dart';
import 'package:kqw_app/core/models/machine.dart';
import 'package:kqw_app/pages/apply_machine_page.dart';

/// 记录验证码验证与申请入参的接口替身
class _FakePosApi extends PosApi {
  _FakePosApi({this.verifyError, this.autoRegistered = false})
      : super(client: ApiClient(dio: Dio()));

  /// 非空时验证接口直接抛错（模拟验证码错误/过期）
  final ApiException? verifyError;

  /// true = 服务端自动建号并绑定推广人
  final bool autoRegistered;

  int verifyCalls = 0;
  int applyCalls = 0;
  String? verifiedPhone;
  String? verifiedCode;
  int? appliedUseType;
  String? appliedPhone;

  @override
  Future<ApplyPhoneVerifyResult> verifyApplyPhone({
    required String phone,
    required String code,
  }) async {
    verifyCalls++;
    verifiedPhone = phone;
    verifiedCode = code;
    if (verifyError != null) throw verifyError!;
    return ApplyPhoneVerifyResult(
      verified: true,
      registered: autoRegistered,
      phone: phone,
      userId: '20001',
    );
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
  }) async {
    applyCalls++;
    appliedUseType = useType;
    appliedPhone = phone;
    return const MachineApplyResult(applyId: '9001', status: 0, statusName: '待处理');
  }
}

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

/// 申请人（业务员）姓名 + 使用人手机号
Future<void> _fillRequired(WidgetTester tester, {String phone = '13900001111'}) async {
  await tester.enterText(find.byType(TextFormField).at(0), '张三');
  await tester.enterText(find.byType(TextFormField).at(1), phone);
}

/// 切到「他人使用」并填好使用人验证码（第 3 个输入框）
Future<void> _switchToOther(WidgetTester tester, {String code = '246810'}) async {
  await tester.tap(find.text('他人使用'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(2), code);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('自己使用不出现验证码字段', (tester) async {
    await _openPage(tester, _FakePosApi());

    expect(find.text('使用人验证码'), findsNothing);
    expect(find.text('获取验证码'), findsNothing);
  });

  testWidgets('切到他人使用：出现验证码字段与获取验证码按钮', (tester) async {
    await _openPage(tester, _FakePosApi());

    await tester.tap(find.text('他人使用'));
    await tester.pumpAndSettle();

    expect(find.text('使用人验证码'), findsOneWidget);
    expect(find.text('获取验证码'), findsOneWidget);
    expect(find.textContaining('号码未注册会自动注册并绑定为你的下级'), findsOneWidget);
  });

  testWidgets('点获取验证码先弹拼图滑块，未通过不发码不验证', (tester) async {
    final api = _FakePosApi();
    await _openPage(tester, api);
    await _fillRequired(tester);
    await tester.tap(find.text('他人使用'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('获取验证码'));
    await tester.pumpAndSettle();

    expect(find.text('安全验证（滑动完成拼图）'), findsOneWidget);
    expect(api.verifyCalls, 0);
    expect(api.applyCalls, 0);
  });

  testWidgets('他人使用提交：先验证使用人号码，再提交 useType=2 的申请', (tester) async {
    final api = _FakePosApi();
    await _openPage(tester, api);
    await _fillRequired(tester);
    await _switchToOther(tester);

    await tester.tap(find.text('提交申请'));
    await tester.pumpAndSettle();

    expect(api.verifyCalls, 1);
    expect(api.verifiedPhone, '13900001111');
    expect(api.verifiedCode, '246810');
    expect(api.applyCalls, 1);
    expect(api.appliedUseType, 2);
  });

  testWidgets('自己使用提交：不调用验证接口', (tester) async {
    final api = _FakePosApi();
    await _openPage(tester, api);
    await _fillRequired(tester);

    await tester.tap(find.text('提交申请'));
    await tester.pumpAndSettle();

    expect(api.verifyCalls, 0);
    expect(api.applyCalls, 1);
    expect(api.appliedUseType, 1);
  });

  testWidgets('验证码不合法（不足 6 位）：表单拦住，不发验证也不提交', (tester) async {
    final api = _FakePosApi();
    await _openPage(tester, api);
    await _fillRequired(tester);
    await _switchToOther(tester, code: '123');

    await tester.tap(find.text('提交申请'));
    await tester.pumpAndSettle();

    expect(find.text('请输入 6 位验证码'), findsOneWidget);
    expect(api.verifyCalls, 0);
    expect(api.applyCalls, 0);
  });

  testWidgets('验证码错误：申请不提交，用户留在申请页', (tester) async {
    final api = _FakePosApi(verifyError: ApiException(10000, '验证码错误或已过期'));
    await _openPage(tester, api);
    await _fillRequired(tester);
    await _switchToOther(tester);

    await tester.tap(find.text('提交申请'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(api.verifyCalls, 1);
    expect(api.applyCalls, 0);
    expect(find.text('提交申请'), findsOneWidget);
  });
}
