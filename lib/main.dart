import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'firebase_options.dart';

const _deviceApi = 'https://dev.nostalgiadragleague.com/api/notify_device_api.php';
const _credentialKey = 'ndrl_dev_device_credential';
const _deviceIdKey = 'ndrl_dev_device_id';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const NdrlApp());
}

class NdrlApp extends StatelessWidget {
  const NdrlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NDRL Notifications Dev',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB91C1C)),
        useMaterial3: true,
      ),
      home: const DeviceRegistrationScreen(),
    );
  }
}

class DeviceRegistrationScreen extends StatefulWidget {
  const DeviceRegistrationScreen({super.key});

  @override
  State<DeviceRegistrationScreen> createState() =>
      _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen> {
  final _storage = const FlutterSecureStorage();
  final _http = http.Client();

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  Future<void>? _syncInProgress;

  String _firebaseStatus = 'Initializing...';
  String _permission = 'Not requested';
  String _serverStatus = 'Not registered';
  String _lastMessage = 'No foreground notifications received';
  String? _token;
  String? _credential;
  int? _deviceId;
  bool _isBusy = false;
  bool _serverHasToken = false;

  @override
  void initState() {
    super.initState();
    _initialize();
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
      response = await _http.get(uri, headers: headers).timeout(
        const Duration(seconds: 20),
      );
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
      // Never include credentials, tokens, or raw response bodies in errors.
      throw StateError('API $action failed (HTTP ${response.statusCode}): '
          '${decoded['error'] ?? 'Unknown error'}');
    }
    return decoded;
  }

  Future<void> _initialize() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (!mounted) return;
      setState(() => _permission = settings.authorizationStatus.name);

      _tokenSubscription = messaging.onTokenRefresh.listen((newToken) {
        if (!mounted) return;
        setState(() => _token = newToken);
        _syncTokenToServer();
      });

      _messageSubscription = FirebaseMessaging.onMessage.listen((message) {
        if (!mounted) return;
        setState(() {
          _lastMessage = message.notification?.title ??
              (message.data.isNotEmpty ? message.data.toString() : 'Message received');
        });
      });

      _credential = await _storage.read(key: _credentialKey);
      final savedDeviceId = await _storage.read(key: _deviceIdKey);
      _deviceId = int.tryParse(savedDeviceId ?? '');

      if (_credential != null) {
        final me = await _api('me', credential: _credential);
        final device = me['device'];
        if (device is Map<String, dynamic>) {
          _deviceId = (device['device_id'] as num).toInt();
        }
      } else {
        // Only register when no credential exists. Don't create a new identity
        // when an existing device has a temporary connection/authentication error.
        final registered = await _api('register', data: {'platform': 'android'});
        final newCredential = registered['credential'];
        final newDeviceId = registered['device_id'];
        if (newCredential is! String || newDeviceId is! num) {
          throw StateError('Registration response missing device credential');
        }
        await _storage.write(key: _credentialKey, value: newCredential);
        await _storage.write(key: _deviceIdKey, value: '${newDeviceId.toInt()}');
        _credential = newCredential;
        _deviceId = newDeviceId.toInt();
      }

      if (!mounted) return;
      setState(() => _serverStatus = 'Device registered (ID $_deviceId)');
      await _refreshToken();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _firebaseStatus = 'Setup incomplete';
        _serverStatus = '$e';
      });
    }
  }

  Future<void> _refreshToken() async {
    try {
      if (mounted) setState(() => _firebaseStatus = 'Requesting FCM token...');
      final token = await FirebaseMessaging.instance.getToken();
      if (!mounted) return;
      setState(() {
        _token = token;
        _firebaseStatus = token == null
            ? 'FCM token unavailable'
            : 'Firebase Messaging connected!';
      });
      if (token != null) await _syncTokenToServer();
    } catch (e) {
      if (!mounted) return;
      setState(() => _firebaseStatus = 'FCM token request failed: $e');
    }
  }

  Future<void> _syncTokenToServer() {
    // Serialize token writes to avoid overlapping requests on token refresh.
    if (_syncInProgress != null) return _syncInProgress!;
    final task = _performTokenSync();
    _syncInProgress = task;
    return task.whenComplete(() => _syncInProgress = null);
  }

  Future<void> _performTokenSync() async {
    final credential = _credential;
    final token = _token;
    if (credential == null || token == null) return;

    if (mounted) setState(() => _isBusy = true);
    try {
      final result = await _api(
        'token.set',
        credential: credential,
        data: {'push_token': token},
      );
      if (!mounted) return;
      setState(() {
        _serverHasToken = result['push_token_registered'] == true;
        _serverStatus = 'Device $_deviceId: FCM token saved in NDRL DEV';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serverHasToken = false;
        _serverStatus = '$e';
      });
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  void dispose() {
    _tokenSubscription?.cancel();
    _messageSubscription?.cancel();
    _http.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokenPreview = _token == null
        ? 'Not available'
        : '${_token!.substring(0, _token!.length < 12 ? _token!.length : 12)}...';

    return Scaffold(
      appBar: AppBar(
        title: const Text('NDRL Notifications · DEV'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.notifications_active, size: 64, color: Color(0xFFB91C1C)),
            const SizedBox(height: 16),
            const Text(
              'NDRL Device Registration Test',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Firebase Status', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_firebaseStatus),
                    const Divider(height: 24),
                    const Text('Notification Permission', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_permission),
                    const Divider(height: 24),
                    const Text('Firebase Token (preview)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(tokenPreview),
                    Text('Length: ${_token?.length ?? 0}'),
                    const Divider(height: 24),
                    const Text('NDRL Development Server', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_serverStatus),
                    if (_deviceId != null) Text('Device ID: $_deviceId'),
                    Text('FCM token stored: ${_serverHasToken ? 'YES' : 'NOT YET'}'),
                    const Divider(height: 24),
                    const Text('Last Foreground Notification', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_lastMessage),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isBusy ? null : _refreshToken,
              icon: const Icon(Icons.sync),
              label: const Text('Refresh and Sync FCM Token'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Development only. Does not subscribe to a class or send push notifications.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
