import 'package:flutter/material.dart';

import '../../services/fantasy_service.dart';
import '../../widgets/sponsor_ad_widget.dart';

const _bg = Color(0xFF080A12);
const _panel = Color(0xFF101525);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFC52A35);

int _number(dynamic value) => int.tryParse('$value') ?? 0;
String _string(dynamic value) => '${value ?? ''}';
Map<String, dynamic> _object(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> _objects(dynamic value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : <Map<String, dynamic>>[];

class NdrlFantasyStandingsScreen extends StatefulWidget {
  const NdrlFantasyStandingsScreen({
    super.key,
    required this.season,
    this.showEventsInitially = false,
  });

  final FantasySeason season;
  final bool showEventsInitially;

  @override
  State<NdrlFantasyStandingsScreen> createState() => _StandingsState();
}

class _StandingsState extends State<NdrlFantasyStandingsScreen> {
  final _service = NdrlFantasyService();
  final _search = TextEditingController();
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _eventData;
  int? _selectedEventId;
  bool _loading = true;
  bool _loadingEvent = false;
  String? _error;
  String? _eventError;
  late bool _showEvents;

  @override
  void initState() {
    super.initState();
    _showEvents = widget.showEventsInitially;
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _service.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _teams => _objects(_data?['standings']);

  List<Map<String, dynamic>> get _events {
    final byId = <int, Map<String, dynamic>>{};
    for (final team in _teams) {
      for (final event in _objects(team['events'])) {
        final id = _number(event['fantasy_event_id']);
        if (id > 0) byId[id] = event;
      }
    }
    final items = byId.values.toList();
    items.sort((a, b) {
      final da = _string(a['event_date']);
      final db = _string(b['event_date']);
      final byDate = db.compareTo(da);
      return byDate != 0
          ? byDate
          : _number(b['fantasy_event_id'])
                .compareTo(_number(a['fantasy_event_id']));
    });
    return items;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.seasonStandings(widget.season.id);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
      final events = _events;
      if (events.isNotEmpty) {
        final valid = events.any(
          (e) => _number(e['fantasy_event_id']) == _selectedEventId,
        );
        await _loadEvent(
          valid ? _selectedEventId! : _number(events.first['fantasy_event_id']),
        );
      } else {
        setState(() {
          _selectedEventId = null;
          _eventData = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _loadEvent(int id) async {
    setState(() {
      _selectedEventId = id;
      _eventData = null;
      _eventError = null;
      _loadingEvent = true;
    });
    try {
      final result = await _service.eventStandings(id);
      if (!mounted || _selectedEventId != id) return;
      if (_number(_object(result['event'])['fantasy_season_id']) !=
          widget.season.id) {
        throw StateError('Event does not belong to this Fantasy season.');
      }
      setState(() {
        _eventData = result;
        _loadingEvent = false;
      });
    } catch (e) {
      if (!mounted || _selectedEventId != id) return;
      setState(() {
        _eventError = '$e';
        _loadingEvent = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(
      backgroundColor: _bg,
      foregroundColor: Colors.white,
      title: const Text(
        'FANTASY STANDINGS',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
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
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${widget.season.year} — ${widget.season.name}',
            style: const TextStyle(
              color: _gold,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Season'),
                icon: Icon(Icons.emoji_events_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text('Events'),
                icon: Icon(Icons.event_outlined),
              ),
            ],
            selected: {_showEvents},
            onSelectionChanged: (value) =>
                setState(() => _showEvents = value.first),
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : _gold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            const LinearProgressIndicator(color: _red)
          else if (_error != null)
            _message('Unable to load standings: $_error')
          else if (_showEvents)
            _eventSection()
          else
            _seasonSection(),
          const SizedBox(height: 22),
          const NdrlSponsorAdWidget(
            placement: 'fantasy_banner',
            heading: 'FANTASY LEAGUE SPONSORS',
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );

  Widget _message(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Text(message, style: const TextStyle(color: Colors.white70)),
  );

  Widget _seasonSection() {
    final season = _object(_data?['season']);
    final filter = _search.text.trim().toLowerCase();
    final rows = _teams
        .where(
          (row) =>
              filter.isEmpty ||
              _string(row['team_name']).toLowerCase().contains(filter) ||
              _string(row['owner_name']).toLowerCase().contains(filter),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_number(season['events_scored'])} scored / ${_number(season['events_total'])} events  •  ${_teams.length} teams',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _search,
          style: const TextStyle(color: Colors.white),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search team or owner',
            hintStyle: const TextStyle(color: Colors.white54),
            prefixIcon: const Icon(Icons.search, color: _gold),
            filled: true,
            fillColor: _panel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          _message('No teams found.')
        else
          ...rows.map((row) => _teamCard(row, event: false)),
      ],
    );
  }

  Widget _eventSection() {
    final events = _events;
    if (events.isEmpty) {
      return _message('No scored event standings are available yet.');
    }
    final event = _object(_eventData?['event']);
    final teams = _objects(_eventData?['teams']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SCORED EVENTS',
          style: TextStyle(color: _gold, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          key: ValueKey(_selectedEventId),
          initialValue: _selectedEventId,
          isExpanded: true,
          dropdownColor: _panel,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: _panel,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: events
              .map(
                (e) => DropdownMenuItem<int>(
                  value: _number(e['fantasy_event_id']),
                  child: Text(
                    _string(e['display_name']),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id != null) _loadEvent(id);
          },
        ),
        const SizedBox(height: 14),
        if (_loadingEvent)
          const LinearProgressIndicator(color: _red)
        else if (_eventError != null)
          _message('Unable to load event: $_eventError')
        else if (_eventData == null)
          _message('Select an event to see standings.')
        else ...[
          Text(
            _string(event['display_name']),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${teams.length} scored rosters',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          if (teams.isEmpty)
            _message('No scored rosters for this event.')
          else
            ...teams.map((row) => _teamCard(row, event: true)),
        ],
      ],
    );
  }

  Widget _teamCard(Map<String, dynamic> team, {required bool event}) {
    final rank = _number(event ? team['rank_in_event'] : team['rank']);
    final name = _string(team['team_name']);
    final owner = _string(team['owner_name']);
    final points = _number(team['total_points']);
    final rosterId = _number(team['fantasy_roster_id']);
    return Card(
      color: _panel,
      margin: const EdgeInsets.only(bottom: 9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: const BorderSide(color: Colors.white12),
      ),
      child: InkWell(
        onTap: event && rosterId > 0 && _selectedEventId != null
            ? () => _openScore(team, rosterId, _selectedEventId!)
            : !event
            ? () => _showTeamEvents(team)
            : null,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Text(
                  rank > 0 ? '#$rank' : '—',
                  style: const TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (owner.isNotEmpty)
                      Text(
                        owner,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    if (!event)
                      Text(
                        '${_number(team['events_scored'])} scored events',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$points',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const Text(
                    'PTS',
                    style: TextStyle(color: _gold, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  void _showTeamEvents(Map<String, dynamic> team) {
    final events = _objects(team['events']);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _panel,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _string(team['team_name']),
                style: const TextStyle(
                  color: _gold,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _string(team['owner_name']),
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              if (events.isEmpty)
                const Text(
                  'No scored events yet.',
                  style: TextStyle(color: Colors.white70),
                ),
              ...events.map(
                (e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _string(e['display_name']),
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Event rank: ${e['rank_in_event'] ?? '—'}',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  trailing: Text(
                    '${_number(e['total_points'])} pts',
                    style: const TextStyle(color: _gold),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    final roster = _number(e['fantasy_roster_id']);
                    final id = _number(e['fantasy_event_id']);
                    if (roster > 0 && id > 0) _openScore(team, roster, id);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openScore(
    Map<String, dynamic> team,
    int rosterId,
    int eventId,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: _red)),
    );
    try {
      final data = await _service.rosterScoreDetails(rosterId, eventId);
      if (!mounted) return;
      Navigator.of(context).pop();
      final picks = _objects(data['picks']);
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: _panel,
        isScrollControlled: true,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _string(team['team_name']),
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_number(data['total_points'])} points  •  Event rank #${data['rank_in_event'] ?? '—'}',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                if (picks.isEmpty)
                  const Text(
                    'Individual driver scoring details are not available for this roster.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ...picks.map(
                  (pick) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _string(
                        pick['driver_name'] ??
                            pick['display_name'] ??
                            pick['name'] ??
                            'Driver',
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      _string(
                        pick['class_name'] ??
                            (pick['is_captain'] == true ? 'Captain' : ''),
                      ),
                      style: const TextStyle(color: Colors.white60),
                    ),
                    trailing: Text(
                      _string(pick['total_points'] ?? pick['points'] ?? ''),
                      style: const TextStyle(color: _gold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load roster score: $e')),
      );
    }
  }
}
