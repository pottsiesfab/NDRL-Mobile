import 'package:flutter/material.dart';

import 'staging_screen.dart';
import 'alerts_screen.dart';
import 'notification_settings_screen.dart';
import 'events_screen.dart';
import 'sponsors_screen.dart';
import 'season_points_screen.dart';
import 'fantasy/fantasy_hub_screen.dart';
import 'members_screen.dart';
import '../widgets/sponsor_ad_widget.dart';
import '../services/auth_service.dart';
import 'account_screen.dart';
import 'diagnostics_screen.dart';
import 'about_ndrl_screen.dart';
import 'news_screen.dart';
import 'rules_screen.dart';
import '../services/official_access_service.dart';
import 'officials_dashboard_screen.dart';

const ndrlBackground = Color(0xFF111111);
const ndrlSurface = Color(0xFF242428);
const ndrlRed = Color(0xFFB91C1C);
const ndrlGold = Color(0xFFD1AC67);

class NdrlAppShell extends StatefulWidget {
  const NdrlAppShell({super.key, required this.authService});

  final AuthService authService;

  @override
  State<NdrlAppShell> createState() => _NdrlAppShellState();
}

class _NdrlAppShellState extends State<NdrlAppShell> {
  int _selectedIndex = 0;
  late final OfficialAccessService _officials;

  @override
  void initState() {
    super.initState();
    _officials = OfficialAccessService(widget.authService);
    WidgetsBinding.instance.addObserver(_officialsLifecycle);
  }

