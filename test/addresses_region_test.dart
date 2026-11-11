import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kqw_app/core/api_client.dart';
import 'package:kqw_app/core/widgets/region_picker.dart';
import 'package:kqw_app/pages/addresses_page.dart';

import 'support/fake_http_adapter.dart';

/// 小样本省市区：联动逻辑与真实 31 省数据一致，测试不必加载 assets
const _tree = {
  '广东省': {
    '深圳市': ['南山区', '福田区'],
    '广州市': ['天河区'],
  },
  '北京市': {
    '北京市': ['东城区', '西城区'],
  },
};

/// 收货地址：省市区改为联动选择（详细地址仍手填），编辑时可改省市区
void main() {
  final posts = <Map<String, dynamic>>[];
  final puts = <Map<String, dynamic>>[];

  setUp(() {
    RegionData.overrideForTest(RegionData.fromMap(_tree));
    posts.clear();
    puts.clear();
    api.dio.httpClientAdapter = FakeAdapter((options, attempt) async {
      final path = options.path;
      if (options.method == 'GET' && path == '/user/addresses') {
        return jsonResponse({
          'items': [
            {
              'id': '1',
              'receiver': '张三',
              'phone': '13800000001',
              'province': '广东省',
              'city': '深圳市',
              'district': '南山区',
              'detail': '科技园 1 号楼 101',
              'isDefault': true,
            }
          ],
          'total': 1,
        }, 200);
      }
      if (options.method == 'POST' && path == '/user/addresses') {
        posts.add(Map<String, dynamic>.from(options.data as Map));
        return jsonResponse({
          'id': '2',
          'receiver': '李四',
          'phone': '13800000002',
          'province': '广东省',
          'city': '深圳市',
          'district': '福田区',
          'detail': '科技园 2 号楼 202',
          'isDefault': false,
        }, 200);
      }
      if (options.method == 'PUT' && path.startsWith('/user/addresses/')) {
        puts.add(Map<String, dynamic>.from(options.data as Map));
        return jsonResponse({
          'id': '1',
          'receiver': '张三',
          'phone': '13800000001',
          'province': '广东省',
          'city': '深圳市',
          'district': '福田区',
          'detail': '科技园 1 号楼 101',
          'isDefault': true,
        }, 200);
      }
      return jsonResponse({'code': 404, 'message': 'not found'}, 404);
    });
  });

  tearDown(() => RegionData.overrideForTest(null));

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AddressesPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('新增地址：省市区走联动选择，提交带上三段', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byIcon(Icons.add_location_alt_outlined));
    await tester.pumpAndSettle();

    // 省/市/区不再是三个文本框，只剩收货人 / 手机号 / 详细地址
    expect(find.text('省 / 市 / 区（点击选择）'), findsOneWidget);
    expect(find.text('省 / 直辖市'), findsNothing);
    expect(find.byType(TextField), findsNWidgets(3));

    await tester.enterText(find.byType(TextField).at(0), '李四');
    await tester.enterText(find.byType(TextField).at(1), '13800000002');
    await tester.enterText(find.byType(TextField).at(2), '科技园 2 号楼 202');

    await tester.tap(find.text('省 / 市 / 区（点击选择）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('广东省'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深圳市'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('福田区'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('广东省 深圳市 福田区'), findsOneWidget);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(posts, hasLength(1));
    expect(posts.single['province'], '广东省');
    expect(posts.single['city'], '深圳市');
    expect(posts.single['district'], '福田区');
    expect(posts.single['detail'], '科技园 2 号楼 202');
  });

  testWidgets('编辑地址：省市区回显，改区县后按新值提交', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    // 已保存的三段拼串直接展示在联动项里
    expect(find.text('广东省 深圳市 南山区'), findsOneWidget);

    await tester.tap(find.text('广东省 深圳市 南山区'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('福田区'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('广东省 深圳市 福田区'), findsOneWidget);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(puts, hasLength(1));
    expect(puts.single['province'], '广东省');
    expect(puts.single['city'], '深圳市');
    expect(puts.single['district'], '福田区');
  });
}
