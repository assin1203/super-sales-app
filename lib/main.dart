import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/app_router.dart';
import 'core/auth_provider.dart';
import 'core/theme.dart';

void main() {
  runApp(const KqwApp());
}

class KqwApp extends StatelessWidget {
  const KqwApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..init(),
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) => MaterialApp.router(
          title: '超级展业',
          debugShowCheckedModeBanner: false,
          theme: kqwTheme,
          routerConfig: appRouter(auth),
        ),
      ),
    );
  }
}
