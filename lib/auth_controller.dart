import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'services/backend_config.dart';
import 'services/local_store.dart';

class AuthController extends ChangeNotifier {
  final LocalStore store;
  bool loading = false;
  String? error;
  bool remoteConnected = false;

  AuthController({LocalStore? store}) : store = store ?? LocalStore();

  Future<String?> restoreSession() => store.currentSession();

  Future<Map<String, dynamic>?> _remoteAuth({
    required String path,
    required String username,
    required String password,
    String? code,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${BackendConfig.httpBaseUrl}$path'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username.trim(),
              'password': password,
              if (code != null) 'code': code.trim(),
            }),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        remoteConnected = true;
        return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      }

      remoteConnected = true;
      final decoded = jsonDecode(response.body);
      error = decoded is Map ? decoded['error']?.toString() : null;
      return null;
    } catch (_) {
      remoteConnected = false;
      return null;
    }
  }

  Future<String?> login(String username, String password) async {
    error = null;
    loading = true;
    notifyListeners();

    final name = username.trim();
    final remote = await _remoteAuth(
      path: '/api/auth/login',
      username: name,
      password: password,
    );

    if (remote != null) {
      await store.setSession(name, token: remote['token']?.toString());
      loading = false;
      notifyListeners();
      return name;
    }

    if (remoteConnected) {
      loading = false;
      error ??= '帳號或密碼不正確';
      notifyListeners();
      return null;
    }

    await Future<void>.delayed(const Duration(milliseconds: 180));
    final ok = await store.login(username: name, password: password);
    loading = false;
    if (!ok) error = '帳號或密碼不正確';
    notifyListeners();
    return ok ? name : null;
  }

  Future<String?> register(String username, String password, String code) async {
    error = null;
    loading = true;
    notifyListeners();

    final name = username.trim();
    if (name.length < 2) {
      loading = false;
      error = '暱稱至少 2 個字';
      notifyListeners();
      return null;
    }
    if (password.length < 4) {
      loading = false;
      error = '密碼至少 4 碼';
      notifyListeners();
      return null;
    }
    if (code.trim() != '611') {
      loading = false;
      error = '班級代碼錯誤';
      notifyListeners();
      return null;
    }

    final remote = await _remoteAuth(
      path: '/api/auth/register',
      username: name,
      password: password,
      code: code,
    );

    if (remote != null) {
      await store.setSession(name, token: remote['token']?.toString());
      loading = false;
      notifyListeners();
      return name;
    }

    if (remoteConnected) {
      loading = false;
      error ??= '建立帳號失敗';
      notifyListeners();
      return null;
    }

    await Future<void>.delayed(const Duration(milliseconds: 180));
    final ok = await store.createAccount(username: name, password: password);
    loading = false;
    if (!ok) error = '這個暱稱已被使用';
    notifyListeners();
    return ok ? name : null;
  }

  Future<void> logout() async {
    await store.clearSession();
  }
}
