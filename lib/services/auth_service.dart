import '../config/app_config.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'device_service.dart';

const _authApi = '${AppConfig.baseUrl}/api/mobile_auth_api.php';
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
  AuthService({
    required this._deviceService,
    FlutterSecureStorage? storage,
    http.Client? client,
  }) : _storage = storage ?? const FlutterSecureStorage(),
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

  /// DEV diagnostics only. Never log or include this token in support reports.
  /// Release builds intentionally cannot reveal bearer credentials.
  Future<String?> devDiagnosticAccessToken() async {
    if (kReleaseMode || !_authApi.contains('://dev.')) return null;
    if (_access == null && _refresh != null) await refresh();
    return _access;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<Map<String, dynamic>> _request(
    String action, {
    String? access,
    String? deviceCredential,
    Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (access != null) 'Authorization': 'Bearer $access',
      'X-NDRL-Device-Credential': ?deviceCredential,
    };
    try {
      final uri = Uri.parse('$_authApi?action=$action');
      final response =
          await (action == 'me'
                  ? _http.get(uri, headers: headers)
                  : _http.post(
                      uri,
                      headers: headers,
                      body: jsonEncode(body ?? <String, dynamic>{}),
                    ))
              .timeout(const Duration(seconds: 20));
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) {
        throw const AuthException('Unexpected server response');
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          value['success'] != true) {
        final error = value['error'];
        throw AuthException(
          error is String
              ? error
              : 'Request failed (HTTP ${response.statusCode})',
        );
      }
      return value;
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException('Connection timed out');
    } on FormatException {
      throw const AuthException('Invalid server response');
    } catch (_) {
      throw const AuthException('Unable to connect to NDRL DEV');
    }
  }

  Future<String> _deviceCredential() async {
    await _deviceService.start();
    final value = await _storage.read(key: _deviceCredentialKey);
    if (value == null || value.isEmpty) {
      throw const AuthException(
        'Device registration is not ready. Check Notification Settings.',
      );
    }
    return value;
  }

  Future<void> _saveTokens(Map<String, dynamic> result) async {
    final access = result['access_token'];
    final refresh = result['refresh_token'];
    if (access is! String ||
        refresh is! String ||
        access.isEmpty ||
        refresh.isEmpty) {
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
      if (_refresh == null) {
        await _clearLocal();
        return;
      }
      if (_access != null) {
        try {
          await _loadMe();
          return;
        } on AuthException {
          /* Refresh below. */
        }
      }
      await refresh();
      await _loadMe();
    } catch (_) {
      // Network failures must not destroy stored credentials. User can retry.
      account = null;
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> _loadMe() async {
    final access = _access;
    if (access == null) throw const AuthException('Not signed in');
    final result = await _request('me', access: access);
    final value = result['account'];
    if (value is! Map<String, dynamic>) {
      throw const AuthException('Invalid member profile');
    }
    account = value;
    _notify();
  }

  /// Authenticated read-only member profile request. Refresh once on HTTP 401.

  /// Authenticated GET for DEV APIs; refreshes once if the access token expires.
  Future<Map<String, dynamic>> authorizedGet(Uri uri) async {
    if (_access == null) {
      if (_refresh == null) throw const AuthException('Please sign in');
      await refresh();
    }
    Future<http.Response> fetch() => _http
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $_access',
          },
        )
        .timeout(const Duration(seconds: 20));
    try {
      var response = await fetch();
      if (response.statusCode == 401) {
        await refresh();
        response = await fetch();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AuthException('Unexpected server response');
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['success'] != true) {
        throw AuthException(
          decoded['error']?.toString() ??
              'Request failed (HTTP ${response.statusCode})',
        );
      }
      return decoded;
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException('Request timed out');
    } on FormatException {
      throw const AuthException('Invalid server response');
    } catch (_) {
      throw const AuthException('Unable to connect to NDRL DEV');
    }
  }

  /// Authenticated JSON POST; refresh once on HTTP 401.
  /// On timeout, caller should reload server state before retrying a save.
  Future<Map<String, dynamic>> authorizedPost(
    Uri uri,
    Map<String, dynamic> body,
  ) async {
    if (_access == null) {
      if (_refresh == null) throw const AuthException('Please sign in');
      await refresh();
    }
    Future<http.Response> send() => _http
        .post(
          uri,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_access',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));
    try {
      var response = await send();
      if (response.statusCode == 401) {
        await refresh();
        response = await send();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AuthException('Unexpected server response');
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['success'] != true) {
        throw AuthException(
          decoded['error']?.toString() ??
              'Request failed (HTTP ${response.statusCode})',
        );
      }
      return decoded;
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException(
        'Request timed out; reload roster before retrying',
      );
    } on FormatException {
      throw const AuthException('Invalid server response');
    } catch (_) {
      throw const AuthException('Unable to connect to NDRL DEV');
    }
  }

  /// Authenticated multipart upload; retries only when the server explicitly
  /// returns 401. Never retry an uncertain network failure automatically.
  Future<Map<String, dynamic>> authorizedMultipart(
    Uri uri, {
    required Map<String, String> fields,
    required XFile file,
  }) async {
    if (_access == null) {
      if (_refresh == null) throw const AuthException('Please sign in');
      await refresh();
    }
    Future<http.Response> send() async {
      final request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $_access';
      request.fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      final streamed = await _http.send(request).timeout(const Duration(seconds: 60));
      return http.Response.fromStream(streamed);
    }
    try {
      var response = await send();
      if (response.statusCode == 401) {
        await refresh();
        response = await send();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AuthException('Unexpected upload response');
      }
      if (response.statusCode < 200 || response.statusCode >= 300 || decoded['success'] != true) {
        throw AuthException(decoded['error']?.toString() ?? 'Upload failed (HTTP ${response.statusCode})');
      }
      return decoded;
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException('Upload timed out; check the image before retrying');
    } on FormatException {
      throw const AuthException('Invalid upload response');
    } catch (_) {
      throw const AuthException('Unable to upload image; check connection');
    }
  }

  Future<Map<String, dynamic>> loadMemberProfile() async {
    if (_access == null) {
      if (_refresh == null) throw const AuthException('Please sign in');
      await refresh();
    }
    Future<http.Response> fetch() => _http
        .get(
          Uri.parse(
            '${AppConfig.baseUrl}/api/mobile_profile_api.php?action=me',
          ),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $_access',
          },
        )
        .timeout(const Duration(seconds: 20));
    try {
      var response = await fetch();
      if (response.statusCode == 401) {
        await refresh();
        response = await fetch();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AuthException('Unexpected profile response');
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['success'] != true) {
        throw AuthException(
          decoded['error'] is String
              ? decoded['error'] as String
              : 'Profile request failed (HTTP ${response.statusCode})',
        );
      }
      return decoded;
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException('Profile request timed out');
    } on FormatException {
      throw const AuthException('Invalid profile response');
    } catch (_) {
      throw const AuthException('Unable to load member profile');
    }
  }

  Future<Map<String, dynamic>> updateMemberProfile(
    Map<String, dynamic> fields,
  ) async {
    Future<http.Response> send() => _http
        .post(
          Uri.parse(
            '${AppConfig.baseUrl}/api/mobile_profile_api.php?action=update_profile',
          ),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_access',
          },
          body: jsonEncode(fields),
        )
        .timeout(const Duration(seconds: 20));
    try {
      if (_access == null) await refresh();
      var response = await send();
      if (response.statusCode == 401) {
        await refresh();
        response = await send();
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw const AuthException('Unexpected server response');
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          data['success'] != true) {
        throw AuthException(
          data['error'] is String
              ? data['error'] as String
              : 'Save failed (HTTP ${response.statusCode})',
        );
      }
      return data;
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException(
        'Save timed out; refresh profile before retrying',
      );
    } on FormatException {
      throw const AuthException('Invalid server response');
    } catch (_) {
      throw const AuthException('Unable to save profile; check connection');
    }
  }

  static const _profileApi = '${AppConfig.baseUrl}/api/mobile_profile_api.php';

  Future<Map<String, dynamic>> profileAction(
    String action,
    Map<String, dynamic> body,
  ) async {
    Future<http.Response> send() => _http
        .post(
          Uri.parse('$_profileApi?action=$action'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_access',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));
    try {
      if (_access == null) await refresh();
      var response = await send();
      if (response.statusCode == 401) {
        await refresh();
        response = await send();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AuthException('Invalid server response');
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['success'] != true) {
        throw AuthException(
          decoded['error']?.toString() ??
              'Request failed (HTTP ${response.statusCode})',
        );
      }
      return decoded;
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException('Request timed out; refresh before retrying');
    } on FormatException {
      throw const AuthException('Invalid server response');
    } catch (_) {
      throw const AuthException('Unable to connect to NDRL DEV');
    }
  }

  Future<Map<String, dynamic>> uploadProfileImage(
    String action,
    String path, {
    int? carId,
  }) async {
    Future<http.Response> send() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_profileApi?action=$action'),
      );
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $_access';
      if (carId != null) request.fields['member_season_class_id'] = '$carId';
      request.files.add(await http.MultipartFile.fromPath('file', path));
      final streamed = await _http
          .send(request)
          .timeout(const Duration(seconds: 60));
      return http.Response.fromStream(streamed);
    }

    try {
      if (_access == null) await refresh();
      var response = await send();
      if (response.statusCode == 401) {
        await refresh();
        response = await send();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AuthException('Invalid upload response');
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          decoded['success'] != true) {
        throw AuthException(
          decoded['error']?.toString() ??
              'Upload failed (HTTP ${response.statusCode})',
        );
      }
      return decoded;
    } on AuthException {
      rethrow;
    } on TimeoutException {
      throw const AuthException('Upload timed out; refresh before retrying');
    } on FormatException {
      throw const AuthException('Invalid upload response');
    } catch (_) {
      throw const AuthException('Unable to upload image');
    }
  }

  Future<void> login(String email, String pin) async {
    loading = true;
    _notify();
    try {
      final deviceCredential = await _deviceCredential();
      final result = await _request(
        'login',
        deviceCredential: deviceCredential,
        body: {'email': email.trim(), 'pin': pin},
      );
      await _saveTokens(result);
      final value = result['account'];
      if (value is! Map<String, dynamic>) {
        throw const AuthException('Invalid member profile');
      }
      account = value;
    } finally {
      loading = false;
      _notify();
    }
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
    final result = await _request(
      'refresh',
      deviceCredential: credential,
      body: {'refresh_token': token},
    );
    await _saveTokens(result);
  }

  Future<void> retry() async {
    loading = true;
    _notify();
    try {
      _refresh ??= await _storage.read(key: _refreshKey);
      await refresh();
      await _loadMe();
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<void> logout({bool allDevices = false}) async {
    final access = _access;
    if (access == null) {
      throw const AuthException(
        'Session unavailable; cannot confirm server logout',
      );
    }
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
  void dispose() {
    _disposed = true;
    _http.close();
    super.dispose();
  }
}
