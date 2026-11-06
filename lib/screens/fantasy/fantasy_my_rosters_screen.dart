import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/fantasy_service.dart';
import '../../widgets/sponsor_ad_widget.dart';
import 'fantasy_roster_screen.dart';

const _bg = Color(0xFF080A12);
const _panel = Color(0xFF101525);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFC52A35);

int _number(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _list(dynamic v) => v is List
    ? v.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList()
    : <Map<String, dynamic>>[];
String _money(dynamic cents) =>
    '\$${(_number(cents) / 100).toStringAsFixed(0)}';

class NdrlFantasyMyRostersScreen extends StatefulWidget {
  const NdrlFantasyMyRostersScreen({
    super.key,
    required this.authService,
    required this.season,
  });

  final AuthService authService;
  final FantasySeason season;

  @override
  State<NdrlFantasyMyRostersScreen> createState() => _MyRostersState();
}

class _MyRostersState extends State<NdrlFantasyMyRostersScreen> {
  final _service = NdrlFantasyService();
  List<Map<String, dynamic>> _events = [];
  final Map<int, Map<String, dynamic>> _details = {};
  final Set<int> _loadingDetails = {};
  final Map<int, String> _detailErrors = {};
  bool _loading = true;
  String? _error;
  bool _newestEditable = false;

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!widget.authService.signedIn) {
        throw const AuthException('Sign in to view your Fantasy rosters.');
      }
      final response = await _service.myRosters(
        authService: widget.authService,
        fantasySeasonId: widget.season.id,
      );
      if (response['has_team'] != true) {
        throw const AuthException('No Fantasy team exists for this season.');
      }
      final events = fantasyRosterEvents(response['rosters']);
      var editable = false;
      if (events.isNotEmpty) {
        try {
          final options = await _service.rosterOptions(
            authService: widget.authService,
            fantasySeasonId: widget.season.id,
            fantasyEventId: fantasyEventId(events.first),
          );
          editable = _map(options['editing'])['can_edit'] == true;
          _details[fantasyEventId(events.first)] = options;
        } catch (_) {
          // History remains visible even if editing/options is unavailable.
          editable = false;
        }
      }
      if (!mounted) return;
      setState(() {
        _events = events;
        _newestEditable = editable;
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

  Future<void> _loadDetails(int eventId) async {
    if (_details.containsKey(eventId) || _loadingDetails.contains(eventId))
      return;
    setState(() => _loadingDetails.add(eventId));
    try {
      final data = await _service.rosterOptions(
        authService: widget.authService,
        fantasySeasonId: widget.season.id,
        fantasyEventId: eventId,
      );
      if (!mounted) return;
      setState(() => _details[eventId] = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _detailErrors[eventId] = '$e');
    } finally {
      if (mounted) setState(() => _loadingDetails.remove(eventId));
    }
  }

  Future<void> _editNewest(int eventId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NdrlFantasyRosterScreen(
          authService: widget.authService,
          season: widget.season,
          initialEventId: eventId,
        ),
      ),
    );
    if (!mounted) return;
    _details.clear();
    await _load();
  }

  Widget _savedPicks(Map<String, dynamic> event, int id) {
    final options = _details[id];
    if (options == null) {
      if (_loadingDetails.contains(id)) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(color: _red)),
        );
      }
      if (_detailErrors.containsKey(id)) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                _detailErrors[id]!,
                style: const TextStyle(color: Colors.white70),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _detailErrors.remove(id));
                  _loadDetails(id);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }
    final roster = _map(options['roster']);
    var picks = _list(roster['picks']);
    if (picks.isEmpty) picks = _list(event['picks']);
    if (picks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'No saved drivers for this event.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    final drivers = {
      for (final d in _list(options['drivers']))
        _number(d['member_season_class_id']): d,
    };
    final classes = {
      for (final c in _list(options['classes']))
        _number(c['class_id']): '${c['class_name'] ?? 'Class'}',
    };
    return Column(
      children: [
        for (final pick in picks)
          Builder(
            builder: (context) {
              final driver = drivers[_number(pick['member_season_class_id'])];
              final detail = _map(driver?['driver']);
              final captain =
                  pick['is_captain'] == true ||
                  _number(pick['is_captain']) == 1;
              final classId = _number(pick['class_id'] ?? driver?['class_id']);
              final name =
                  pick['display_name'] ??
                  pick['driver_name'] ??
                  detail['display_name'] ??
                  detail['name'] ??
                  'Driver #${pick['member_season_class_id']}';
              final price = pick['price_cents'] ?? driver?['price_cents'];
              return ListTile(
                dense: true,
                title: Text(
                  '$name${captain ? '  ★ CAPTAIN' : ''}',
                  style: TextStyle(color: captain ? _gold : Colors.white),
                ),
                subtitle: Text(
                  classes[classId] ??
                      '${pick['class_name'] ?? 'Class $classId'}',
                  style: const TextStyle(color: Colors.white60),
                ),
                trailing: price == null
                    ? null
                    : Text(_money(price), style: const TextStyle(color: _gold)),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        title: const Text('MY ROSTERS'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.season.name,
              style: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const NdrlSponsorAdWidget(
              placement: 'fantasy_banner',
              heading: 'FANTASY LEAGUE SPONSORS',
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator(color: _red))
            else if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.white70)),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ] else if (_events.isEmpty)
              const Text(
                'No Fantasy events in this season.',
                style: TextStyle(color: Colors.white70),
              )
            else
              for (var index = 0; index < _events.length; index++)
                Card(
                  color: _panel,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    iconColor: _gold,
                    collapsedIconColor: _gold,
                    onExpansionChanged: (expanded) {
                      if (expanded)
                        _loadDetails(fantasyEventId(_events[index]));
                    },
                    title: Text(
                      '${_events[index]['event_name'] ?? 'Fantasy Event'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      index == 0 && _newestEditable
                          ? 'CURRENT EVENT · Open for editing'
                          : 'READ ONLY · ${_events[index]['event_date'] ?? _events[index]['lock_date'] ?? 'Saved roster'}',
                      style: TextStyle(
                        color: index == 0 && _newestEditable
                            ? Colors.greenAccent
                            : Colors.white60,
                      ),
                    ),
                    children: [
                      _savedPicks(
                        _events[index],
                        fantasyEventId(_events[index]),
                      ),
                      if (index == 0 && _newestEditable)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: _red,
                              ),
                              onPressed: () =>
                                  _editNewest(fantasyEventId(_events[index])),
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit current roster'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
