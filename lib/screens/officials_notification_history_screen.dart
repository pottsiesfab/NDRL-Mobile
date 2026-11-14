import 'package:flutter/material.dart';

import '../services/official_access_service.dart';
import '../services/official_notifications_service.dart';

class NdrlOfficialsHistoryScreen extends StatefulWidget {
  const NdrlOfficialsHistoryScreen({super.key, required this.officials});
  final OfficialAccessService officials;

  @override
  State<NdrlOfficialsHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<NdrlOfficialsHistoryScreen>
    with WidgetsBindingObserver {
  late final OfficialNotificationsService api = OfficialNotificationsService(
    widget.officials.auth,
  );
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> history = [];
  int? eventId;
  int? nextBeforeId;
  bool hasMore = false;
  bool loading = false;
  bool historyLoading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.officials.addListener(_onAccess);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _onAccess() {
    if (!mounted) return;
    if (widget.officials.loading) {
      setState(() {});
      return;
    }
    if (!widget.officials.access.canViewHistory) {
      setState(() {
        events = [];
        history = [];
        eventId = null;
      });
    } else {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.officials.removeListener(_onAccess);
    super.dispose();
  }

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : [];

  Future<void> _reload() async {
    if (loading || historyLoading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.officials.refresh();
      if (!mounted || !widget.officials.access.canViewHistory) return;
      final data = await api.targets(seasonId: widget.officials.seasonId);
      if (!mounted || !widget.officials.access.canViewHistory) return;
      final available = _maps(data['events']);
      final scopes = widget.officials.access.eventIds;
      final authorized = available
          .where((e) => scopes.isEmpty || scopes.contains(e['event_id']))
          .toList();
      setState(() {
        events = authorized;
        if (!events.any((e) => e['event_id'] == eventId)) {
          eventId = events.isEmpty ? null : events.first['event_id'] as int?;
        }
        history = [];
        nextBeforeId = null;
        hasMore = false;
      });
      if (eventId != null) await _loadHistory(refreshAccess: false);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadHistory({
    bool older = false,
    bool refreshAccess = true,
  }) async {
    if (eventId == null || historyLoading) return;
    setState(() {
      historyLoading = true;
      error = null;
    });
    try {
      if (refreshAccess) await widget.officials.refresh();
      if (!mounted || !widget.officials.access.canViewHistory) {
        throw StateError('History permission unavailable');
      }
      final requestedEvent = eventId!;
      final result = await api.history(
        eventId: requestedEvent,
        beforeId: older ? nextBeforeId : null,
      );
      if (!mounted ||
          !widget.officials.access.canViewHistory ||
          eventId != requestedEvent)
        return;
      final page = _maps(result['items']);
      final pagination = result['pagination'];
      setState(() {
        history = older ? [...history, ...page] : page;
        if (pagination is Map) {
          nextBeforeId = pagination['next_before_id'] as int?;
          hasMore = pagination['has_more'] == true;
        } else {
          nextBeforeId = null;
          hasMore = false;
        }
      });
    } catch (e) {
      if (mounted)
        setState(() {
          history = [];
          error = '$e';
        });
    } finally {
      if (mounted) setState(() => historyLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = widget.officials.access;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification History'),
        actions: [
          IconButton(
            onPressed: loading || historyLoading ? null : _reload,
            tooltip: 'Refresh history',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: widget.officials.loading || loading
          ? const Center(child: CircularProgressIndicator())
          : !access.canViewHistory
          ? const Center(child: Text('History access unavailable.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<int>(
                  key: ValueKey(eventId),
                  initialValue: eventId,
                  decoration: const InputDecoration(
                    labelText: 'Authorized event',
                  ),
                  items: events
                      .map(
                        (e) => DropdownMenuItem<int>(
                          value: e['event_id'] as int,
                          child: Text('${e['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: historyLoading
                      ? null
                      : (value) {
                          setState(() {
                            eventId = value;
                            history = [];
                            nextBeforeId = null;
                            hasMore = false;
                          });
                          _loadHistory();
                        },
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SelectableText(
                      error!,
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                if (historyLoading) const LinearProgressIndicator(),
                if (history.isEmpty && !historyLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text('No notification records loaded.'),
                  ),
                ...history.map((batch) {
                  final delivery = batch['delivery'] is Map
                      ? batch['delivery'] as Map
                      : {};
                  final messages = _maps(batch['messages']);
                  return Card(
                    child: ExpansionTile(
                      title: Text(
                        '${batch['outcome'] ?? 'unknown'} · ${_maps(batch['classes']).map((c) => c['name']).join(', ')}',
                      ),
                      subtitle: Text(
                        '${batch['created_at']} · ${batch['official'] is Map ? batch['official']['display_name'] ?? 'Official' : 'Official'}',
                      ),
                      children: [
                        ListTile(
                          title: Text(
                            'Accepted ${delivery['accepted'] ?? 0} · Failed ${delivery['failed'] ?? 0}',
                          ),
                          subtitle: Text(
                            'Skipped ${delivery['skipped'] ?? 0} · In progress ${delivery['in_progress'] ?? 0}\nFCM accepted does not mean displayed on device.',
                          ),
                        ),
                        ...messages.map(
                          (m) => ListTile(
                            title: Text('${m['title']} · ${m['status']}'),
                            subtitle: Text(
                              '${m['body']}\n${m['round_label'] ?? ''} · ${m['message_type'] ?? ''}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (hasMore)
                  OutlinedButton(
                    onPressed: historyLoading
                        ? null
                        : () => _loadHistory(older: true),
                    child: const Text('Load older notifications'),
                  ),
              ],
            ),
    );
  }
}
