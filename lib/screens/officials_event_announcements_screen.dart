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
  // High-contrast daylight palette matching Staging Lane Control
  static const Color _bgPage = Color(0xFFE2E8F0);
  static const Color _bgCard = Color(0xFFFFFFFF);
  static const Color _inkPrimary = Color(0xFF0F172A);
  static const Color _inkSecondary = Color(0xFF334155);
  static const Color _borderStrong = Color(0xFF0F172A);
  static const Color _borderMuted = Color(0xFF94A3B8);
  static const Color _accentPrimary = Color(0xFFB91C1C);
  static const Color _accentSelected = Color(0xFF0F172A);
  static const Color _accentGold = Color(0xFFFACC15);
  static const Color _accentSuccess = Color(0xFF15803D);

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

  bool get _isLocked => loading || pendingKey != null;
  bool get _canSelected => widget.officials.access.canCallLanes;
  bool get _canEntire =>
      widget.officials.access.canAnnounceEvent &&
      widget.officials.access.allClasses;

  List<String> get _selectedClassNames {
    return classes
        .where((c) => selectedClasses.contains(c['class_id']))
        .map((c) => '${c['name']}'.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

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
        classIds: audience == 'entire_event'
            ? []
            : (selectedClasses.toList()..sort()),
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

  Future<void> _stageAndVerifyRecipients() async {
    if (!_valid || _isLocked) return;
    setState(() {
      loading = true;
      error = null;
      preview = null;
      submission = null;
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

  Future<void> _broadcastNow() async {
    final draft = pendingDraft;
    if (draft == null || preview == null || loading) return;

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
      child: Theme(
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
              'EVENT ANNOUNCEMENTS',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 0.8,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh authorized targets',
                onPressed: _isLocked ? null : _reload,
                icon: const Icon(Icons.refresh, size: 28),
              ),
            ],
          ),
          body: widget.officials.loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 4))
              : !access.enabled || (!_canSelected && !_canEntire)
                  ? _statusMessage('Announcement permission unavailable.')
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                      children: [
                        if (loading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: LinearProgressIndicator(minHeight: 6),
                          ),
                        _eventHeaderCard(access),
                        if (error != null) _errorBanner(error!),
                        if (pendingKey != null)
                          _errorBanner(
                            'Submission outcome uncertain. Controls locked to preserve retry ID. Check history or tap RETRY BROADCAST NOW.',
                          ),
                        const SizedBox(height: 12),
                        _step1AudienceCard(),
                        const SizedBox(height: 12),
                        _step2MessageCard(),
                        const SizedBox(height: 12),
                        _step3LivePreviewAndSendCard(),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _statusMessage(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _inkPrimary,
          ),
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

  Widget _eventHeaderCard(dynamic access) {
    final targetSummary = audience == 'entire_event'
        ? 'ENTIRE EVENT'
        : '${selectedClasses.length} CLASS${selectedClasses.length == 1 ? '' : 'ES'}';
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _accentGold,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _inkPrimary, width: 1.5),
                ),
                child: Text(
                  'ROLE: ${access.roles.join(', ').toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _inkPrimary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                targetSummary,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: (audience == 'selected_classes' &&
                          selectedClasses.isEmpty)
                      ? _inkSecondary
                      : _accentPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'ACTIVE EVENT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _inkSecondary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
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
            onChanged: _isLocked
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _accentPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _step1AudienceCard() {
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
              const Expanded(
                child: Text(
                  '1. SELECT AUDIENCE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _inkPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (audience == 'selected_classes' && selectedClasses.isNotEmpty)
                OutlinedButton(
                  onPressed: _isLocked
                      ? null
                      : () {
                          setState(() => selectedClasses.clear());
                          _draftChanged();
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _inkPrimary,
                    side: const BorderSide(color: _inkPrimary, width: 1.5),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text(
                    'CLEAR ALL',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (_canSelected)
                _bigChoiceButton(
                  label: 'SELECTED CLASSES',
                  selected: audience == 'selected_classes',
                  activeColor: _accentSelected,
                  onTap: () {
                    setState(() => audience = 'selected_classes');
                    _draftChanged();
                  },
                ),
              if (_canSelected && _canEntire) const SizedBox(width: 8),
              if (_canEntire)
                _bigChoiceButton(
                  label: 'ENTIRE EVENT',
                  selected: audience == 'entire_event',
                  activeColor: _accentPrimary,
                  onTap: () {
                    setState(() => audience = 'entire_event');
                    _draftChanged();
                  },
                ),
            ],
          ),
          if (audience == 'entire_event') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                border: Border.all(color: _accentPrimary, width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.groups, color: _accentPrimary, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Broadcasts to ALL subscribers following this event (all classes + event followers).',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _inkPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (audience == 'selected_classes') ...[
            const SizedBox(height: 12),
            if (classes.isEmpty)
              const Text(
                'No authorized classes available.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: classes.map((c) {
                      final id = c['class_id'] as int;
                      final name = '${c['name']}';
                      final isSelected = selectedClasses.contains(id);
                      return SizedBox(
                        width: itemWidth,
                        height: 60,
                        child: Material(
                          color: isSelected ? _accentSelected : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: _isLocked
                                ? null
                                : () {
                                    setState(() {
                                      if (isSelected) {
                                        selectedClasses.remove(id);
                                      } else {
                                        selectedClasses.add(id);
                                      }
                                    });
                                    _draftChanged();
                                  },
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color:
                                      isSelected ? _accentGold : _borderStrong,
                                  width: isSelected ? 3 : 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    color:
                                        isSelected ? _accentGold : _inkPrimary,
                                    size: 26,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: isSelected
                                            ? Colors.white
                                            : _inkPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _step2MessageCard() {
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
          const Text(
            '2. WRITE ANNOUNCEMENT',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _inkPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'HEADLINE / TITLE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: _inkSecondary,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: titleController,
            maxLength: 200,
            readOnly: _isLocked,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _inkPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'e.g., Weather Delay or Drivers Meeting',
              hintStyle: const TextStyle(
                color: _borderMuted,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _borderStrong, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _accentPrimary, width: 2.5),
              ),
            ),
            onChanged: (_) => _draftChanged(),
          ),
          const SizedBox(height: 8),
          const Text(
            'MESSAGE BODY',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: _inkSecondary,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: bodyController,
            maxLength: 2000,
            maxLines: 5,
            minLines: 3,
            readOnly: _isLocked,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _inkPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Enter clear details for racers, crews, and fans...',
              hintStyle: const TextStyle(
                color: _borderMuted,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _borderStrong, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _accentPrimary, width: 2.5),
              ),
            ),
            onChanged: (_) => _draftChanged(),
          ),
        ],
      ),
    );
  }

  Widget _step3LivePreviewAndSendCard() {
    final canStage = !_isLocked && _valid;
    final previewTitle = titleController.text.trim().isEmpty
        ? '[Enter Headline Above]'
        : titleController.text.trim();
    final previewBody = bodyController.text.trim().isEmpty
        ? '[Enter Announcement Message Above]'
        : bodyController.text.trim();
    final audienceTag = audience == 'entire_event'
        ? 'AUDIENCE: ENTIRE EVENT'
        : _selectedClassNames.isEmpty
            ? 'AUDIENCE: [SELECT CLASSES]'
            : 'CLASSES: ${_selectedClassNames.join(', ')}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgCard,
        border: Border.all(color: _borderStrong, width: 2.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '3. LIVE MESSAGE PREVIEW',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _inkPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF9C3),
              border: Border.all(color: _inkPrimary, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  audienceTag.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _accentPrimary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  previewTitle,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: _inkPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  previewBody,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                    color: _inkPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (preview == null)
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: canStage ? _stageAndVerifyRecipients : null,
                icon: const Icon(Icons.fact_check, size: 26),
                label: Text(
                  !_valid
                      ? 'COMPLETE AUDIENCE, TITLE & MESSAGE'
                      : 'VERIFY RECIPIENTS & STAGE ALERT',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _inkPrimary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _borderMuted,
                  disabledForegroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          if (preview != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                border: Border.all(color: _accentSuccess, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'READY TO BROADCAST',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _accentSuccess,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Audience: ${audience == 'entire_event' ? 'Entire event' : _maps(preview!['classes']).map((c) => c['name']).join(', ')}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _inkPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Push-ready devices: ${preview!['recipients']?['unique_push_ready_devices'] ?? '?'} '
                    '(${preview!['recipients']?['unique_matching_devices'] ?? '?'} subscribed)',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _inkSecondary,
                    ),
                  ),
                  ...((preview!['warnings'] is List)
                      ? (preview!['warnings'] as List).map(
                          (w) => Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'WARNING: $w',
                              style: const TextStyle(
                                color: _accentPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : <Widget>[]),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: ElevatedButton.icon(
                onPressed: loading ? null : _broadcastNow,
                icon: const Icon(Icons.campaign, size: 30),
                label: Text(
                  pendingKey != null
                      ? 'RETRY BROADCAST NOW'
                      : 'SEND ANNOUNCEMENT NOW',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
          if (submission != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                border: Border.all(color: _accentSuccess, width: 2.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: _accentSuccess,
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ANNOUNCEMENT QUEUED! Message IDs: ${submission!['message_ids']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _inkPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bigChoiceButton({
    required String label,
    required bool selected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: _isLocked ? null : onTap,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            elevation: 0,
            backgroundColor: selected ? activeColor : Colors.white,
            foregroundColor: selected ? Colors.white : _inkPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: selected ? _inkPrimary : _borderStrong,
                width: selected ? 2.5 : 1.5,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
