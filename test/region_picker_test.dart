import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kqw_app/core/widgets/region_picker.dart';

/// 小样本数据：真实数据 31 省太长，联动逻辑与 UI 用两份数据都一样
const _tree = {
  '广东省': {
    '深圳市': ['南山区', '福田区'],
    '广州市': ['天河区'],
  },
  '北京市': {
    '北京市': ['东城区', '西城区'],
  },
};

void main() {
  setUp(() => RegionData.overrideForTest(RegionData.fromMap(_tree)));
  tearDown(() => RegionData.overrideForTest(null));

  test('直辖市拼串不重复市级', () {
    expect(joinRegion('北京市', '北京市', '东城区'), '北京市东城区');
    expect(joinRegion('广东省', '深圳市', '南山区'), '广东省深圳市南山区');
  });

  test('层级缺失时返回空列表而不是抛异常', () {
    final data = RegionData.fromMap(_tree);
    expect(data.provinces, ['广东省', '北京市']);
    expect(data.citiesOf(null), isEmpty);
    expect(data.citiesOf('不存在省'), isEmpty);
    expect(data.districtsOf('广东省', null), isEmpty);
    expect(data.districtsOf('广东省', '深圳市'), ['南山区', '福田区']);
  });

  testWidgets('省市区三段联动，确认后回填拼串', (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RegionPickerField(value: '', onChanged: (v) => picked = v),
      ),
    ));

    await tester.tap(find.byType(RegionPickerField));
    await tester.pumpAndSettle();

    // 还没选省时，市/区两列只给提示
    expect(find.text('请先选上一级'), findsNWidgets(2));

    await tester.tap(find.text('广东省'));
    await tester.pumpAndSettle();
    expect(find.text('深圳市'), findsOneWidget);
    expect(find.text('广州市'), findsOneWidget);

    await tester.tap(find.text('深圳市'));
    await tester.pumpAndSettle();
    expect(find.text('南山区'), findsOneWidget);

    await tester.tap(find.text('南山区'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(picked, '广东省深圳市南山区');
  });

  testWidgets('换上级会清空下级，未选齐时确定不可用', (tester) async {
    String? picked;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RegionPickerField(value: '', onChanged: (v) => picked = v),
      ),
    ));

    await tester.tap(find.byType(RegionPickerField));
    await tester.pumpAndSettle();

    // 选到区县后，再换省份，区县应被清掉、确定重新禁用
    await tester.tap(find.text('广东省'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('深圳市'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('南山区'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('北京市'));
    await tester.pumpAndSettle();

    expect(find.text('南山区'), findsNothing);
    expect(find.text('东城区'), findsOneWidget);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    // 只选了省，不该回填也没关闭弹层
    expect(picked, isNull);
    expect(find.text('确定'), findsOneWidget);
  });

  testWidgets('已有值时展示拼串', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RegionPickerField(value: '北京市东城区', onChanged: (_) {}),
      ),
    ));
    expect(find.text('北京市东城区'), findsOneWidget);
  });
}
