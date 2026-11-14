import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kqw_app/core/api/pos_api.dart';
import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/models/machine.dart';
import 'package:kqw_app/pages/add_machine_page.dart';
import 'package:kqw_app/pages/install_guide_page.dart';

/// 打桩的 PosApi：只实现装机页用到的方法，记录装机调用。
class _FakePosApi extends PosApi {
  _FakePosApi({required this.preview, this.installed}) : super(client: ApiClient(dio: Dio()));

  final PendingInstallPreview preview;

  /// 实名核对结果（姓名 + 身份证后 6 位查已装机器），缺省 = 查不到
  final InstalledMachines? installed;

  final List<String> installedApplyIds = [];
  String? installedMachineNo;
  String? installedIdTail;
  String? installedName;
  int installedQueryCount = 0;

  /// 最近一次「核对已装机器」查的入参
  String? lastQueryName;
  String? lastQueryIdTail;

  @override
  Future<List<PosBrandOption>> brands() async => const [];

  @override
  Future<List<PosTypeOption>> types() async => const [];

  @override
  Future<PosMachineProfile> machineProfile(String sn) async =>
      PosMachineProfile(found: false, machineNo: sn, message: '未查到机具信息');

  @override
  Future<InstalledMachines> installedMachines({
    required String name,
    required String idTail,
  }) async {
    installedQueryCount++;
    lastQueryName = name;
    lastQueryIdTail = idTail;
    return installed ??
        const InstalledMachines(found: false, total: 0, message: '未查到该客户的装机记录');
  }

  @override
  Future<PendingInstallPreview> pendingAppliesByPhone(String phone, {int? source}) async =>
      preview;

  @override
  Future<MachineApply> installApply({
    required String applyId,
    String? machineNo,
    int? installMode,
    String? brandId,
    String? typeId,
    DateTime? bootTime,
    String? contactName,
    String? merchantName,
    String? region,
    String? address,
    String? remark,
    String? trafficFeeRemark,
    String? idTail,
  }) async {
    installedApplyIds.add(applyId);
    installedMachineNo = machineNo;
    installedIdTail = idTail;
    installedName = contactName;
    return MachineApply(
      applyId: applyId,
      machineNo: machineNo ?? '',
      customerPhone: '139****1111',
      status: 3,
      statusName: '已安装',
    );
  }
}

PendingInstallApply _pending({
  required String applyId,
  String? merchantName,
  String? machineNo,
}) =>
    PendingInstallApply(
      applyId: applyId,
      requestNo: 'AP$applyId',
      phone: '139****1111',
      source: 1,
      sourceName: '装机申请',
      useType: 1,
      useTypeName: '自己使用',
      merchantName: merchantName,
      machineNo: machineNo,
      submittedAt: DateTime(2026, 11, 1, 10, 30),
    );

