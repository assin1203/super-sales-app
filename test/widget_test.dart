import 'package:flutter_test/flutter_test.dart';
import 'package:kqw_app/main.dart';

void main() {
  testWidgets('App 启动后展示登录页', (tester) async {
    await tester.pumpWidget(const KqwApp());
    await tester.pumpAndSettle();
    expect(find.text('超级展业'), findsWidgets);
    expect(find.text('登录 / 注册'), findsOneWidget);
  });
}
