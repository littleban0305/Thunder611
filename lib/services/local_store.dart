import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStore {
  static const _accountsKey = 'thunder611.accounts.v1';
  static const _sessionKey = 'thunder611.session.v1';
  static const _tokenKey = 'thunder611.token.v1';
  static const _profilePrefix = 'thunder611.profile.';
  static const _chatPrefix = 'thunder611.chat.';
  static const _privatePrefix = 'thunder611.private.';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<Map<String, String>> loadAccounts() async {
    final prefs = await _prefs;
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
  }

  Future<bool> createAccount({required String username, required String password}) async {
    final normalized = username.trim();
    if (normalized.isEmpty || password.length < 4) return false;
    final accounts = await loadAccounts();
    if (accounts.containsKey(normalized)) return false;
    accounts[normalized] = password;
    final prefs = await _prefs;
    await prefs.setString(_accountsKey, jsonEncode(accounts));
    await setSession(normalized);
    return true;
  }

  Future<bool> login({required String username, required String password}) async {
    final normalized = username.trim();
    final accounts = await loadAccounts();
    if (accounts[normalized] != password) return false;
    await setSession(normalized);
    return true;
  }

  Future<String?> currentSession() async {
    final prefs = await _prefs;
    return prefs.getString(_sessionKey);
  }

  Future<String?> currentToken() async {
    final prefs = await _prefs;
    return prefs.getString(_tokenKey);
  }

  Future<void> setSession(String username, {String? token}) async {
    final prefs = await _prefs;
    await prefs.setString(_sessionKey, username);
    if (token != null && token.isNotEmpty) {
      await prefs.setString(_tokenKey, token);
    }
  }

  Future<void> clearSession() async {
    final prefs = await _prefs;
    await prefs.remove(_sessionKey);
    await prefs.remove(_tokenKey);
  }

  String _profileKey(String username) => '$_profilePrefix${Uri.encodeComponent(username)}';
  String _chatKey(String username) => '$_chatPrefix${Uri.encodeComponent(username)}';
  String _privateKey(String username) => '$_privatePrefix${Uri.encodeComponent(username)}';

  Future<Map<String, dynamic>> loadProfile(String username) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_profileKey(username));
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  Future<void> saveProfile(String username, Map<String, dynamic> profile) async {
    final prefs = await _prefs;
    await prefs.setString(_profileKey(username), jsonEncode(profile));
  }

  Future<List<Map<String, dynamic>>> loadChat(String username) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_chatKey(username));
    if (raw == null) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> saveChat(String username, List<Map<String, dynamic>> messages) async {
    final prefs = await _prefs;
    await prefs.setString(_chatKey(username), jsonEncode(messages));
  }

  Future<Map<String, List<Map<String, dynamic>>>> loadPrivate(String username) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_privateKey(username));
    if (raw == null) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map((key, value) {
      final list = value is List
          ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      return MapEntry(key.toString(), list);
    });
  }

  Future<void> savePrivate(String username, Map<String, List<Map<String, dynamic>>> messages) async {
    final prefs = await _prefs;
    await prefs.setString(_privateKey(username), jsonEncode(messages));
  }
}
