import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/fantasy_service.dart';
import '../../widgets/sponsor_ad_widget.dart';

const _bg = Color(0xFF080A12);
const _panel = Color(0xFF101525);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFC52A35);

int _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
String _money(int cents) => '\$${(cents / 100).toStringAsFixed(0)}';
Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> _list(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

class NdrlFantasyRosterScreen extends StatefulWidget {
  const NdrlFantasyRosterScreen({
    super.key,
    required this.authService,
    required this.season,
    this.initialEventId,
  });
  final AuthService authService;
  final FantasySeason season;
  final int? initialEventId;

  @override
  State<NdrlFantasyRosterScreen> createState() => _RosterState();
}

class _RosterState extends State<NdrlFantasyRosterScreen> {
  final _service = NdrlFantasyService();
  List<Map<String, dynamic>> _events = [];
  Map<String, dynamic> _options = {};
  final Map<int, Map<String, dynamic>> _selected = {};
  int? _eventId;
  int? _captainId;
  bool _loading = true;
  bool _busy = false;
  bool _dirty = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  bool get _editable => _map(_options['editing'])['can_edit'] == true;
  int get _budget => _int(_options['budget_cents']);
  int get _total =>
      _selected.values.fold(0, (sum, d) => sum + _int(d['price_cents']));
  List<Map<String, dynamic>> get _drivers => _list(_options['drivers']);
  List<Map<String, dynamic>> get _classes => _list(_options['classes']);
  int get _minimum => _int(_options['min_picks']);

  Future<void> _load() async {
    if (!widget.authService.signedIn) {
      setState(() {
        _loading = false;
        _error = 'Sign in to your NDRL account first.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });
    try {
      final rosters = await _service.myRosters(
        authService: widget.authService,
        fantasySeasonId: widget.season.id,
      );
      if (rosters['has_team'] != true) {
        throw const AuthException('No Fantasy team exists for this season.');
      }
      final events = fantasyRosterEvents(rosters['rosters']);
      // Only the newest season event may be edited. Never fall back to an
      // older open event when the newest is locked.
      final chosen = events.isEmpty ? null : fantasyEventId(events.first);
      if (widget.initialEventId != null && chosen != widget.initialEventId) {
        throw const AuthException(
          'The current Fantasy event has changed. Refresh My Rosters.',
        );
      }
      Map<String, dynamic> options = {};
      if (chosen != null) {
        options = await _service.rosterOptions(
          authService: widget.authService,
          fantasySeasonId: widget.season.id,
          fantasyEventId: chosen,
        );
      }
      final selected = <int, Map<String, dynamic>>{};
      int? captain;
      final roster = _map(options['roster']);
      // The API may return roster picks directly or nested in roster.picks.
      final saved = _list(roster['picks']);
      final byId = {
        for (final d in _list(options['drivers']))
          _int(d['member_season_class_id']): d,
      };
      for (final pick in saved) {
        final id = _int(pick['member_season_class_id']);
        final driver = byId[id];
        if (driver == null) continue;
        selected[_int(driver['class_id'])] = driver;
        if (pick['is_captain'] == true || _int(pick['is_captain']) == 1) {
          captain = id;
        }
      }
      if (!mounted) return;
      setState(() {
        _events = events;
        _eventId = chosen;
        _options = options;
        _selected
          ..clear()
          ..addAll(selected);
        _captainId = captain;
        _dirty = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<bool> _confirmDiscard() async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text('Your unsaved driver selections will be lost.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ) ??
      false;

  List<Map<String, dynamic>> _picks() {
    return _selected.values
        .map(
          (d) => <String, dynamic>{
            'member_season_class_id': _int(d['member_season_class_id']),
            'class_id': _int(d['class_id']),
            'is_captain': _int(d['member_season_class_id']) == _captainId,
          },
        )
        .toList();
  }

  Future<void> _submit({required bool save}) async {
    final id = _eventId;
    if (id == null || _busy) return;
    if (_selected.length != _classes.length || _selected.length < _minimum) {
      _show('Choose one driver from each class.');
      return;
    }
    if (_captainId == null ||
        !_selected.values.any(
          (d) => _int(d['member_season_class_id']) == _captainId,
        )) {
      _show('Select a captain.');
      return;
    }
    if (_total > _budget) {
      _show('Roster exceeds the budget cap.');
      return;
    }
    if (save) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Save Fantasy roster?'),
          content: Text(
            'Save ${_selected.length} drivers for ${_money(_total)}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await _service.rosterWrite(
        authService: widget.authService,
        fantasySeasonId: widget.season.id,
        fantasyEventId: id,
        picks: _picks(),
        save: save,
      );
      if (!mounted) return;
      _show(
        save
            ? 'Roster saved successfully.'
            : 'Roster valid: ${_money(_int(result['total_cost_cents']))} / ${_money(_int(result['budget_cents']))}',
      );
      if (save) {
        await _load();
        if (mounted) _show('Roster saved successfully.');
      }
    } catch (e) {
      if (mounted) _show('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    setState(() => _message = message);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final event = _events
        .where((e) => _int(e['fantasy_event_id']) == _eventId)
        .firstOrNull;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !_dirty) return;
        if (await _confirmDiscard() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          foregroundColor: Colors.white,
          title: const Text('ROSTER PICKER'),
          actions: [
            IconButton(
              onPressed: _loading || _busy
                  ? null
                  : () async {
                      if (!_dirty || await _confirmDiscard()) await _load();
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _red))
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                      ),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.season.name,
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const NdrlSponsorAdWidget(
                    placement: 'fantasy_banner',
                    heading: 'FANTASY LEAGUE SPONSORS',
                  ),
                  const SizedBox(height: 16),
                  if (_events.isEmpty)
                    const Text(
                      'No Fantasy events available.',
                      style: TextStyle(color: Colors.white70),
                    )
                  else
                    Card(
                      color: _panel,
                      child: ListTile(
                        title: Text(
                          '${event?['event_name'] ?? 'Current event'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text(
                          'Newest Fantasy event',
                          style: TextStyle(color: Colors.white60),
                        ),
                        leading: const Icon(Icons.flag_outlined, color: _gold),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    _editable
                        ? 'ROSTER OPEN FOR EDITING'
                        : 'ROSTER LOCKED — VIEW ONLY',
                    style: TextStyle(
                      color: _editable ? Colors.greenAccent : _gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (event != null && event['lock_date'] != null)
                    Text(
                      'Lock: ${event['lock_date']} (Eastern)',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  const SizedBox(height: 14),
                  Card(
                    color: _panel,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selected.length} / ${_classes.length} drivers selected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_money(_total)} / ${_money(_budget)}',
                            style: TextStyle(
                              color: _total > _budget
                                  ? Colors.redAccent
                                  : _gold,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_money(_budget - _total)} remaining',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: _budget == 0
                                ? 0
                                : (_total / _budget).clamp(0.0, 1.0),
                            color: _total > _budget ? Colors.redAccent : _gold,
                            backgroundColor: Colors.white12,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._classes.map((c) {
                    final classId = _int(c['class_id']);
                    final options =
                        _drivers
                            .where((d) => _int(d['class_id']) == classId)
                            .toList()
                          ..sort((a, b) {
                            final byPrice = _int(b['price_cents'])
                                .compareTo(_int(a['price_cents']));
                            if (byPrice != 0) return byPrice;
                            final nameA =
                                '${_map(a['driver'])['display_name'] ?? ''}';
                            final nameB =
                                '${_map(b['driver'])['display_name'] ?? ''}';
                            return nameA.compareTo(nameB);
                          });
                    final chosen = _selected[classId];
                    final chosenId = chosen == null
                        ? null
                        : _int(chosen['member_season_class_id']);
                    return Card(
                      color: _panel,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${c['class_name'] ?? 'Class $classId'}',
                              style: const TextStyle(
                                color: _gold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            DropdownButtonFormField<int>(
                              key: ValueKey('$classId-$chosenId-$_eventId'),
                              initialValue: chosenId,
                              isExpanded: true,
                              dropdownColor: _panel,
                              style: const TextStyle(color: Colors.white),
                              decoration: const InputDecoration(
                                hintText: 'Choose driver',
                                hintStyle: TextStyle(color: Colors.white54),
                              ),
                              items: [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text('No driver selected'),
                                ),
                                ...options.map(
                                  (d) => DropdownMenuItem<int>(
                                    value: _int(d['member_season_class_id']),
                                    child: Text(
                                      '${_map(d['driver'])['display_name'] ?? _map(d['driver'])['name'] ?? 'Driver #${d['member_season_class_id']}'} — ${_money(_int(d['price_cents']))}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: !_editable || _busy
                                  ? null
                                  : (id) => setState(() {
                                      if (id == null) {
                                        _selected.remove(classId);
                                      } else {
                                        _selected[classId] = options.firstWhere(
                                          (d) =>
                                              _int(
                                                d['member_season_class_id'],
                                              ) ==
                                              id,
                                        );
                                      }
                                      if (_captainId == chosenId &&
                                          id != chosenId) {
                                        _captainId = null;
                                      }
                                      _dirty = true;
                                    }),
                            ),
                            if (chosen != null)
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                value: chosenId == _captainId,
                                activeColor: _red,
                                title: const Text(
                                  'Team captain',
                                  style: TextStyle(color: Colors.white),
                                ),
                                subtitle: const Text(
                                  'One captain per roster',
                                  style: TextStyle(color: Colors.white60),
                                ),
                                onChanged: !_editable || _busy
                                    ? null
                                    : (checked) => setState(() {
                                        _captainId = checked == true
                                            ? chosenId
                                            : null;
                                        _dirty = true;
                                      }),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _message!,
                        style: const TextStyle(color: _gold),
                      ),
                    ),
                  if (_editable)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _submit(save: false),
                            child: const Text('Validate'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _red,
                            ),
                            onPressed: _busy ? null : () => _submit(save: true),
                            child: Text(_busy ? 'Working…' : 'Save roster'),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                ],
              ),
      ),
    );
  }
}
