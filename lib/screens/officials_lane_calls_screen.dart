import 'package:flutter/material.dart';

import '../services/official_access_service.dart';
import '../services/official_notifications_service.dart';

class NdrlOfficialsLaneCallsScreen extends StatefulWidget {
  const NdrlOfficialsLaneCallsScreen({super.key, required this.officials});
  final OfficialAccessService officials;

  @override
  State<NdrlOfficialsLaneCallsScreen> createState() => _LaneCallsState();
}

class _LaneCallsState extends State<NdrlOfficialsLaneCallsScreen>
    with WidgetsBindingObserver {
  late final OfficialNotificationsService api = OfficialNotificationsService(
    widget.officials.auth,
  );
  final round = TextEditingController(text: 'Qualifying 1');
  final message = TextEditingController(text: 'Please report to staging.');
  String roundType = 'Qualifying';
  int roundNumber = 1;
  String stagingInstruction = 'staging';

  bool get _usesRoundNumber =>
      roundType == 'TT' ||
      roundType == 'Qualifying' ||
      roundType == 'Eliminations';

  String get _roundLabel =>
      _usesRoundNumber ? '$roundType $roundNumber' : roundType;

  String get _generatedMessage => stagingInstruction == 'staging'
      ? 'Please report to staging.'
      : 'Please be on deck.';

  void _regenerateMessage() {
    if (pendingKey != null || loading) return;
    setState(() {
      round.text = _roundLabel;
      message.text = _generatedMessage;
    });
    _draftChanged();
  }

  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> classes = [];
  final Set<int> selected = {};
  int? eventId;
  String callType = 'first';
  bool loading = false;
  String? error;
  Map<String, dynamic>? preview;
  Map<String, dynamic>? submission;
  LaneCallDraft? pendingDraft;
  String? pendingKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.officials.addListener(_permissionsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _permissionsChanged() {
    if (!mounted) return;
    if (widget.officials.loading) {
      setState(() {});
      return;
    }
    if (!widget.officials.access.enabled) {
      setState(() {
        events = [];
        classes = [];
        selected.clear();
        preview = null;
        pendingDraft = null;
        pendingKey = null;
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
    widget.officials.removeListener(_permissionsChanged);
    round.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
      preview = null;
    });
    try {
      await widget.officials.refresh();
      if (!widget.officials.access.enabled) return;
      final data = await api.targets(seasonId: widget.officials.seasonId);

      if (!mounted || !widget.officials.access.enabled) return;
      final nextEvents = _maps(data['events']);
      final nextClasses = _maps(data['classes']);
      final access = widget.officials.access;
      final filteredEvents = nextEvents
          .where(
            (e) =>
                access.eventIds.isEmpty ||
                access.eventIds.contains(e['event_id']),
          )
          .toList();
      // The backend Targets API already returns the classes
      // this official is authorized to manage.
      final filteredClasses = nextClasses;
      setState(() {
        events = filteredEvents;
        classes = filteredClasses;
        if (!events.any((e) => e['event_id'] == eventId)) {
          eventId = events.isEmpty ? null : events.first['event_id'] as int?;
        }
        selected.removeWhere((id) => !classes.any((c) => c['class_id'] == id));
      });
    } catch (e) {
      if (mounted)
        setState(() {
          error = '$e';
          events = [];
          classes = [];
        });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : [];

  void _draftChanged() {
    if (pendingKey != null) return;
    setState(() {
      preview = null;
      submission = null;
      pendingDraft = null;
      pendingKey = null;
    });
  }

  LaneCallDraft _draft() => LaneCallDraft(
    eventId: eventId!,
    classIds: selected.toList()..sort(),
    callType: callType,
    roundLabel: round.text.trim(),
    message: message.text.trim(),
  );

  Future<void> _preview() async {
    if (eventId == null || selected.isEmpty || pendingKey != null) return;
    setState(() {
      loading = true;
      error = null;
      preview = null;
    });
    try {
      await widget.officials.refresh();
      if (!widget.officials.access.canCallLanes) {
        throw StateError('Access revoked');
      }
      final draft = _draft();
      final result = await api.previewLaneCall(draft);
      if (!mounted || !widget.officials.access.canCallLanes) return;
      setState(() {
        preview = result;
        pendingDraft = draft;
        pendingKey = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    final draft = pendingDraft;
    if (draft == null || preview == null || loading) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm lane call'),
        content: Text(
          '${preview!['title']}\n\n${preview!['body']}\n\n'
          'This will queue a real DEV notification for the selected classes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm & Send'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.officials.refresh();
      if (!widget.officials.access.canCallLanes) {
        throw StateError('Access revoked');
      }
      // Retain the exact draft and UUID after uncertain network failures.
      pendingKey ??= OfficialNotificationsService.newSubmissionKey();
      final result = await api.sendLaneCall(draft, idempotencyKey: pendingKey!);
      if (!mounted) return;
      setState(() {
        submission = result;
        preview = null;
        pendingDraft = null;
        pendingKey = null;
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              'Submission result uncertain or rejected: $e. Do not change the draft; '
              'retry with the same submission ID only after checking history.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = widget.officials.access;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staging Lane Calls'),
        actions: [
          IconButton(
            onPressed: loading || pendingKey != null ? null : _reload,
            tooltip: 'Refresh access and targets',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: widget.officials.loading
          ? const Center(child: CircularProgressIndicator())
          : !access.enabled
          ? Center(
              child: Text(
                widget.officials.error ?? 'Official access unavailable.',
              ),
            )
          : !access.canCallLanes
          ? const Center(child: Text('Lane-call permission unavailable.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Roles: ${access.roles.join(', ')}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SelectableText(
                      error!,
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                if (loading) const LinearProgressIndicator(),
                const SizedBox(height: 12),
                if (access.canCallLanes) ...[
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
                    onChanged: loading || pendingKey != null
                        ? null
                        : (value) {
                            setState(() {
                              eventId = value;
                            });
                            _draftChanged();
                          },
                  ),
                  const SizedBox(height: 16),
                ],
                if (access.canCallLanes) _laneControls(),
              ],
            ),
    );
  }

  Widget _laneControls() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Staging Lane Calls',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (classes.isEmpty) const Text('No authorized classes available.'),
          ...classes.map(
            (c) => CheckboxListTile(
              dense: true,
              title: Text('${c['name']}'),
              value: selected.contains(c['class_id']),
              onChanged: loading || pendingKey != null
                  ? null
                  : (checked) {
                      setState(() {
                        if (checked == true) {
                          selected.add(c['class_id'] as int);
                        } else {
                          selected.remove(c['class_id']);
                        }
                      });
                      _draftChanged();
                    },
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: callType,
            decoration: const InputDecoration(labelText: 'Call type'),
            items: const [
              DropdownMenuItem(value: 'first', child: Text('First Call')),
              DropdownMenuItem(value: 'second', child: Text('Second Call')),
              DropdownMenuItem(value: 'final', child: Text('Final Call')),
            ],
            onChanged: loading || pendingKey != null
                ? null
                : (v) {
                    if (v != null) {
                      callType = v;
                      _draftChanged();
                    }
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: roundType,
            decoration: const InputDecoration(labelText: 'Round type'),
            items: const [
              DropdownMenuItem(value: 'TT', child: Text('TT')),
              DropdownMenuItem(value: 'Qualifying', child: Text('Qualifying')),
              DropdownMenuItem(
                value: 'Eliminations',
                child: Text('Elimination Rounds'),
              ),
              DropdownMenuItem(value: 'Semi Final', child: Text('Semi Final')),
              DropdownMenuItem(value: 'Final', child: Text('Final')),
            ],
            onChanged: loading || pendingKey != null
                ? null
                : (value) {
                    if (value == null) return;
                    roundType = value;
                    _regenerateMessage();
                  },
          ),
          if (_usesRoundNumber) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey(roundType),
              initialValue: roundNumber,
              decoration: const InputDecoration(labelText: 'Round number'),
              items: List.generate(
                8,
                (index) => DropdownMenuItem<int>(
                  value: index + 1,
                  child: Text('${index + 1}'),
                ),
              ),
              onChanged: loading || pendingKey != null
                  ? null
                  : (value) {
                      if (value == null) return;
                      roundNumber = value;
                      _regenerateMessage();
                    },
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: stagingInstruction,
            decoration: const InputDecoration(labelText: 'Lane instruction'),
            items: const [
              DropdownMenuItem(
                value: 'staging',
                child: Text('Report to Staging'),
              ),
              DropdownMenuItem(value: 'deck', child: Text('On Deck')),
            ],
            onChanged: loading || pendingKey != null
                ? null
                : (value) {
                    if (value == null) return;
                    stagingInstruction = value;
                    _regenerateMessage();
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: round,
            decoration: const InputDecoration(
              labelText: 'Round label',
              helperText: 'Generated from the round selectors',
            ),
            readOnly: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: message,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Message body (editable)',
              helperText: 'Changing a dropdown regenerates this message',
            ),
            readOnly: loading || pendingKey != null,
            onChanged: (_) => _draftChanged(),
          ),
          TextButton.icon(
            onPressed: loading || pendingKey != null
                ? null
                : _regenerateMessage,
            icon: const Icon(Icons.refresh),
            label: const Text('Regenerate message'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                loading ||
                    pendingKey != null ||
                    eventId == null ||
                    selected.isEmpty
                ? null
                : _preview,
            icon: const Icon(Icons.visibility),
            label: const Text('Preview lane call'),
          ),
          if (preview != null) ...[
            const Divider(),
            Text(
              '${preview!['title']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('${preview!['body']}'),
            const SizedBox(height: 8),
            Text(
              'Classes: ${_maps(preview!['classes']).map((c) => c['name']).join(', ')}',
            ),
            Text(
              'Unique matching devices: ${preview!['recipients']?['unique_matching_devices'] ?? '?'}',
            ),
            Text(
              'Unique push-ready devices: ${preview!['recipients']?['unique_push_ready_devices'] ?? '?'}',
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: loading ? null : _send,
              icon: const Icon(Icons.send),
              label: const Text('Review & Confirm Send'),
            ),
          ],
          if (submission != null) ...[
            const Divider(),
            const Text(
              'Submission accepted by API. Push delivery is asynchronous.',
            ),
            SelectableText('$submission'),
          ],
          if (pendingKey != null && preview != null)
            const Text(
              'Retry will reuse the same submission ID.',
              style: TextStyle(color: Colors.orange),
            ),
        ],
      ),
    ),
  );
}
