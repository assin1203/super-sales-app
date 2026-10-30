import 'package:kqw_app/core/token_store.dart';

/// 内存版安全存储：测试里替代系统安全存储（Keychain / Keystore）。
///
/// 平台通道在 `testWidgets` 的 fake async 里不会完成，直接把真实现带进测试
/// 会让 `auth.init()` 永远挂住，因此测试统一注入这个实现。
class MemorySecureStore implements SecureStore {
  MemorySecureStore([Map<String, String>? initial]) : _values = {...?initial};

  final Map<String, String> _values;

  /// 便于断言「token 落在安全存储而不是 SharedPreferences」
  Map<String, String> get values => Map.unmodifiable(_values);

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String value}) async =>
      _values[key] = value;

  @override
  Future<void> delete({required String key}) async => _values.remove(key);
}

/// 模拟「平台不支持安全存储」：每次访问都抛异常，用于验证降级到 SharedPreferences
class UnavailableSecureStore implements SecureStore {
  @override
  Future<String?> read({required String key}) async =>
      throw UnsupportedError('no keychain');

  @override
  Future<void> write({required String key, required String value}) async =>
      throw UnsupportedError('no keychain');

  @override
  Future<void> delete({required String key}) async =>
      throw UnsupportedError('no keychain');
}
