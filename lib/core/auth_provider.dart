import 'package:flutter/material.dart';

/// 登录态（骨架：手机号验证码登录，JWT 由 server 签发）。
/// TODO: 持久化 token（shared_preferences / flutter_secure_storage）
class AuthProvider extends ChangeNotifier {
  bool _loggedIn = false;
  String? _token;
  int? _userId;

  bool get loggedIn => _loggedIn;
  String? get token => _token;
  int? get userId => _userId;

  void init() {
    // TODO: 从本地安全存储恢复 token 并校验
  }

  /// 手机号 + 验证码登录；mock 模式直接置登录态
  Future<bool> loginSms(String phone, String code) async {
    // TODO: api.post('/auth/sms-login', body: {phone, code}) → token/userId
    _token = 'mock-token';
    _userId = 1;
    _loggedIn = true;
    notifyListeners();
    return true;
  }

  void logout() {
    _token = null;
    _userId = null;
    _loggedIn = false;
    notifyListeners();
  }
}
