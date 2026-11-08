import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:kqw_app/core/api/pos_api.dart';
import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/models/machine.dart';
import 'package:kqw_app/core/models/page_result.dart';
import 'package:kqw_app/pages/machines_page.dart';

/// 打桩的 PosApi：两个列表都返回空，只看入口跳转
class _FakePosApi extends PosApi {
  _FakePosApi() : super(client: ApiClient(dio: Dio()));

  int machinesCalls = 0;
  int appliesCalls = 0;

  @override
  Future<MachineList> machines({
    int? newbieStatus,
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    machinesCalls++;
    return const MachineList(
      page: PageResult(items: [], total: 0, pageNum: 1, pageSize: 20),
    );
  }

  @override
  Future<PageResult<MachineApply>> applies({
    int? status,
    int? source,
    int pageNum = 1,
    int pageSize = 20,
  }) async {
    appliesCalls++;
    return const PageResult(items: [], total: 0, pageNum: 1, pageSize: 20);
  }
}

void main() {
  testWidgets('我的机器页有「申请新机器」入口，与首页同一申请页', (tester) async {
    final api = _FakePosApi();
    final router = GoRouter(
      initialLocation: '/machines',
      routes: [
        GoRoute(path: '/machines', builder: (c, s) => MachinesPage(api: api)),
        GoRoute(
          path: '/machine/apply',
          builder: (c, s) => const Scaffold(body: Text('申请POS机页面')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('申请新机器'), findsOneWidget);

    await tester.tap(find.text('申请新机器'));
    await tester.pumpAndSettle();

    // 跳的是首页同一个 `/machine/apply`
    expect(find.text('申请POS机页面'), findsOneWidget);
  });
}
