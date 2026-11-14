import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/device_service.dart';
import 'services/auth_service.dart';
import 'screens/version_gate_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const NdrlApp());
}

class NdrlApp extends StatefulWidget {
  const NdrlApp({super.key});

  @override
  State<NdrlApp> createState() => _NdrlAppState();
}

class _NdrlAppState extends State<NdrlApp> {
  late final DeviceService _deviceService;
  late final AuthService _authService;
  bool _splashFinished = false;

  @override
  void initState() {
    super.initState();
    _deviceService = DeviceService();
    _authService = AuthService(deviceService: _deviceService);
    unawaited(_authService.restore());
    // Device registration runs independently of the splash and dashboard.
    // The service captures setup failures in its status fields.
    unawaited(_deviceService.start());
  }

  @override
  void dispose() {
    _authService.dispose();
    _deviceService.dispose();
    super.dispose();
  }

  void _finishSplash() {
    if (!mounted || _splashFinished) return;
    setState(() => _splashFinished = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nostalgia Drag Racing League',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF111111),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB91C1C),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: _splashFinished
          ? NdrlVersionGateScreen(authService: _authService)
          : NdrlSplashScreen(onFinished: _finishSplash),
    );
  }
}
