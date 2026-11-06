import 'package:flutter/material.dart';

import '../services/official_access_service.dart';
import 'officials_lane_calls_screen.dart';
import 'officials_event_announcements_screen.dart';
import 'officials_notification_history_screen.dart';

class NdrlOfficialsDashboardScreen extends StatefulWidget {
  const NdrlOfficialsDashboardScreen({super.key, required this.officials});
  final OfficialAccessService officials;

  @override
  State<NdrlOfficialsDashboardScreen> createState() => _OfficialsMenuState();
}

class _OfficialsMenuState extends State<NdrlOfficialsDashboardScreen>
    with WidgetsBindingObserver {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Officials / Race Control'),
        actions: [
          IconButton(
            onPressed: busy ? null : _refresh,
            tooltip: 'Refresh permissions',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: busy
          ? const Center(child: CircularProgressIndicator())
          : !access.enabled
          ? Center(
              child: Text(
                widget.officials.error ?? 'Official access unavailable.',
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Roles: ${access.roles.join(', ')}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 20),
                if (access.canCallLanes)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: const Text('Staging Lane Calls'),
                      subtitle: const Text('Select classes, preview and send'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(
                        NdrlOfficialsLaneCallsScreen(
                          officials: widget.officials,
                        ),
                      ),
                    ),
                  ),
                if (access.canViewHistory)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('Notification History'),
                      subtitle: const Text(
                        'View previous calls and delivery status',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(
                        NdrlOfficialsHistoryScreen(officials: widget.officials),
                      ),
                    ),
                  ),
                if (access.canAnnounceEvent)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.campaign_outlined),
                      title: const Text('Event Announcements'),
                      subtitle: const Text(
                        'Write, preview and send an announcement',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(
                        NdrlOfficialsEventAnnouncementsScreen(
                          officials: widget.officials,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
