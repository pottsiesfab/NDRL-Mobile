import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'device_service.dart';

const _authApi = 'https://dev.nostalgiadragleague.com/api/mobile_auth_api.php';
const _deviceCredentialKey = 'ndrl_dev_device_credential';
const _accessKey = 'ndrl_dev_member_access';
const _refreshKey = 'ndrl_dev_member_refresh';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  AuthService({required DeviceService deviceService,
      FlutterSecureStorage? storage, http.Client? client})
      : _deviceService = deviceService,
        _storage = storage ?? const FlutterSecureStorage(),
        _http = client ?? http.Client();

  final DeviceService _deviceService;
  final FlutterSecureStorage _storage;
  final http.Client _http;
  Future<void>? _refreshing;
  bool _disposed = false;
  bool loading = true;
  Map<String, dynamic>? account;
  String? _access;
  String? _refresh;

  bool get signedIn => account != null;
  void _notify() { if (!_disposed) notifyListeners(); }

  Future<Map<String, dynamic>> _request(String action, {
    String? access, String? deviceCredential, Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (access != null) 'Authorization': 'Bearer $access',
      if (deviceCredential != null) 'X-NDRL-Device-Credential': deviceCredential,
    };
    try {
      final uri = Uri.parse('$_authApi?action=$action');
      final response = await (action == 'me'
          ? _http.get(uri, headers: headers)
          : _http.post(uri, headers: headers, body: jsonEncode(body ?? <String, dynamic>{})))
          .timeout(const Duration(seconds: 20));
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) throw const AuthException('Unexpected server response');
      if (response.statusCode < 200 || response.statusCode >= 300 || value['success'] != true) {
        final error = value['error'];
        throw AuthException(error is String ? error : 'Request failed (HTTP ${response.statusCode})');
      }
      return value;
    } on AuthException { rethrow; }
      on TimeoutException { throw const AuthException('Connection timed out'); }
      on FormatException { throw const AuthException('Invalid server response'); }
      catch (_) { throw const AuthException('Unable to connect to NDRL DEV'); }
  }

  Future<String> _deviceCredential() async {
    await _deviceService.start();
    final value = await _storage.read(key: _deviceCredentialKey);
    if (value == null || value.isEmpty) {
      throw const AuthException('Device registration is not ready. Check Notification Settings.');
    }
    return value;
  }

  Future<void> _saveTokens(Map<String, dynamic> result) async {
    final access = result['access_token'];
    final refresh = result['refresh_token'];
    if (access is! String || refresh is! String || access.isEmpty || refresh.isEmpty) {
      throw const AuthException('Server did not return login tokens');
    }
    // Persist refresh first: on interrupted writes, never retain a stale refresh token.
    await _storage.write(key: _refreshKey, value: refresh);
    await _storage.write(key: _accessKey, value: access);
    _refresh = refresh;
    _access = access;
  }

  Future<void> _clearLocal() async {
    _access = null;
    _refresh = null;
    account = null;
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    _notify();
  }

  Future<void> restore() async {
    loading = true;
    _notify();
    try {
      _access = await _storage.read(key: _accessKey);
      _refresh = await _storage.read(key: _refreshKey);
      if (_refresh == null) { await _clearLocal(); return; }
      if (_access != null) {
        try { await _loadMe(); return; } on AuthException { /* Refresh below. */ }
      }
      await refresh();
      await _loadMe();
    } catch (_) {
      // Network failures must not destroy stored credentials. User can retry.
      account = null;
    } finally { loading = false; _notify(); }
  }

  Future<void> _loadMe() async {
    final access = _access;
    if (access == null) throw const AuthException('Not signed in');
    final result = await _request('me', access: access);
    final value = result['account'];
    if (value is! Map<String, dynamic>) throw const AuthException('Invalid member profile');
    account = value;
    _notify();
  }

  Future<void> login(String email, String pin) async {
    loading = true; _notify();
    try {
      final deviceCredential = await _deviceCredential();
      final result = await _request('login', deviceCredential: deviceCredential,
        body: {'email': email.trim(), 'pin': pin});
      await _saveTokens(result);
      final value = result['account'];
      if (value is! Map<String, dynamic>) throw const AuthException('Invalid member profile');
      account = value;
    } finally { loading = false; _notify(); }
  }

  Future<void> refresh() {
    if (_refreshing != null) return _refreshing!;
    final future = _doRefresh();
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null);
  }

  Future<void> _doRefresh() async {
    final token = _refresh;
    if (token == null) throw const AuthException('Please sign in');
    final credential = await _deviceCredential();
    final result = await _request('refresh', deviceCredential: credential,
      body: {'refresh_token': token});
    await _saveTokens(result);
  }

  Future<void> retry() async {
    loading = true; _notify();
    try {
      if (_refresh == null) _refresh = await _storage.read(key: _refreshKey);
      await refresh();
      await _loadMe();
    } finally { loading = false; _notify(); }
  }

  Future<void> logout({bool allDevices = false}) async {
    final access = _access;
    if (access == null) throw const AuthException('Session unavailable; cannot confirm server logout');
    try {
      await _request(allDevices ? 'logout_all' : 'logout', access: access);
    } on AuthException {
      // An expired access token cannot perform logout; refresh and retry once.
      await refresh();
      await _request(allDevices ? 'logout_all' : 'logout', access: _access);
    }
    await _clearLocal();
  }

  @override
  void dispose() { _disposed = true; _http.close(); super.dispose(); }
}
