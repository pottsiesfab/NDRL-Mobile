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
  // High-contrast daylight palette
  static const Color _bgPage = Color(0xFFE2E8F0);
  static const Color _bgCard = Color(0xFFFFFFFF);
  static const Color _inkPrimary = Color(0xFF0F172A);
  static const Color _inkSecondary = Color(0xFF334155);
  static const Color _borderStrong = Color(0xFF0F172A);
  static const Color _borderMuted = Color(0xFF94A3B8);
  static const Color _accentPrimary = Color(
    0xFFB91C1C,
  ); // High-contrast NDRL Red
  static const Color _accentSelected = Color(0xFF0F172A);
  static const Color _accentGold = Color(0xFFFACC15);
  static const Color _accentSuccess = Color(0xFF15803D);

  late final OfficialNotificationsService api = OfficialNotificationsService(
    widget.officials.auth,
  );

  final TextEditingController _customMessageController =
      TextEditingController();
  bool _useCustomMessage = false;

  String roundType = 'Qualifying';
  int roundNumber = 1;
  String stagingInstruction = 'staging';
  String callType = 'first';

  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> classes = [];
  final Set<int> selected = {};
  int? eventId;

  bool loading = false;
  String? error;
  Map<String, dynamic>? preview;
  Map<String, dynamic>? submission;
  LaneCallDraft? pendingDraft;
  String? pendingKey;

  bool get _isLocked => loading || pendingKey != null;

  bool get _usesRoundNumber =>
      roundType == 'TT' ||
      roundType == 'Qualifying' ||
      roundType == 'Eliminations';

  String get _roundLabel =>
      _usesRoundNumber ? '$roundType Round $roundNumber' : roundType;

  String get _callTypeLabel {
    switch (callType) {
      case 'second':
        return 'Second Call';
      case 'final':
        return 'Final Call';
      case 'first':
      default:
        return 'First Call';
    }
  }

  String get _instructionPhrase {
    return stagingInstruction == 'deck'
        ? 'Report on deck'
        : 'Report to staging lanes';
  }

  List<String> get _selectedClassNames {
    return classes
        .where((c) => selected.contains(c['class_id']))
        .map((c) => '${c['name']}'.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  String get _formattedLiveMessage {
    if (_useCustomMessage && _customMessageController.text.trim().isNotEmpty) {
      return _customMessageController.text.trim();
    }
    final classPart = _selectedClassNames.isEmpty
        ? '[Select Class]'
        : _selectedClassNames.join(', ');
    return '$classPart - $_callTypeLabel - $_instructionPhrase for $_roundLabel';
  }

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
    _customMessageController.dispose();
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
      setState(() {
        events = filteredEvents;
        classes = nextClasses;
        if (!events.any((e) => e['event_id'] == eventId)) {
          eventId = events.isEmpty ? null : events.first['event_id'] as int?;
        }
        selected.removeWhere((id) => !classes.any((c) => c['class_id'] == id));
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
    roundLabel: _roundLabel,
    message: _formattedLiveMessage,
  );

  Future<void> _stageAndVerifyRecipients() async {
    if (eventId == null || selected.isEmpty || _isLocked) return;
    setState(() {
      loading = true;
      error = null;
      preview = null;
      submission = null;
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

  Future<void> _broadcastNow() async {
    final draft = pendingDraft;
    if (draft == null || preview == null || loading) return;

    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.officials.refresh();
      if (!widget.officials.access.canCallLanes) {
        throw StateError('Access revoked');
      }
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
              'Send uncertain or rejected: $e. Do not change selections; '
              'tap RETRY SEND to reuse the same submission ID safely.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
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
            'STAGING LANE CONTROL',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 0.8,
            ),
          ),
          actions: [
            IconButton(
              onPressed: _isLocked ? null : _reload,
              tooltip: 'Refresh classes & events',
              icon: const Icon(Icons.refresh, size: 28),
            ),
          ],
        ),
        body: widget.officials.loading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 4))
            : !access.enabled
            ? _statusMessage(
                widget.officials.error ?? 'Official access unavailable.',
              )
            : !access.canCallLanes
            ? _statusMessage('Lane-call permission unavailable.')
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
                  const SizedBox(height: 12),
                  _step1ClassesCard(),
                  const SizedBox(height: 12),
                  _step2CallDetailsCard(),
                  const SizedBox(height: 12),
                  _step3LivePreviewAndSendCard(),
                ],
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
                '${selected.length} CLASS${selected.length == 1 ? '' : 'ES'} SELECTED',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: selected.isEmpty ? _inkSecondary : _accentPrimary,
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
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
        ],
      ),
    );
  }

  Widget _step1ClassesCard() {
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
                  '1. TAP CLASSES TO CALL',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _inkPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              if (selected.isNotEmpty)
                OutlinedButton(
                  onPressed: _isLocked
                      ? null
                      : () {
                          setState(() => selected.clear());
                          _draftChanged();
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _inkPrimary,
                    side: const BorderSide(color: _inkPrimary, width: 1.5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'CLEAR ALL',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (classes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No authorized classes available.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
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
                    final isSelected = selected.contains(id);
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
                                      selected.remove(id);
                                    } else {
                                      selected.add(id);
                                    }
                                  });
                                  _draftChanged();
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? _accentGold : _borderStrong,
                                width: isSelected ? 3 : 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_box
                                      : Icons.check_box_outline_blank,
                                  color: isSelected ? _accentGold : _inkPrimary,
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
      ),
    );
  }

  Widget _step2CallDetailsCard() {
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
            '2. CALL LEVEL & ACTION',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _inkPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _bigChoiceButton(
                label: 'FIRST CALL',
                selected: callType == 'first',
                activeColor: _accentSuccess,
                onTap: () {
                  setState(() => callType = 'first');
                  _draftChanged();
                },
              ),
              const SizedBox(width: 8),
              _bigChoiceButton(
                label: 'SECOND CALL',
                selected: callType == 'second',
                activeColor: const Color(0xFFD97706),
                onTap: () {
                  setState(() => callType = 'second');
                  _draftChanged();
                },
              ),
              const SizedBox(width: 8),
              _bigChoiceButton(
                label: 'FINAL CALL',
                selected: callType == 'final',
                activeColor: _accentPrimary,
                onTap: () {
                  setState(() => callType = 'final');
                  _draftChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _bigChoiceButton(
                label: 'REPORT TO STAGING',
                selected: stagingInstruction == 'staging',
                activeColor: _accentSelected,
                onTap: () {
                  setState(() => stagingInstruction = 'staging');
                  _draftChanged();
                },
              ),
              const SizedBox(width: 8),
              _bigChoiceButton(
                label: 'ON DECK',
                selected: stagingInstruction == 'deck',
                activeColor: _accentSelected,
                onTap: () {
                  setState(() => stagingInstruction = 'deck');
                  _draftChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'ROUND / SESSION',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: _inkSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const {
                'TT': 'Time Trial',
                'Qualifying': 'Qualifying',
                'Eliminations': 'Eliminations',
                'Semi Final': 'Semi Final',
                'Final': 'Final',
              }.entries)
                _pillButton(
                  label: entry.value,
                  selected: roundType == entry.key,
                  onTap: () {
                    setState(() => roundType = entry.key);
                    _draftChanged();
                  },
                ),
            ],
          ),
          if (_usesRoundNumber) ...[
            const SizedBox(height: 14),
            const Text(
              'ROUND NUMBER',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: _inkSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(8, (index) {
                final num = index + 1;
                final isSelected = roundNumber == num;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index == 7 ? 0 : 6),
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLocked
                            ? null
                            : () {
                                setState(() => roundNumber = num);
                                _draftChanged();
                              },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          elevation: 0,
                          backgroundColor: isSelected
                              ? _accentSelected
                              : Colors.white,
                          foregroundColor: isSelected
                              ? Colors.white
                              : _inkPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? _accentGold : _borderStrong,
                              width: isSelected ? 2.5 : 1.5,
                            ),
                          ),
                        ),
                        child: Text(
                          '$num',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _step3LivePreviewAndSendCard() {
    final canStage = !_isLocked && eventId != null && selected.isNotEmpty;

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
          Row(
            children: [
              const Expanded(
                child: Text(
                  '3. LIVE MESSAGE PREVIEW',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _inkPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _isLocked
                    ? null
                    : () {
                        setState(() {
                          _useCustomMessage = !_useCustomMessage;
                          if (_useCustomMessage &&
                              _customMessageController.text.trim().isEmpty) {
                            _customMessageController.text =
                                _formattedLiveMessage;
                          }
                        });
                        _draftChanged();
                      },
                icon: Icon(
                  _useCustomMessage ? Icons.auto_fix_high : Icons.edit,
                  size: 18,
                  color: _inkPrimary,
                ),
                label: Text(
                  _useCustomMessage ? 'USE AUTO TEXT' : 'EDIT TEXT',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _inkPrimary,
                  ),
                ),
              ),
            ],
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
                  'NDRL — $_callTypeLabel'.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _accentPrimary,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formattedLiveMessage,
                  style: const TextStyle(
                    fontSize: 19,
                    height: 1.3,
                    fontWeight: FontWeight.w900,
                    color: _inkPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (_useCustomMessage) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _customMessageController,
              maxLines: 3,
              readOnly: _isLocked,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _inkPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Custom Message Override',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _borderStrong, width: 2),
                ),
              ),
              onChanged: (_) => _draftChanged(),
            ),
          ],
          const SizedBox(height: 14),
          if (preview == null)
            SizedBox(
              height: 60,
              child: ElevatedButton.icon(
                onPressed: canStage ? _stageAndVerifyRecipients : null,
                icon: const Icon(Icons.fact_check, size: 26),
                label: Text(
                  selected.isEmpty
                      ? 'SELECT AT LEAST 1 CLASS ABOVE'
                      : 'VERIFY RECIPIENTS & STAGE CALL',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
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
                    'Classes: ${_maps(preview!['classes']).map((c) => c['name']).join(', ')}',
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
                  pendingKey != null ? 'RETRY BROADCAST NOW' : 'SEND CALL NOW',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
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
                      'CALL SENT! Queued ${submission!['delivery_records'] ?? 0} device deliveries.',
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
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        onPressed: _isLocked ? null : onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          elevation: 0,
          backgroundColor: selected ? _accentSelected : Colors.white,
          foregroundColor: selected ? Colors.white : _inkPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: selected ? _accentGold : _borderStrong,
              width: selected ? 2.5 : 1.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
