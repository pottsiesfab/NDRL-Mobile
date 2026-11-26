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
  // High-contrast daylight palette matching Staging Lane Control
  static const Color _bgPage = Color(0xFFE2E8F0);
  static const Color _bgCard = Color(0xFFFFFFFF);
  static const Color _inkPrimary = Color(0xFF0F172A);
  static const Color _inkSecondary = Color(0xFF334155);
  static const Color _borderStrong = Color(0xFF0F172A);
  static const Color _accentPrimary = Color(0xFFB91C1C);
  static const Color _accentSuccess = Color(0xFF15803D);

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
          eventId != requestedEvent) {
        return;
      }
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
      if (mounted) {
        setState(() {
          history = [];
          error = '$e';
        });
      }
    } finally {
      if (mounted) setState(() => historyLoading = false);
    }
  }

  Color _outcomeColor(String outcome) {
    final lower = outcome.toLowerCase();
    if (lower.contains('fail') || lower.contains('error')) {
      return _accentPrimary;
    }
    if (lower.contains('queue') ||
        lower.contains('progress') ||
        lower.contains('partial')) {
      return const Color(0xFFD97706);
    }
    return _accentSuccess;
  }

  @override
  Widget build(BuildContext context) {
    final access = widget.officials.access;
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
            'CALL & ALERT HISTORY',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 0.8,
            ),
          ),
          actions: [
            IconButton(
              onPressed: loading || historyLoading ? null : _reload,
              tooltip: 'Refresh history',
              icon: const Icon(Icons.refresh, size: 28),
            ),
          ],
        ),
        body: widget.officials.loading || loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 4))
            : !access.canViewHistory
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'History access unavailable.',
                        style: TextStyle(
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
                      _eventFilterCard(),
                      if (error != null) _errorBanner(error!),
                      if (historyLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: LinearProgressIndicator(minHeight: 6),
                        ),
                      const SizedBox(height: 12),
                      if (history.isEmpty && !historyLoading)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _bgCard,
                            border: Border.all(color: _borderStrong, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'No notification records loaded for this event.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _inkSecondary,
                            ),
                          ),
                        ),
                      ...history.map(_historyBatchCard),
                      if (hasMore) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: historyLoading
                                ? null
                                : () => _loadHistory(older: true),
                            icon: const Icon(Icons.expand_more, size: 24),
                            label: const Text(
                              'LOAD OLDER CALLS',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _bgCard,
                              foregroundColor: _inkPrimary,
                              side: const BorderSide(
                                color: _borderStrong,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }

  Widget _errorBanner(String msg) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: _accentPrimary, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: _accentPrimary,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              msg,
              style: const TextStyle(
                color: Color(0xFF7F1D1D),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventFilterCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border.all(color: _borderStrong, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'FILTER BY EVENT',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _inkSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Text(
                '${history.length} LOADED',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: _inkPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<int>(
            key: ValueKey(eventId),
            initialValue: eventId,
            isExpanded: true,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _inkPrimary,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _borderStrong, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _accentPrimary, width: 2.5),
              ),
            ),
            items: events
                .map(
                  (e) => DropdownMenuItem<int>(
                    value: e['event_id'] as int,
                    child: Text(
                      '${e['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
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
        ],
      ),
    );
  }

  Widget _historyBatchCard(Map<String, dynamic> batch) {
    final delivery =
        batch['delivery'] is Map ? batch['delivery'] as Map : <String, dynamic>{};
    final messages = _maps(batch['messages']);
    final outcome = '${batch['outcome'] ?? 'unknown'}'.toUpperCase();
    final classNames = _maps(batch['classes']).map((c) => c['name']).join(', ');
    final officialName = batch['official'] is Map
        ? (batch['official']['display_name'] ?? 'Official')
        : 'Official';
    final primaryBody =
        messages.isNotEmpty ? '${messages.first['body'] ?? ''}' : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border.all(color: _borderStrong, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: _inkPrimary,
          collapsedIconColor: _inkPrimary,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _outcomeColor(outcome),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      outcome,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${batch['created_at'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _inkSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                classNames.isEmpty ? 'Entire Event' : classNames,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _inkPrimary,
                ),
              ),
              if (primaryBody.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  primaryBody,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _inkPrimary,
                  ),
                ),
              ],
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Sent by $officialName · Accepted: ${delivery['accepted'] ?? 0} · Failed: ${delivery['failed'] ?? 0}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _inkSecondary,
              ),
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                border: Border.all(color: _borderStrong, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DELIVERY BREAKDOWN: Accepted ${delivery['accepted'] ?? 0} · '
                    'Failed ${delivery['failed'] ?? 0} · '
                    'Skipped ${delivery['skipped'] ?? 0} · '
                    'In Progress ${delivery['in_progress'] ?? 0}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: _inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Note: FCM accepted means queued to Apple/Google push servers.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ...messages.map(
              (m) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF9C3),
                  border: Border.all(color: _inkPrimary, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${m['title'] ?? ''} · ${'${m['status'] ?? ''}'.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: _accentPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${m['body'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _inkPrimary,
                      ),
                    ),
                    if ('${m['round_label'] ?? ''}'.isNotEmpty ||
                        '${m['message_type'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${m['round_label'] ?? ''} · ${m['message_type'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _inkSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
