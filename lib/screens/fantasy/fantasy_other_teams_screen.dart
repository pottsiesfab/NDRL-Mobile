import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/fantasy_service.dart';
import '../../widgets/sponsor_ad_widget.dart';

const _bg = Color(0xFF080A12);
const _panel = Color(0xFF101525);
const _gold = Color(0xFFD1AC67);

class NdrlFantasyOtherTeamsScreen extends StatefulWidget {
  const NdrlFantasyOtherTeamsScreen({
    super.key,
    required this.authService,
    required this.season,
  });
  final AuthService authService;
  final FantasySeason season;
  @override
  State<NdrlFantasyOtherTeamsScreen> createState() => _OtherTeamsState();
}

class _OtherTeamsState extends State<NdrlFantasyOtherTeamsScreen> {
  final _service = NdrlFantasyService();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _teams = [];
  bool _loading = false;
  String? _error;
  int _total = 0;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _request++;
    _search.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    final request = ++_request;
    final offset = more ? _teams.length : 0;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.otherTeams(
        authService: widget.authService,
        fantasySeasonId: widget.season.id,
        query: _search.text.trim(),
        offset: offset,
      );
      if (!mounted || request != _request) return;
      final items = (data['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _teams = more ? [..._teams, ...items] : items;
        _total = int.tryParse('${data['total']}') ?? 0;
      });
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e.toString());
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _bg,
    appBar: AppBar(
      title: const Text('OTHER TEAMS'),
      backgroundColor: _bg,
      foregroundColor: Colors.white,
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const NdrlSponsorAdWidget(
            placement: 'fantasy_banner',
            heading: 'FANTASY LEAGUE SPONSORS',
          ),
          const SizedBox(height: 20),
          Text(
            widget.season.name,
            style: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search team or owner',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: _gold),
              filled: true,
              fillColor: _panel,
              suffixIcon: IconButton(
                onPressed: () {
                  _search.clear();
                  _load();
                },
                icon: const Icon(Icons.clear, color: Colors.white54),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _load(),
          ),
          const SizedBox(height: 12),
          Text('$_total teams', style: const TextStyle(color: Colors.white70)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            TextButton(onPressed: () => _load(), child: const Text('Retry')),
          ],
          for (final team in _teams)
            Card(
              color: _panel,
              child: ListTile(
                leading: const Icon(Icons.groups_outlined, color: _gold),
                title: Text(
                  '${team['name'] ?? 'Team'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  '${team['owner_display_name'] ?? ''}',
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white54,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _OtherTeamProfile(
                      authService: widget.authService,
                      season: widget.season,
                      teamId: int.tryParse('${team['fantasy_team_id']}') ?? 0,
                    ),
                  ),
                ),
              ),
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: _gold)),
            ),
          if (!_loading && _teams.isEmpty && _error == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No teams found.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          if (!_loading && _teams.length < _total)
            Center(
              child: TextButton(
                onPressed: () => _load(more: true),
                child: const Text('Load more teams'),
              ),
            ),
        ],
      ),
    ),
  );
}

class _OtherTeamProfile extends StatefulWidget {
  const _OtherTeamProfile({
    required this.authService,
    required this.season,
    required this.teamId,
  });
  final AuthService authService;
  final FantasySeason season;
  final int teamId;
  @override
  State<_OtherTeamProfile> createState() => _OtherTeamProfileState();
}

class _OtherTeamProfileState extends State<_OtherTeamProfile> {
  final _service = NdrlFantasyService();
  Map<String, dynamic>? _data;
  String? _error;
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
    try {
      final data = await _service.otherTeamProfile(
        authService: widget.authService,
        fantasySeasonId: widget.season.id,
        fantasyTeamId: widget.teamId,
      );
      if (mounted)
        setState(() {
          _data = data;
          _error = null;
        });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final team = _data?['team'] as Map?;
    final events = _data?['events'] as List? ?? [];
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('TEAM PROFILE'),
        backgroundColor: _bg,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_data == null && _error == null)
              const Center(child: CircularProgressIndicator(color: _gold)),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
            if (team != null) ...[
              Text(
                '${team['name'] ?? ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Owner: ${team['owner_display_name'] ?? ''}',
                style: const TextStyle(color: _gold),
              ),
              const SizedBox(height: 24),
              const Text(
                'EVENT HISTORY',
                style: TextStyle(color: _gold, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final raw in events)
                Builder(
                  builder: (context) {
                    final event = Map<String, dynamic>.from(raw as Map);
                    final public = event['has_public_roster'] == true;
                    return Card(
                      color: _panel,
                      child: ListTile(
                        title: Text(
                          '${event['event_name'] ?? 'Event'}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          public
                              ? 'Scored — view roster'
                              : event['is_scored'] == true
                              ? 'No roster submitted'
                              : 'Selections private until scored',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: Icon(
                          public ? Icons.chevron_right : Icons.lock_outline,
                          color: public ? _gold : Colors.white38,
                        ),
                        onTap: !public
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => _OtherTeamRoster(
                                    authService: widget.authService,
                                    season: widget.season,
                                    teamId: widget.teamId,
                                    eventId:
                                        int.tryParse(
                                          '${event['fantasy_event_id']}',
                                        ) ??
                                        0,
                                  ),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              if (events.isEmpty)
                const Text(
                  'No events for this season.',
                  style: TextStyle(color: Colors.white70),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _OtherTeamRoster extends StatefulWidget {
  const _OtherTeamRoster({
    required this.authService,
    required this.season,
    required this.teamId,
    required this.eventId,
  });
  final AuthService authService;
  final FantasySeason season;
  final int teamId;
  final int eventId;
  @override
  State<_OtherTeamRoster> createState() => _OtherTeamRosterState();
}

class _OtherTeamRosterState extends State<_OtherTeamRoster> {
  final _service = NdrlFantasyService();
  Map<String, dynamic>? _data;
  String? _error;
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
    try {
      final data = await _service.otherTeamRoster(
        authService: widget.authService,
        fantasySeasonId: widget.season.id,
        fantasyTeamId: widget.teamId,
        fantasyEventId: widget.eventId,
      );
      if (mounted)
        setState(() {
          _data = data;
          _error = null;
        });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final picks = _data?['picks'] as List? ?? [];
    final team = _data?['team'] as Map?;
    final event = _data?['event'] as Map?;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('PUBLIC ROSTER'),
        backgroundColor: _bg,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_data == null && _error == null)
              const Center(child: CircularProgressIndicator(color: _gold)),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
            if (_data != null) ...[
              Text(
                '${team?['name'] ?? ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${event?['event_name'] ?? ''}',
                style: const TextStyle(color: _gold),
              ),
              const SizedBox(height: 10),
              Text(
                'Roster cost: \$${((int.tryParse('${_data!['total_cost_cents']}') ?? 0) / 100).toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              for (final raw in picks)
                Builder(
                  builder: (context) {
                    final p = Map<String, dynamic>.from(raw as Map);
                    final captain = p['is_captain'] == true;
                    return Card(
                      color: _panel,
                      child: ListTile(
                        leading: Icon(
                          captain
                              ? Icons.star
                              : Icons.sports_motorsports_outlined,
                          color: _gold,
                        ),
                        title: Text(
                          '${p['driver_name'] ?? ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${p['class_name'] ?? ''}${captain ? ' • CAPTAIN' : ''}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  },
                ),
              if (picks.isEmpty)
                const Text(
                  'No driver selections.',
                  style: TextStyle(color: Colors.white70),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
