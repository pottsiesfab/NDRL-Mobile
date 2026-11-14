import 'dart:async';

import 'package:flutter/material.dart';

import '../services/members_service.dart';

const _background = Color(0xFF111111);
const _surface = Color(0xFF242428);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);

class NdrlMemberProfileScreen extends StatefulWidget {
  const NdrlMemberProfileScreen({
    super.key,
    required this.memberId,
    required this.seasonId,
  });

  final int memberId;
  final int seasonId;

  @override
  State<NdrlMemberProfileScreen> createState() =>
      _NdrlMemberProfileScreenState();
}

class _NdrlMemberProfileScreenState extends State<NdrlMemberProfileScreen> {
  final _service = NdrlMembersService();
  Map<String, dynamic>? _member;
  String? _error;
  Map<String, dynamic>? _stats;
  String? _statsError;
  bool _statsLoading = false;
  bool _loading = true;
  int? _selectedSeasonId;
  int? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _selectedSeasonId = widget.seasonId;
    unawaited(_load());
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
      final payload = await _service.profile(
        memberId: widget.memberId,
        seasonId: widget.seasonId,
      );
      if (!mounted) return;
      final member = Map<String, dynamic>.from(payload['member'] as Map);
      setState(() => _member = member);
      if (member['membership_type'] == 'driver') {
        await _loadStats();
      } else {
        setState(() {
          _stats = null;
          _statsError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load this member profile.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() {
      _statsLoading = true;
      _statsError = null;
    });
    try {
      final stats = await _service.driverStats(memberId: widget.memberId);
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      if (mounted) {
        setState(
          () => _statsError = 'Driver statistics are temporarily unavailable.',
        );
      }
    } finally {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  String _string(dynamic value) => value?.toString() ?? '';
  int? _asInt(dynamic value) => value is int ? value : int.tryParse('$value');

  @override
  Widget build(BuildContext context) {
    final member = _member;
    final name = member == null
        ? 'Member Profile'
        : '${_string(member['first_name'])} ${_string(member['last_name'])}'
              .trim();
    final city = _string(member?['city']);
    final state = _string(member?['state']);
    final location = [city, state].where((s) => s.isNotEmpty).join(', ');
    final cars = member?['cars'] is List
        ? member!['cars'] as List
        : <dynamic>[];
    final seasons = _stats?['seasons'] is List
        ? (_stats!['seasons'] as List).whereType<Map>().toList()
        : <Map>[];
    final selectedSeasons = seasons
        .where(
          (s) =>
              _selectedSeasonId == null ||
              _asInt(s['season_id']) == _selectedSeasonId,
        )
        .toList();
    final classOptions = <int, String>{};
    for (final season in selectedSeasons) {
      final entries = season['classes'];
      if (entries is List) {
        for (final entry in entries.whereType<Map>()) {
          final id = _asInt(entry['class_id']);
          if (id != null) {
            classOptions[id] = '${entry['class_name'] ?? 'Class $id'}';
          }
        }
      }
    }
    final activeClass = classOptions.containsKey(_selectedClassId)
        ? _selectedClassId
        : null;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(backgroundColor: _background, title: Text(name)),
      body: RefreshIndicator(
        color: _red,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(color: _red),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
            if (member != null) ...[
              Card(
                color: _surface,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      NdrlMemberAvatar(
                        url: _string(member['avatar_person_url']),
                        radius: 38,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (location.isNotEmpty)
                              Text(
                                location,
                                style: const TextStyle(color: Colors.white70),
                              ),
                            const SizedBox(height: 5),
                            Text(
                              _string(member['membership_type']) == 'associate'
                                  ? 'ASSOCIATE MEMBER'
                                  : 'NDRL DRIVER',
                              style: const TextStyle(
                                color: _gold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (member['membership_type'] == 'driver') ...[
                const SizedBox(height: 20),
                const Text(
                  'DRIVER STATISTICS',
                  style: TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                if (_statsLoading) const LinearProgressIndicator(color: _red),
                if (_statsError != null) ...[
                  Text(
                    _statsError!,
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                  TextButton.icon(
                    onPressed: _loadStats,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry statistics'),
                  ),
                ],
                if (seasons.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    key: ValueKey('profile-season-$_selectedSeasonId'),
                    initialValue: _selectedSeasonId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Season',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All seasons'),
                      ),
                      for (final season in seasons)
                        DropdownMenuItem<int?>(
                          value: _asInt(season['season_id']),
                          child: Text(
                            '${season['season_name'] ?? 'Season'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedSeasonId = value;
                      _selectedClassId = null;
                    }),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    key: ValueKey(
                      'profile-class-$_selectedSeasonId-$activeClass',
                    ),
                    initialValue: activeClass,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Racing class',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All classes'),
                      ),
                      for (final entry in classOptions.entries)
                        DropdownMenuItem<int?>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _selectedClassId = value),
                  ),
                ],
                if (_stats?['career'] is Map) ...[
                  _CareerCard(
                    career: Map<String, dynamic>.from(_stats!['career'] as Map),
                  ),
                ],
                for (final season in selectedSeasons)
                  if (season['classes'] is List &&
                      (season['classes'] as List).whereType<Map>().any(
                        (entry) =>
                            activeClass == null ||
                            _asInt(entry['class_id']) == activeClass,
                      ))
                    _SeasonCard(
                      key: ValueKey(
                        'season-${season['season_id']}-$activeClass',
                      ),
                      season: Map<String, dynamic>.from(season),
                      classId: activeClass,
                      initiallyExpanded: true,
                    ),
              ],
              if (cars.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'RACING ENTRIES',
                  style: TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                for (final entry in cars)
                  if (entry is Map)
                    Card(
                      color: _surface,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            NdrlMemberAvatar(
                              url: _string(entry['avatar_car_url']),
                              radius: 32,
                              fallback: Icons.directions_car_outlined,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _string(entry['class_name']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_string(entry['car_desc']).isNotEmpty)
                                    Text(
                                      _string(entry['car_desc']),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '#${_string(entry['car_number'])}',
                              style: const TextStyle(
                                color: _gold,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _CareerCard extends StatelessWidget {
  const _CareerCard({required this.career});
  final Map<String, dynamic> career;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CAREER PERFORMANCE · ALL SEASONS / CLASSES',
              style: TextStyle(color: _gold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            _StatGrid(
              items: [
                ('SEASONS', career['seasons_participated']),
                ('CLASS ENTRIES', career['season_class_entries']),
                ('CLASS-EVENTS', career['career_events_entered']),
                ('POINTS', career['career_points']),
                ('RACE WINS', career['career_race_wins']),
                ('ROUNDS WON', career['career_rounds_won']),
                ('QUAL AVG', career['career_qual_avg']),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Class-events count entries in each class, not unique race weekends.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.items});
  final List<(String, dynamic)> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          SizedBox(
            width: (MediaQuery.sizeOf(context).width - 80) / 3,
            child: Column(
              children: [
                Text(
                  item.$2 == null ? '—' : '${item.$2}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.$1,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SeasonCard extends StatelessWidget {
  const _SeasonCard({
    super.key,
    required this.season,
    required this.initiallyExpanded,
    required this.classId,
  });
  final Map<String, dynamic> season;
  final bool initiallyExpanded;
  final int? classId;

  @override
  Widget build(BuildContext context) {
    final classes = season['classes'];
    return Card(
      color: _surface,
      margin: const EdgeInsets.only(top: 10),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        title: Text(
          '${season['season_name'] ?? 'Season'}',
          style: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
        ),
        children: [
          if (classes is List)
            for (final raw in classes)
              if (raw is Map &&
                  (classId == null ||
                      int.tryParse('${raw['class_id']}') == classId))
                _ClassCard(data: Map<String, dynamic>.from(raw)),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final events = data['events'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1E),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${data['class_name'] ?? ''}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  Text(
                    '${data['points'] ?? 0} PTS',
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Championship rank #${data['rank'] ?? '—'}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              _StatGrid(
                items: [
                  ('EVENTS', data['event_count']),
                  ('AVG PTS', data['pts_avg']),
                  ('QUAL AVG', data['qual_avg']),
                  ('RACE WINS', data['race_wins']),
                  ('ROUNDS', data['rounds_won']),
                  ('COUNTED PTS', data['pts_included']),
                ],
              ),
              if (events is List && events.isNotEmpty) ...[
                const SizedBox(height: 14),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    'EVENT RESULTS (${events.length})',
                    style: const TextStyle(
                      color: _gold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  children: [
                    for (final raw in events)
                      if (raw is Map)
                        _EventRow(data: Map<String, dynamic>.from(raw)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final date = '${data['event_date'] ?? ''}';
    final qualified = data['qualified'] == 1 || data['qualified'] == true;
    final position = data['qual_pos'];
    final qual = !qualified
        ? 'Not qualified'
        : position == null
        ? 'Qualified'
        : 'Qual #$position';
    final included = data['included'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['event_name'] ?? 'Event'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '$date · $qual · ${data['rounds_won'] ?? 0} rounds won',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                if (!included)
                  const Text(
                    'Dropped / not counted',
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${data['event_pts'] ?? 0} pts',
            style: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class NdrlMemberAvatar extends StatelessWidget {
  const NdrlMemberAvatar({
    super.key,
    required this.url,
    this.radius = 26,
    this.fallback = Icons.person_outline,
  });

  final String url;
  final double radius;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url);
    final valid =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.hasAuthority;
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF38383E),
      child: ClipOval(
        child: valid
            ? Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    Icon(fallback, color: _gold, size: radius),
              )
            : Icon(fallback, color: _gold, size: radius),
      ),
    );
  }
}
