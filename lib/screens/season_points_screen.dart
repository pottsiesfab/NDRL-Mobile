import '../config/app_config.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _api = '${AppConfig.baseUrl}/api/standings_public_api.php';
const _surface = Color(0xFF242428);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);

class NdrlSeasonPointsScreen extends StatefulWidget {
  const NdrlSeasonPointsScreen({super.key});

  @override
  State<NdrlSeasonPointsScreen> createState() => _NdrlSeasonPointsScreenState();
}

class _NdrlSeasonPointsScreenState extends State<NdrlSeasonPointsScreen> {
  final http.Client _client = http.Client();
  List<Map<String, dynamic>> _seasons = [];
  List<Map<String, dynamic>> _classes = [];
  List<Map<String, dynamic>> _standings = [];
  int? _seasonId;
  int? _classId;
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _generation++;
    _client.close();
    super.dispose();
  }

  Future<Map<String, dynamic>> _get(
    String action,
    Map<String, String> params,
  ) async {
    final uri = Uri.parse(_api)
        .replace(queryParameters: {'action': action, ...params});
    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected response from standings API');
    }
    if (response.statusCode != 200 || decoded['ok'] != true) {
      throw StateError(
        'Standings request failed (HTTP ${response.statusCode}): ${decoded['message']}',
      );
    }

    final data = decoded['message'];

    if (data is! Map<String, dynamic>) {
      throw const FormatException('Unexpected standings API payload');
    }

    return data;
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> payload) {
    final raw = payload['items'];
    if (raw is! List) {
      throw const FormatException('Standings API returned no items list');
    }
    return raw.map((item) {
      if (item is! Map) throw const FormatException('Invalid standings entry');
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  int _int(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  String _str(dynamic value) => value?.toString() ?? '';

  Future<void> _initialize() async {
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final seasons = _items(await _get('season.list', {'limit': '200'}));
      if (seasons.isEmpty) {
        throw StateError('No championship seasons available');
      }
      seasons.sort(
        (a, b) => _int(b['season_id']).compareTo(_int(a['season_id'])),
      );
      final selected = seasons.any((s) => _int(s['season_id']) == _seasonId)
          ? _seasonId!
          : _int(seasons.first['season_id']);
      final classes = _items(
        await _get('class.list', {'season_id': '$selected', 'limit': '200'}),
      );
      classes.sort(
        (a, b) => _str(a['class_name']).compareTo(_str(b['class_name'])),
      );
      final selectedClass = classes.any((c) => _int(c['class_id']) == _classId)
          ? _classId
          : (classes.isEmpty ? null : _int(classes.first['class_id']));
      final standings = selectedClass == null
          ? <Map<String, dynamic>>[]
          : await _fetchStandings(selected, selectedClass);
      if (!mounted || generation != _generation) return;
      setState(() {
        _seasons = seasons;
        _seasonId = selected;
        _classes = classes;
        _classId = selectedClass;
        _standings = standings;
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = _message(e));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchStandings(
    int season,
    int racingClass,
  ) async {
    // Fetch all pages rather than silently dropping drivers after the first 100.
    final rows = <Map<String, dynamic>>[];
    for (var offset = 0; ; offset += 200) {
      final page = _items(
        await _get('standings.list', {
          'season_id': '$season',
          'class_id': '$racingClass',
          'limit': '200',
          'offset': '$offset',
        }),
      );
      rows.addAll(page);
      if (page.length < 200) break;
    }
    return rows;
  }

  Future<void> _selectSeason(int? value) async {
    if (value == null || value == _seasonId) return;
    setState(() {
      _seasonId = value;
      _classId = null;
      _classes = [];
      _standings = [];
    });
    await _initialize();
  }

  Future<void> _selectClass(int? value) async {
    if (value == null || value == _classId || _seasonId == null) return;
    final generation = ++_generation;
    setState(() {
      _classId = value;
      _standings = [];
      _loading = true;
      _error = null;
    });
    try {
      final standings = await _fetchStandings(_seasonId!, value);
      if (mounted && generation == _generation) {
        setState(() => _standings = standings);
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = _message(e));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  String _message(Object error) {
    if (error is StateError) return error.message.toString();
    return 'Unable to load standings from NDRL DEV. Check your connection and retry.';
  }

  void _openDriver(Map<String, dynamic> driver) {
    final memberId = _int(driver['member_id']);
    if (memberId <= 0) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _DriverStatsScreen(
          memberId: memberId,
          seasonId: _seasonId,
          name: _str(driver['member_display_name']),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        title: const Text('Season Points'),
        backgroundColor: const Color(0xFF111111),
      ),
      body: RefreshIndicator(
        color: _red,
        onRefresh: _initialize,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'CHAMPIONSHIP STANDINGS',
              style: TextStyle(
                color: _gold,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Official NDRL season points · DEV',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<int>(
              key: ValueKey('season-$_seasonId'),
              initialValue: _seasonId,
              decoration: const InputDecoration(
                labelText: 'Season',
                border: OutlineInputBorder(),
              ),
              items: _seasons
                  .map(
                    (s) => DropdownMenuItem<int>(
                      value: _int(s['season_id']),
                      child: Text(_str(s['season_name'])),
                    ),
                  )
                  .toList(),
              onChanged: _loading ? null : _selectSeason,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('class-$_seasonId-$_classId'),
              initialValue: _classId,
              decoration: const InputDecoration(
                labelText: 'Racing class',
                border: OutlineInputBorder(),
              ),
              items: _classes
                  .map(
                    (c) => DropdownMenuItem<int>(
                      value: _int(c['class_id']),
                      child: Text(_str(c['class_name'])),
                    ),
                  )
                  .toList(),
              onChanged: _loading ? null : _selectClass,
            ),
            if (_loading) ...[
              const SizedBox(height: 18),
              const LinearProgressIndicator(color: _red),
            ],
            if (_error != null) ...[
              const SizedBox(height: 18),
              Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
              TextButton.icon(
                onPressed: _initialize,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
            const SizedBox(height: 20),
            if (!_loading && _error == null && _standings.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text('No standings available for this selection.'),
                ),
              ),
            for (final driver in _standings)
              Card(
                color: _surface,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => _openDriver(driver),
                  leading: CircleAvatar(
                    backgroundColor: _int(driver['class_rank']) == 1
                        ? _gold
                        : const Color(0xFF38383E),
                    foregroundColor: _int(driver['class_rank']) == 1
                        ? Colors.black
                        : Colors.white,
                    child: Text(
                      '${_int(driver['class_rank'])}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    _str(driver['member_display_name']),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Car #${_str(driver['car_number'])}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${_int(driver['pts_total'])}',
                        style: const TextStyle(
                          color: _gold,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'POINTS',
                        style: TextStyle(fontSize: 10, color: Colors.white60),
                      ),
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

class _DriverStatsScreen extends StatefulWidget {
  const _DriverStatsScreen({
    required this.memberId,
    required this.seasonId,
    required this.name,
  });
  final int memberId;
  final int? seasonId;
  final String name;

  @override
  State<_DriverStatsScreen> createState() => _DriverStatsScreenState();
}

class _DriverStatsScreenState extends State<_DriverStatsScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final uri = Uri.parse(_api).replace(
        queryParameters: {
          'action': 'standings.member.stats',
          'member_id': '${widget.memberId}',
          if (widget.seasonId != null) 'season_id': '${widget.seasonId}',
          'include_events': '0',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      final decoded = jsonDecode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map<String, dynamic> ||
          decoded['ok'] != true) {
        throw StateError('Unable to load driver statistics');
      }
      final data = decoded['message'];
      if (mounted) {
        setState(() => _data = data is Map<String, dynamic> ? data : decoded);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Driver statistics are temporarily unavailable.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final career = _data?['career'];
    final seasons = _data?['seasons'];
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        title: Text(widget.name),
        backgroundColor: const Color(0xFF111111),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'DRIVER STATISTICS',
            style: TextStyle(
              color: _gold,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          if (_data == null && _error == null)
            const LinearProgressIndicator(color: _red),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
          if (career is Map)
            Card(
              color: _surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CAREER',
                      style: TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Seasons: ${career['seasons_participated'] ?? 0}'),
                    Text('Points: ${career['career_points'] ?? 0}'),
                    Text('Race wins: ${career['career_race_wins'] ?? 0}'),
                    Text('Rounds won: ${career['career_rounds_won'] ?? 0}'),
                  ],
                ),
              ),
            ),
          if (seasons is List)
            for (final season in seasons)
              if (season is Map) ...[
                const SizedBox(height: 16),
                Text(
                  '${season['season_name'] ?? 'Season'}',
                  style: const TextStyle(
                    color: _gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (season['classes'] is List)
                  for (final racingClass in season['classes'])
                    if (racingClass is Map)
                      Card(
                        color: _surface,
                        child: ListTile(
                          title: Text('${racingClass['class_name'] ?? ''}'),
                          subtitle: Text(
                            'Rank #${racingClass['rank'] ?? '-'} · '
                            '${racingClass['race_wins'] ?? 0} race wins',
                          ),
                          trailing: Text(
                            '${racingClass['points'] ?? 0} pts',
                            style: const TextStyle(
                              color: _gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
              ],
        ],
      ),
    );
  }
}
