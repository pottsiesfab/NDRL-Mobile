import 'package:flutter/material.dart';

import '../services/official_access_service.dart';
import 'officials_event_announcements_screen.dart';
import 'officials_lane_calls_screen.dart';
import 'officials_notification_history_screen.dart';

class NdrlOfficialsDashboardScreen extends StatefulWidget {
  const NdrlOfficialsDashboardScreen({super.key, required this.officials});
  final OfficialAccessService officials;

  @override
  State<NdrlOfficialsDashboardScreen> createState() => _OfficialsMenuState();
}

class _OfficialsMenuState extends State<NdrlOfficialsDashboardScreen>
    with WidgetsBindingObserver {
  // High-contrast daylight palette matching Staging Lane Control
  static const Color _bgPage = Color(0xFFE2E8F0);
  static const Color _bgCard = Color(0xFFFFFFFF);
  static const Color _inkPrimary = Color(0xFF0F172A);
  static const Color _inkSecondary = Color(0xFF334155);
  static const Color _borderStrong = Color(0xFF0F172A);
  static const Color _accentPrimary = Color(0xFFB91C1C);
  static const Color _accentGold = Color(0xFFFACC15);
  static const Color _accentSuccess = Color(0xFF15803D);

  bool refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.officials.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    if (refreshing) return;
    setState(() => refreshing = true);
    try {
      await widget.officials.refresh();
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.officials.removeListener(_changed);
    super.dispose();
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final access = widget.officials.access;
    final busy = refreshing || widget.officials.loading;

    return Theme(
      data: ThemeData.light().copyWith(
        scaffoldBackgroundColor: _bgPage,
        colorScheme: const ColorScheme.light(
          primary: _inkPrimary,
          secondary: _accentPrimary,
          surface: _bgCard,
        ),
      ),
      child: Scaffold(
        backgroundColor: _bgPage,
        appBar: AppBar(
          backgroundColor: _inkPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'RACE CONTROL CONSOLE',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 0.8,
            ),
          ),
          actions: [
            IconButton(
              onPressed: busy ? null : _refresh,
              tooltip: 'Refresh permissions',
              icon: const Icon(Icons.refresh, size: 28),
            ),
          ],
        ),
        body: busy
            ? const Center(child: CircularProgressIndicator(strokeWidth: 4))
            : !access.enabled
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.officials.error ??
                            'Official access unavailable.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _inkPrimary,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                    children: [
                      _roleStatusBanner(access),
                      const SizedBox(height: 14),
                      if (access.canCallLanes) ...[
                        _consoleTile(
                          icon: Icons.flag,
                          badgeText: 'TRACKSIDE CALLS',
                          badgeColor: _accentPrimary,
                          title: 'STAGING LANE CALLS',
                          subtitle:
                              'Call classes to staging lanes or on deck with live preview',
                          onTap: () => _open(
                            NdrlOfficialsLaneCallsScreen(
                              officials: widget.officials,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (access.canAnnounceEvent) ...[
                        _consoleTile(
                          icon: Icons.campaign,
                          badgeText: 'BROADCAST',
                          badgeColor: const Color(0xFFD97706),
                          title: 'EVENT ANNOUNCEMENTS',
                          subtitle:
                              'Send schedule updates, weather alerts, or pit notices',
                          onTap: () => _open(
                            NdrlOfficialsEventAnnouncementsScreen(
                              officials: widget.officials,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (access.canViewHistory) ...[
                        _consoleTile(
                          icon: Icons.history,
                          badgeText: 'LOG & STATUS',
                          badgeColor: _accentSuccess,
                          title: 'NOTIFICATION HISTORY',
                          subtitle:
                              'Verify sent lane calls, timestamps, and delivery counts',
                          onTap: () => _open(
                            NdrlOfficialsHistoryScreen(
                              officials: widget.officials,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _roleStatusBanner(dynamic access) {
    final roleLabel = access.roles.isEmpty
        ? 'OFFICIAL'
        : access.roles.join(', ').toUpperCase();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border.all(color: _borderStrong, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _accentGold,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _inkPrimary, width: 1.5),
            ),
            child: Text(
              'ROLE: $roleLabel',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: _inkPrimary,
              ),
            ),
          ),
          const Spacer(),
          const Text(
            'DAYLIGHT MODE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: _inkSecondary,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _consoleTile({
    required IconData icon,
    required String badgeText,
    required Color badgeColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _bgCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderStrong, width: 2.5),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _inkPrimary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _accentGold, width: 2),
                ),
                child: Icon(icon, color: _accentGold, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _inkPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios,
                color: _inkPrimary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
