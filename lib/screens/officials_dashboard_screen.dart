import 'package:flutter/material.dart';

import '../services/official_access_service.dart';

class NdrlOfficialsDashboardScreen extends StatefulWidget {
  const NdrlOfficialsDashboardScreen({super.key, required this.officials});
  final OfficialAccessService officials;

  @override
  State<NdrlOfficialsDashboardScreen> createState() => _NdrlOfficialsDashboardScreenState();
}

class _NdrlOfficialsDashboardScreenState extends State<NdrlOfficialsDashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.officials.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.officials.refresh();
    });
  }

  void _changed() { if (mounted) setState(() {}); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.officials.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.officials.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.officials;
    final access = service.access;
    return Scaffold(
      appBar: AppBar(title: const Text('Officials / Race Control'), actions: [
        IconButton(icon: const Icon(Icons.refresh), tooltip: 'Recheck access',
          onPressed: service.loading ? null : service.refresh),
      ]),
      body: service.loading
        ? const Center(child: CircularProgressIndicator())
        : !access.enabled
          ? Center(child: Padding(padding: const EdgeInsets.all(24),
              child: Text(service.error ?? 'Official access is not available for this account.',
                textAlign: TextAlign.center)))
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text('Official roles: ${access.roles.join(', ')}',
                style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (access.canCallLanes) _section(context, Icons.flag_outlined,
                'Staging Lane Calls',
                'Select an event, class, and call type. Sending will be enabled when the authenticated mobile API is ready.',
                access.allClasses ? 'Class scope: all authorized event classes'
                  : 'Authorized class IDs: ${access.classIds.join(', ')}'),
              if (access.canAnnounceEvent) _section(context, Icons.campaign_outlined,
                'Event Announcements',
                'Compose and review event announcements. Publishing is not available yet.',
                'Event scope is enforced by the backend.'),
              if (access.canViewHistory) _section(context, Icons.history,
                'Notification History',
                'History will appear when the mobile history API is available.',
                'No notification records are loaded.'),
              const SizedBox(height: 12),
              const Text('DEV preview only. No notifications can be sent from this screen.',
                style: TextStyle(color: Colors.white70)),
            ]),
    );
  }

  Widget _section(BuildContext context, IconData icon, String title,
      String description, String scope) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon), const SizedBox(width: 10),
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge))]),
      const SizedBox(height: 12), Text(description),
      const SizedBox(height: 8), Text(scope,
        style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 12), const FilledButton(
        onPressed: null, child: Text('Awaiting backend API')),
    ]),
  ));
}
