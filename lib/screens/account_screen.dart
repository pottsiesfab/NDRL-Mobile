import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'app_shell.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'my_tech_cards_screen.dart';
import 'season_points_screen.dart';

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

  void _openTechCards() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NdrlMyTechCardsScreen(authService: widget.authService),
      ),
    );
  }

  Widget _garageTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      color: ndrlSurface,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, color: ndrlGold, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: ndrlGold),
            ],
          ),
        ),
      ),
    );
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 16),

          const Text(
            'MY GARAGE',
            style: TextStyle(
              color: ndrlGold,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          const Icon(Icons.account_circle_outlined, color: ndrlGold, size: 76),

          const SizedBox(height: 12),

          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 6),

          const Text(
            'Signed in to NDRL',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),

          const SizedBox(height: 32),

          _garageTile(
            icon: Icons.person_outline,
            title: 'My Profile',
            subtitle: 'View and edit your member information',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => NdrlProfileScreen(authService: auth),
              ),
            ),
          ),

          _garageTile(
            icon: Icons.directions_car_outlined,
            title: 'My Vehicles & Tech Cards',
            subtitle: 'Registered race cars and inspections',
            onTap: _openTechCards,
          ),

          _garageTile(
            icon: Icons.emoji_events_outlined,
            title: 'My Championship Points',
            subtitle: 'Season standings and race results',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NdrlSeasonPointsScreen(),
              ),
            ),
          ),

          const SizedBox(height: 24),

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