  late final WidgetsBindingObserver _officialsLifecycle = _OfficialLifecycle(
    onResume: () { if (mounted) _officials.refresh(); },
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_officialsLifecycle);
    _officials.dispose();
    super.dispose();
  }

  void _openOfficials() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NdrlOfficialsDashboardScreen(officials: _officials),
    ));
  }


  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.flag_outlined),
      selectedIcon: Icon(Icons.flag),
      label: 'Staging',
    ),
    NavigationDestination(
      icon: Icon(Icons.event_outlined),
      selectedIcon: Icon(Icons.event),
      label: 'Events',
    ),
    NavigationDestination(
      icon: Icon(Icons.notifications_outlined),
      selectedIcon: Icon(Icons.notifications),
      label: 'Alerts',
    ),
    NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
  ];

  void _openStaging() {
    setState(() => _selectedIndex = 1);
  }

  void _openFeature(String title) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => title == 'Contact Us'
            ? const NdrlAboutScreen(contactsOnly: true)
            : title == 'NDRL Rules'
            ? const NdrlRulesScreen()
            : title == 'NDRL News'
            ? const NdrlNewsScreen()
            : title == 'About NDRL'
            ? const NdrlAboutScreen()
            : title == 'Fantasy Racing'
            ? NdrlFantasyHubScreen(authService: widget.authService)
            : title == 'NDRL Members' || title == 'Driver Profiles'
            ? const NdrlMembersScreen()
            : title == 'Our Sponsors'
            ? const NdrlSponsorsScreen()
            : title == 'Season Points'
            ? const NdrlSeasonPointsScreen()
            : NdrlFeatureScreen(title: title),
      ),
    );
  }

  void _openDiagnostics() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NdrlDiagnosticsScreen(authService: widget.authService),
      ),
    );
  }

  void _openAccount() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NdrlAccountScreen(authService: widget.authService),
      ),
    );
  }

  void _openNotificationSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: ndrlBackground,
          appBar: AppBar(
            backgroundColor: ndrlBackground,
            title: const Text('Notification Settings'),
          ),
          body: const NdrlNotificationSettingsScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeScreen(
        onOpenFeature: _openFeature,
        onOpenStaging: _openStaging,
        isActive: _selectedIndex == 0,
      ),
      NdrlStagingScreen(isActive: _selectedIndex == 1),
      const NdrlEventsScreen(),
      const NdrlAlertsScreen(),
      ListenableBuilder(
        listenable: _officials,
        builder: (context, _) => _MoreScreen(
          officials: _officials,
          onOpenOfficials: _openOfficials,
          onOpenFeature: _openFeature,
          onOpenNotificationSettings: _openNotificationSettings,
          onOpenAccount: _openAccount,
          onOpenDiagnostics: _openDiagnostics,
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: ndrlBackground,
      appBar: AppBar(
        backgroundColor: ndrlBackground,
        foregroundColor: Colors.white,
        title: const Text(
          'NDRL MOBILE',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        actions: [
          IconButton(
            tooltip: 'Sponsors',
            icon: const Icon(Icons.handshake_outlined),
            onPressed: () => _openFeature('Our Sponsors'),
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        backgroundColor: ndrlSurface,
        indicatorColor: ndrlRed,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: _destinations,
      ),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({
    required this.onOpenFeature,
    required this.onOpenStaging,
    required this.isActive,
  });

  final void Function(String) onOpenFeature;
  final VoidCallback onOpenStaging;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Image.asset(
            'assets/images/ndrl_logo.png',
            height: 190,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Text(
              'NDRL',
              style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          color: ndrlRed,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onOpenStaging,
            child: const Padding(
              padding: EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RACE DAY',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Live Staging Board',
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 8),
                  Text('Current class calls and racing rounds'),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(Icons.arrow_forward, size: 28),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'EXPLORE NDRL',
          style: TextStyle(
            color: ndrlGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _FeatureTile(
              title: 'Season Points',
              icon: Icons.emoji_events_outlined,
              onTap: () => onOpenFeature('Season Points'),
            ),
            _FeatureTile(
              title: 'Fantasy Racing',
              icon: Icons.sports_score,
              onTap: () => onOpenFeature('Fantasy Racing'),
            ),
            _FeatureTile(
              title: 'NDRL Members',
              icon: Icons.people_outline,
              onTap: () => onOpenFeature('Driver Profiles'),
            ),
            _FeatureTile(
              title: 'Our Sponsors',
              icon: Icons.handshake_outlined,
              onTap: () => onOpenFeature('Our Sponsors'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        NdrlSponsorAdWidget(
          placement: 'home_featured',
          isActive: isActive,
          heading: 'FEATURED NDRL PARTNER',
        ),
        const SizedBox(height: 16),
        NdrlSponsorAdWidget(
          placement: 'home_rotation',
          isActive: isActive,
          heading: 'NDRL SPONSORS',
        ),
      ],
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: ndrlSurface,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: ndrlGold, size: 32),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SponsorPlacement extends StatelessWidget {
  const SponsorPlacement({super.key});

  @override
  Widget build(BuildContext context) {
    // Temporary visual placeholder.
    // Future implementation will consume the sponsor API.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FEATURED NDRL PARTNER',
          style: TextStyle(
            color: ndrlGold,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 110,
          width: double.infinity,
          decoration: BoxDecoration(
            color: ndrlSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, color: Colors.white54),
              SizedBox(height: 8),
              Text(
                'Sponsor placement',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class NdrlFeatureScreen extends StatelessWidget {
  const NdrlFeatureScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ndrlBackground,
      appBar: Navigator.of(context).canPop()
          ? AppBar(backgroundColor: ndrlBackground, title: Text(title))
          : null,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          const Text(
            'This feature is being prepared for the NDRL Mobile App.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 30),
          const SponsorPlacement(),
        ],
      ),
    );
  }
}

class _OfficialLifecycle extends WidgetsBindingObserver {
  _OfficialLifecycle({required this.onResume});
  final VoidCallback onResume;
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen({
    required this.onOpenFeature,
    required this.officials,
    required this.onOpenOfficials,
    required this.onOpenNotificationSettings,
    required this.onOpenAccount,
    required this.onOpenDiagnostics,
  });

  final void Function(String) onOpenFeature;
  final OfficialAccessService officials;
  final VoidCallback onOpenOfficials;
  final VoidCallback onOpenNotificationSettings;
  final VoidCallback onOpenAccount;
  final VoidCallback onOpenDiagnostics;

  @override
  Widget build(BuildContext context) {
    const entries = [
      ('My Account', Icons.account_circle_outlined),
      ('Our Sponsors', Icons.handshake_outlined),
      ('Season Points', Icons.emoji_events_outlined),
      ('Fantasy Racing', Icons.sports_score),
      ('NDRL Members', Icons.people_outline),
      ('Notification Settings', Icons.settings_outlined),
      ('Diagnostics', Icons.monitor_heart_outlined),
      ('About NDRL', Icons.info_outline),
      ('Contact Us', Icons.contact_phone_outlined),
      ('NDRL News', Icons.newspaper_outlined),
      ('NDRL Rules', Icons.menu_book_outlined),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'MORE NDRL',
          style: TextStyle(
            color: ndrlGold,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        if (officials.access.enabled)
          Card(color: ndrlSurface, child: ListTile(
            leading: const Icon(Icons.shield_outlined, color: ndrlGold),
            title: const Text('Officials / Race Control'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenOfficials,
          )),
        for (final entry in entries)
          Card(
            color: ndrlSurface,
            child: ListTile(
              leading: Icon(entry.$2, color: ndrlGold),
              title: Text(entry.$1),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                if (entry.$1 == 'My Account') {
                  onOpenAccount();
                } else if (entry.$1 == 'Diagnostics') {
                  onOpenDiagnostics();
                } else if (entry.$1 == 'Notification Settings') {
                  onOpenNotificationSettings();
                } else {
                  onOpenFeature(entry.$1);
                }
              },
            ),
          ),
        const SizedBox(height: 24),
        const NdrlSponsorAdWidget(
          placement: 'home_featured',
          isActive: true,
          heading: 'FEATURED NDRL PARTNER',
        ),
      ],
    );
  }
}
