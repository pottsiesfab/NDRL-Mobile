import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'app_shell.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

/// Account entry point: sign in when logged out; show a simple account
/// summary when signed in. The full member profile is a separate route.
class NdrlAccountScreen extends StatefulWidget {
  const NdrlAccountScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<NdrlAccountScreen> createState() => _NdrlAccountScreenState();
}

class _NdrlAccountScreenState extends State<NdrlAccountScreen> {
  bool _loggingOut = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.authService.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant NdrlAccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authService != widget.authService) {
      oldWidget.authService.removeListener(_changed);
      widget.authService.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.authService.removeListener(_changed);
    super.dispose();
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() {
      _loggingOut = true;
      _error = null;
    });
    try {
      await widget.authService.logout();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.authService;
    if (auth.loading && !auth.signedIn) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.signedIn) {
      return NdrlLoginScreen(authService: auth);
    }

    final rawName = (auth.account?['display_name'] ?? '').toString().trim();
    final name = rawName.isEmpty ? 'NDRL Member' : rawName;
    return Scaffold(
      backgroundColor: ndrlBackground,
      appBar: AppBar(
        backgroundColor: ndrlBackground,
        title: const Text('My Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 18),
          const Icon(Icons.account_circle_outlined, color: ndrlGold, size: 84),
          const SizedBox(height: 16),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Signed in to NDRL',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NdrlProfileScreen(authService: auth),
              ),
            ),
            icon: const Icon(Icons.person_outline),
            label: const Text('View My Profile'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loggingOut ? null : _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
          if (_loggingOut) const LinearProgressIndicator(color: ndrlRed),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
        ],
      ),
    );
  }
}
