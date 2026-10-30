import 'package:flutter_test/flutter_test.dart';

import 'support/memory_secure_store.dart';
import 'package:kqw_app/core/auth_provider.dart';
import 'package:kqw_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App 启动后展示登录页', (tester) async {
    // 未登录冷启动：本地无 token，路由应落在 /login
    SharedPreferences.setMockInitialValues({});
    final auth = AuthProvider(secureStore: MemorySecureStore());
    await auth.init();

    await tester.pumpWidget(KqwApp(auth: auth));
    await tester.pumpAndSettle();
    expect(find.text('超级展业'), findsWidgets);
    expect(find.text('登录'), findsOneWidget);
  });
}
