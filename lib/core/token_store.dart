import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 敏感值（access / refresh token）存储接口。
///
/// 生产环境用 [PlatformSecureStore] 走系统安全存储；单元测试注入内存实现，
/// 避免在 `testWidgets` 的 fake async 里 await 平台通道导致死锁。
abstract class SecureStore {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});

  Future<void> delete({required String key});
}

/// 系统安全存储实现（iOS Keychain / Android Keystore）。
///
/// 平台不支持（测试环境、无插件）时会抛异常，由调用方捕获后降级到
/// SharedPreferences，因此这里不做任何兜底。
class PlatformSecureStore implements SecureStore {
  const PlatformSecureStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}
