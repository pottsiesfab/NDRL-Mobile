import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _deviceApi =
    'https://dev.nostalgiadragleague.com/api/notify_device_api.php';
const _credentialKey = 'ndrl_dev_device_credential';
const _deviceIdKey = 'ndrl_dev_device_id';

/// Owns DEV device identity and FCM registration independently of any screen.
/// Firebase.initializeApp must be called before start().
class DeviceService extends ChangeNotifier {
  DeviceService({FlutterSecureStorage? storage, http.Client? client})
    : _storage = storage ?? const FlutterSecureStorage(),
      _http = client ?? http.Client();

  final FlutterSecureStorage _storage;
  final http.Client _http;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  Future<void>? _syncInProgress;
  Future<void>? _startInProgress;
  bool _disposed = false;

  String firebaseStatus = 'Initializing...';
  String permission = 'Not requested';
  String serverStatus = 'Not registered';
  String lastMessage = 'No foreground notifications received';
  String? _token;
  String? _credential;
  int? deviceId;
  bool isBusy = false;
  bool serverHasToken = false;

  bool get hasCredential => _credential != null;
  String get tokenPreview {
    final token = _token;
    if (token == null) return 'Not available';
    return '${token.substring(0, token.length < 12 ? token.length : 12)}...';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<Map<String, dynamic>> _api(
    String action, {
    Map<String, dynamic>? data,
    String? credential,
  }) async {
    final uri = Uri.parse('$_deviceApi?action=$action');
    final headers = <String, String>{
      if (data != null) 'Content-Type': 'application/json',
      if (credential != null) 'Authorization': 'Bearer $credential',
    };

    final http.Response response;
    if (data == null) {
      response = await _http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 20));
    } else {
      response = await _http
          .post(uri, headers: headers, body: jsonEncode(data))
          .timeout(const Duration(seconds: 20));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Server returned unexpected JSON');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      // Do not expose credentials, tokens, or raw response bodies.
      throw StateError(
        'API $action failed (HTTP ${response.statusCode}): '
        '${decoded['error'] ?? 'Unknown error'}',
      );
    }
    return decoded;
  }

  Future<void> start() {
    if (_startInProgress != null) return _startInProgress!;
    final task = _initialize();
    _startInProgress = task;
    return task;
  }

  Future<void> _initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (_disposed) return;
      permission = settings.authorizationStatus.name;
      _notify();

      _tokenSubscription = messaging.onTokenRefresh.listen((newToken) {
        if (_disposed) return;
        _token = newToken;
        _notify();
        unawaited(syncTokenToServer());
      });

      _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
        if (_disposed) return;
        lastMessage =
            message.notification?.title ??
            (message.data.isNotEmpty
                ? message.data.toString()
                : 'Message received');
        _notify();
      });

      _credential = await _storage.read(key: _credentialKey);
      final savedDeviceId = await _storage.read(key: _deviceIdKey);
      if (_disposed) return;
      deviceId = int.tryParse(savedDeviceId ?? '');

      if (_credential != null) {
        final me = await _api('me', credential: _credential);
        if (_disposed) return;
        final device = me['device'];
        if (device is Map<String, dynamic>) {
          deviceId = (device['device_id'] as num).toInt();
        }
      } else {
        // Never create a new identity when an existing credential has a
        // temporary connection or authentication error.
        final registered = await _api(
          'register',
          data: {'platform': 'android'},
        );
        if (_disposed) return;
        final newCredential = registered['credential'];
        final newDeviceId = registered['device_id'];
        if (newCredential is! String || newDeviceId is! num) {
          throw StateError('Registration response missing device credential');
        }
        await _storage.write(key: _credentialKey, value: newCredential);
        await _storage.write(
          key: _deviceIdKey,
          value: '${newDeviceId.toInt()}',
        );
        if (_disposed) return;
        _credential = newCredential;
        deviceId = newDeviceId.toInt();
      }

      serverStatus = 'Device registered (ID $deviceId)';
      _notify();
      await refreshToken();
    } catch (e) {
      if (_disposed) return;
      firebaseStatus = 'Setup incomplete';
      serverStatus = '$e';
      _notify();
    }
  }

  Future<void> refreshToken() async {
    try {
      if (_disposed) return;
      firebaseStatus = 'Requesting FCM token...';
      _notify();
      final token = await FirebaseMessaging.instance.getToken();
      if (_disposed) return;
      _token = token;
      firebaseStatus = token == null
          ? 'FCM token unavailable'
          : 'Firebase Messaging connected!';
      _notify();
      if (token != null) await syncTokenToServer();
    } catch (e) {
      if (_disposed) return;
      firebaseStatus = 'FCM token request failed: $e';
      _notify();
    }
  }

  Future<void> syncTokenToServer() {
    if (_disposed) return Future<void>.value();
    if (_syncInProgress != null) return _syncInProgress!;
    final task = _performTokenSync();
    _syncInProgress = task;
    return task.whenComplete(() => _syncInProgress = null);
  }

  Future<void> _performTokenSync() async {
    final credential = _credential;
    final token = _token;
    if (credential == null || token == null) return;

    isBusy = true;
    _notify();
    try {
      final result = await _api(
        'token.set',
        credential: credential,
        data: {'push_token': token},
      );
      if (_disposed) return;
      serverHasToken = result['push_token_registered'] == true;
      serverStatus = 'Device $deviceId: FCM token saved in NDRL DEV';
      _notify();
    } catch (e) {
      if (_disposed) return;
      serverHasToken = false;
      serverStatus = '$e';
      _notify();
    } finally {
      if (!_disposed) {
        isBusy = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _tokenSubscription?.cancel();
    _messageSubscription?.cancel();
    _http.close();
    super.dispose();
  }
}