/// 打开装机页（外层留一个可 pop 的路由，装机成功后的 pop 才是真实路径）
Future<void> _openPage(WidgetTester tester, PosApi api) async {
  // 表单项多：默认 800x600 会把提交按钮挤出 ListView 的构建范围，先放大视口
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (ctx) => TextButton(
          onPressed: () => Navigator.of(ctx).push(
            MaterialPageRoute(builder: (_) => AddMachinePage(api: api)),
          ),
          child: const Text('打开装机页'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('打开装机页'));
  await tester.pumpAndSettle();
}

/// 填完姓名/手机号/身份证 → 核对已装机器 → 确认 → 提交
///
/// 表单顺序：机器号 / 客户姓名 / 客户手机号 / 身份证后 6 位 / 流量费备注 / 备注
Future<void> _fillPhoneAndSubmit(WidgetTester tester, String phone) async {
  await tester.enterText(find.byType(TextFormField).at(1), '张三');
  await tester.enterText(find.byType(TextFormField).at(2), phone);
  await tester.enterText(find.byType(TextFormField).at(3), '123456');

  // 核对是提交前的强制步骤：不确认就会被拦在提交之外
  await tester.tap(find.text('核对已装机器'));
  await tester.pumpAndSettle();
  final confirm = find.text('确认无误，继续装机');
  await tester.tap(confirm.evaluate().isNotEmpty ? confirm : find.text('确认，继续装机'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('确认添加'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('一个号码有多台待装：弹窗选一台，只装选中的那条', (tester) async {
    final first = _pending(applyId: '11', merchantName: '王记便利店');
    final second = _pending(applyId: '12', merchantName: '李记超市');
    final api = _FakePosApi(
      preview: PendingInstallPreview(
        found: true,
        phone: '139****1111',
        total: 2,
        message: '该号码有 2 台待装机器，选一台开始装机',
        items: [first, second],
      ),
    );

    await _openPage(tester, api);
    await _fillPhoneAndSubmit(tester, '13900001111');

    // 多台时不直接装：先让业务员选一台
    expect(find.text('该号码有 2 台待装机器，选一台开始装机'), findsOneWidget);
    expect(find.text('王记便利店'), findsOneWidget);
    expect(find.text('李记超市'), findsOneWidget);
    expect(api.installedApplyIds, isEmpty);

    await tester.tap(find.text('李记超市'));
    await tester.pumpAndSettle();

    expect(api.installedApplyIds, ['12']);
  });

  testWidgets('只有一台待装：不弹选择框，直接装机', (tester) async {
    final api = _FakePosApi(
      preview: PendingInstallPreview(
        found: true,
        phone: '139****1111',
        total: 1,
        message: '该号码有 1 台待装机器，选一台开始装机',
        items: [_pending(applyId: '21', merchantName: '张记烟酒', machineNo: 'SN-21')],
      ),
    );

    await _openPage(tester, api);
    await _fillPhoneAndSubmit(tester, '13900001111');

    expect(find.text('该号码有 1 台待装机器，选一台开始装机'), findsNothing);
    expect(api.installedApplyIds, ['21']);
    // 申请记录已带机号而输入框空着：回填后一起提交，避免与记录对不上
    expect(api.installedMachineNo, 'SN-21');
    // 实名两项随装机一起上报（申请记录没存，空着后端拿不到），且只核对了一次
    expect(api.installedIdTail, '123456');
    expect(api.installedName, '张三');
    expect(api.installedQueryCount, 1);
  });

  testWidgets('该号码没有可装机申请：提示后端文案，不发起装机', (tester) async {
    final api = _FakePosApi(
      preview: const PendingInstallPreview(
        found: false,
        phone: '139****1111',
        total: 0,
        message: '该手机号没有待处理的装机申请，请先提交申请或核对号码',
      ),
    );

    await _openPage(tester, api);
    await _fillPhoneAndSubmit(tester, '13900001111');

    expect(find.text('该手机号没有待处理的装机申请，请先提交申请或核对号码'), findsOneWidget);
    expect(api.installedApplyIds, isEmpty);
  });

  testWidgets('凭证截图已迁到申请页：装机页不再有凭证区', (tester) async {
    final api = _FakePosApi(
      preview: const PendingInstallPreview(
        found: false,
        phone: '139****1111',
        total: 0,
        message: '',
      ),
    );

    await _openPage(tester, api);

    expect(find.text('装机凭证截图'), findsNothing);
    expect(find.text('选填，最多 4 张。不清楚传哪张？看截图示例'), findsNothing);
    expect(find.text('0/4'), findsNothing);
  });

  testWidgets('装机只提交申请补录字段（凭证随申请单走）', (tester) async {
    final api = _FakePosApi(
      preview: PendingInstallPreview(
        found: true,
        phone: '139****1111',
        total: 1,
        message: '',
        items: [_pending(applyId: '31', merchantName: '陈记五金', machineNo: 'SN-31')],
      ),
    );

    await _openPage(tester, api);
    await _fillPhoneAndSubmit(tester, '13900001111');

    expect(api.installedApplyIds, ['31']);
  });

  testWidgets('没核对已装机器就提交：被拦下，不发起装机', (tester) async {
    final api = _FakePosApi(
      preview: PendingInstallPreview(
        found: true,
        phone: '139****1111',
        total: 1,
        message: '',
        items: [_pending(applyId: '41', merchantName: '赵记水果')],
      ),
    );

    await _openPage(tester, api);
    await tester.enterText(find.byType(TextFormField).at(1), '张三');
    await tester.enterText(find.byType(TextFormField).at(2), '13900001111');
    await tester.enterText(find.byType(TextFormField).at(3), '123456');
    await tester.tap(find.text('确认添加'));
    await tester.pumpAndSettle();

    expect(find.text('请先点「核对已装机器」，确认客户信息后再提交'), findsOneWidget);
    expect(api.installedApplyIds, isEmpty);
    // 没点核对就不该发起实名查询
    expect(api.installedQueryCount, 0);
  });

  testWidgets('核对弹窗显示已装台数：同品牌两台提示上限，但仍允许提交', (tester) async {
    final api = _FakePosApi(
      installed: const InstalledMachines(
        found: true,
        total: 2,
        message: '',
        items: [
          InstalledMachineItem(machineNo: 'SN-A1', brandName: '新大陆'),
          InstalledMachineItem(machineNo: 'SN-A2', brandName: '新大陆'),
        ],
      ),
      preview: PendingInstallPreview(
        found: true,
        phone: '139****1111',
        total: 1,
        message: '',
        items: [_pending(applyId: '51', merchantName: '赵记水果')],
      ),
    );

    await _openPage(tester, api);
    await tester.enterText(find.byType(TextFormField).at(1), '张三');
    await tester.enterText(find.byType(TextFormField).at(2), '13900001111');
    await tester.enterText(find.byType(TextFormField).at(3), '123456');

    await tester.tap(find.text('核对已装机器'));
    await tester.pumpAndSettle();

    // 台数 + 品牌统计 + 机器号清单都在弹窗里
    expect(find.text('该客户已装机 2 台'), findsOneWidget);
    expect(find.text('新大陆 2 台'), findsOneWidget);
    expect(find.textContaining('已达 2 台上限'), findsOneWidget);
    expect(find.text('SN-A1'), findsOneWidget);

    await tester.tap(find.text('确认无误，继续装机'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已确认：该客户已装 2 台'), findsOneWidget);
    expect(api.installedQueryCount, 1);

    await tester.tap(find.text('确认添加'));
    await tester.pumpAndSettle();
    expect(api.installedApplyIds, ['51']);
    expect(api.installedIdTail, '123456');
  });

  testWidgets('身份证后 6 位小写 x：核对与提交都按大写归一化', (tester) async {
    final api = _FakePosApi(
      preview: PendingInstallPreview(
        found: true,
        phone: '139****1111',
        total: 1,
        message: '',
        items: [_pending(applyId: '61', merchantName: '孙记茶饮')],
      ),
    );

    await _openPage(tester, api);
    await tester.enterText(find.byType(TextFormField).at(1), '张三');
    await tester.enterText(find.byType(TextFormField).at(2), '13900001111');
    await tester.enterText(find.byType(TextFormField).at(3), '12345x');

    await tester.tap(find.text('核对已装机器'));
    await tester.pumpAndSettle();
    // 后端 @Matches 只认大写，核对请求不能带小写
    expect(api.lastQueryIdTail, '12345X');
    await tester.tap(find.text('确认，继续装机'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('确认添加'));
    await tester.pumpAndSettle();
    expect(api.installedApplyIds, ['61']);
    expect(api.installedIdTail, '12345X');
    expect(api.installedName, '张三');
  });

  testWidgets('核对后改客户手机号：核对结果作废，提交被拦下', (tester) async {
    final api = _FakePosApi(
      preview: PendingInstallPreview(
        found: true,
        phone: '139****1111',
        total: 1,
        message: '',
        items: [_pending(applyId: '71', merchantName: '周记杂货')],
      ),
    );

    await _openPage(tester, api);
    await tester.enterText(find.byType(TextFormField).at(1), '张三');
    await tester.enterText(find.byType(TextFormField).at(2), '13900001111');
    await tester.enterText(find.byType(TextFormField).at(3), '123456');

    await tester.tap(find.text('核对已装机器'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认，继续装机'));
    await tester.pumpAndSettle();
    expect(find.textContaining('已确认'), findsOneWidget);

    // 手机号决定这条核对结果装在谁的申请单上，换号必须重新核对
    await tester.enterText(find.byType(TextFormField).at(2), '13900002222');
    await tester.pumpAndSettle();
    expect(find.text('提交前需按姓名和身份证号核对客户已装机器'), findsOneWidget);

    await tester.tap(find.text('确认添加'));
    await tester.pumpAndSettle();
    expect(find.text('请先点「核对已装机器」，确认客户信息后再提交'), findsOneWidget);
    expect(api.installedApplyIds, isEmpty);
  });

  testWidgets('说明页示例图可全屏预览：能左右滑动切换，也能关闭', (tester) async {    // 入口已随凭证区迁到申请页，这里直接打开说明页验证预览交互
    tester.view.physicalSize = const Size(1080, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: InstallGuidePage()));
    await tester.pumpAndSettle();
    // 示例图是真实 asset：等真实 IO 解码完成，否则 RenderImage 尺寸为 0 点不到
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.text('装机凭证上传说明'), findsOneWidget);
    expect(find.text('① 在「我的」页点「我是商户」'), findsOneWidget);

    // 点第一张示例图进入全屏预览，页码从 1/3 开始
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);

    // 左滑切到第二张、再切第三张
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);

    // 右上角关闭回说明页
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('装机凭证上传说明'), findsOneWidget);
    expect(find.text('1/3'), findsNothing);
  });
}
