import 'package:flutter/material.dart';

import '../services/official_access_service.dart';
import '../services/official_notifications_service.dart';

class NdrlOfficialsEventAnnouncementsScreen extends StatefulWidget {
  const NdrlOfficialsEventAnnouncementsScreen({
    super.key,
    required this.officials,
  });

  final OfficialAccessService officials;

  @override
  State<NdrlOfficialsEventAnnouncementsScreen> createState() =>
      _EventAnnouncementsState();
}

class _EventAnnouncementsState
    extends State<NdrlOfficialsEventAnnouncementsScreen>
    with WidgetsBindingObserver {
  late final OfficialNotificationsService api = OfficialNotificationsService(
    widget.officials.auth,
  );
  final titleController = TextEditingController();
  final bodyController = TextEditingController();
  final Set<int> selectedClasses = {};
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> classes = [];
  int? eventId;
  String audience = 'selected_classes';
  bool loading = false;
  String? error;
  Map<String, dynamic>? preview;
  Map<String, dynamic>? submission;
  AnnouncementDraft? pendingDraft;
  String? pendingKey;

  bool get _canSelected => widget.officials.access.canCallLanes;
  bool get _canEntire =>
      widget.officials.access.canAnnounceEvent &&
      widget.officials.access.allClasses;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.officials.addListener(_accessChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.officials.removeListener(_accessChanged);
    titleController.dispose();
    bodyController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && pendingKey == null) {
      _reload();
    }
  }

  void _accessChanged() {
    if (!mounted) return;
    if (widget.officials.loading) {
      setState(() {});
      return;
    }
    if (!_canSelected && !_canEntire) {
      setState(() {
        events = [];
        classes = [];
        selectedClasses.clear();
        preview = null;
        pendingDraft = null;
        pendingKey = null;
      });
    } else {
      setState(() {});
    }
  }

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : [];

  Future<void> _reload() async {
    if (loading || pendingKey != null) return;
    setState(() {
      loading = true;
      error = null;
      preview = null;
      pendingDraft = null;
    });
    try {
      await widget.officials.refresh();
      if (!mounted || (!_canSelected && !_canEntire)) return;
      final data = await api.targets(seasonId: widget.officials.seasonId);
      if (!mounted || (!_canSelected && !_canEntire)) return;
      final access = widget.officials.access;
      final availableEvents = _maps(data['events'])
          .where((e) => e['event_id'] == 14)
          .where(
            (e) =>
                access.eventIds.isEmpty ||
                access.eventIds.contains(e['event_id']),
          )
          .toList();
      final availableClasses = _maps(data['classes']);
      setState(() {
        events = availableEvents;
        classes = availableClasses;
        if (!events.any((e) => e['event_id'] == eventId)) {
          eventId = events.isEmpty ? null : events.first['event_id'] as int?;
        }
        selectedClasses.removeWhere(
          (id) => !classes.any((c) => c['class_id'] == id),
        );
        if (!_canEntire) audience = 'selected_classes';
        if (!_canSelected && _canEntire) audience = 'entire_event';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          events = [];
          classes = [];
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _draftChanged() {
    if (pendingKey != null) return;
    setState(() {
      preview = null;
      pendingDraft = null;
      submission = null;
    });
  }

  AnnouncementDraft _draft() => AnnouncementDraft(
    eventId: eventId!,
    audience: audience,
    classIds: audience == 'entire_event' ? [] : selectedClasses.toList(),
    title: titleController.text.trim(),
    body: bodyController.text.trim(),
  );

  bool get _valid =>
      eventId != null &&
      (audience == 'entire_event'
          ? _canEntire
          : (_canSelected && selectedClasses.isNotEmpty)) &&
      titleController.text.trim().isNotEmpty &&
      titleController.text.trim().runes.length <= 200 &&
      bodyController.text.trim().isNotEmpty &&
      bodyController.text.trim().runes.length <= 2000;

  Future<void> _preview() async {
    if (!_valid || loading || pendingKey != null) return;
    setState(() {
      loading = true;
      error = null;
      preview = null;
    });
    try {
      final draft = _draft();
      await widget.officials.refresh();
      if (!mounted ||
          (draft.audience == 'entire_event' ? !_canEntire : !_canSelected)) {
        throw StateError('Announcement permission unavailable');
      }
      final result = await api.previewAnnouncement(draft);
      if (!mounted) return;
      setState(() {
        preview = result;
        pendingDraft = draft;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _send() async {
    final draft = pendingDraft;
    if (draft == null || preview == null || loading) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm announcement'),
        content: SingleChildScrollView(
          child: Text(
            '${preview!['title']}\n\n${preview!['body']}\n\n'
            'Audience: ${draft.audience == 'entire_event' ? 'Entire event' : 'Selected classes'}\n'
            'Push-ready devices: ${preview!['recipients']?['unique_push_ready_devices'] ?? '?'}\n\n'
            'This will queue a real DEV notification.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm & Send'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.officials.refresh();
      if (!mounted ||
          (draft.audience == 'entire_event' ? !_canEntire : !_canSelected)) {
        throw StateError('Announcement permission unavailable');
      }
      pendingKey ??= OfficialNotificationsService.newSubmissionKey();
      final result = await api.sendAnnouncement(
        draft,
        idempotencyKey: pendingKey!,
      );
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
              'Send failed or result uncertain: $e. Check Notification History '
              'before retrying. A retry here will reuse the same submission ID.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = widget.officials.access;
    return PopScope(
      canPop: pendingKey == null,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Event Announcements'),
          actions: [
            IconButton(
              tooltip: 'Refresh authorized targets',
              onPressed: loading || pendingKey != null ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: widget.officials.loading
            ? const Center(child: CircularProgressIndicator())
            : !access.enabled || (!_canSelected && !_canEntire)
            ? const Center(child: Text('Announcement permission unavailable.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Roles: ${access.roles.join(', ')}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (loading) const LinearProgressIndicator(),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: SelectableText(
                        error!,
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  if (pendingKey != null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Submission outcome uncertain. This screen is locked '
                        'to preserve the retry ID. Check history, then retry.',
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
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
                            child: Text(
                              '${e['name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: loading || pendingKey != null
                        ? null
                        : (value) {
                            setState(() => eventId = value);
                            _draftChanged();
                          },
                  ),
                  if (events.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'No eligible DEV announcement event (event 14).',
                      ),
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: audience,
                    key: ValueKey(audience),
                    decoration: const InputDecoration(labelText: 'Audience'),
                    items: [
                      if (_canSelected)
                        const DropdownMenuItem(
                          value: 'selected_classes',
                          child: Text('Selected classes'),
                        ),
                      if (_canEntire)
                        const DropdownMenuItem(
                          value: 'entire_event',
                          child: Text('Entire event'),
                        ),
                    ],
                    onChanged: loading || pendingKey != null
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => audience = value);
                            _draftChanged();
                          },
                  ),
                  if (audience == 'selected_classes') ...[
                    const SizedBox(height: 12),
                    Text(
                      'Recipient classes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (classes.isEmpty)
                      const Text('No authorized classes available.'),
                    ...classes.map(
                      (c) => CheckboxListTile(
                        dense: true,
                        title: Text('${c['name']}'),
                        value: selectedClasses.contains(c['class_id']),
                        onChanged: loading || pendingKey != null
                            ? null
                            : (checked) {
                                setState(() {
                                  final id = c['class_id'] as int;
                                  if (checked == true) {
                                    selectedClasses.add(id);
                                  } else {
                                    selectedClasses.remove(id);
                                  }
                                });
                                _draftChanged();
                              },
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    maxLength: 200,
                    readOnly: loading || pendingKey != null,
                    decoration: const InputDecoration(
                      labelText: 'Notification title',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _draftChanged(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: bodyController,
                    maxLength: 2000,
                    maxLines: 5,
                    minLines: 3,
                    readOnly: loading || pendingKey != null,
                    decoration: const InputDecoration(
                      labelText: 'Announcement message',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => _draftChanged(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: loading || pendingKey != null || !_valid
                        ? null
                        : _preview,
                    icon: const Icon(Icons.visibility),
                    label: const Text('Preview announcement'),
                  ),
                  if (preview != null) ...[
                    const Divider(height: 32),
                    Text(
                      'Server preview',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${preview!['title']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('${preview!['body']}'),
                    const SizedBox(height: 12),
                    Text(
                      'Audience: ${audience == 'entire_event' ? 'Entire event' : 'Selected classes'}',
                    ),
                    if (audience == 'selected_classes')
                      Text(
                        'Classes: ${_maps(preview!['classes']).map((c) => c['name']).join(', ')}',
                      ),
                    Text(
                      'Matching devices: ${preview!['recipients']?['unique_matching_devices'] ?? '?'}',
                    ),
                    Text(
                      'Push-ready devices: ${preview!['recipients']?['unique_push_ready_devices'] ?? '?'}',
                    ),
                    ...((preview!['warnings'] is List)
                        ? (preview!['warnings'] as List).map(
                            (w) => Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '$w',
                                style: const TextStyle(color: Colors.orange),
                              ),
                            ),
                          )
                        : <Widget>[]),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: loading ? null : _send,
                      icon: const Icon(Icons.send),
                      label: Text(
                        pendingKey == null
                            ? 'Review & Confirm Send'
                            : 'Retry same submission',
                      ),
                    ),
                  ],
                  if (submission != null) ...[
                    const Divider(height: 32),
                    const Text(
                      'Announcement queued by API. Delivery is asynchronous.',
                    ),
                    SelectableText(
                      'Message IDs: ${submission!['message_ids']}',
                    ),
                    Text(
                      'Already submitted: ${submission!['already_submitted'] == true ? 'Yes' : 'No'}',
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
