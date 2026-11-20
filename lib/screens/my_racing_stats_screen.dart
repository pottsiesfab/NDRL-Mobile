import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../services/auth_service.dart';
import '../services/season_context_service.dart';

const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);
const _surface = Color(0xFF242428);
const _background = Color(0xFF111111);

class NdrlMyRacingStatsScreen extends StatefulWidget {
  const NdrlMyRacingStatsScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<NdrlMyRacingStatsScreen> createState() =>
      _NdrlMyRacingStatsScreenState();
}

class _NdrlMyRacingStatsScreenState extends State<NdrlMyRacingStatsScreen> {
  final http.Client _client = http.Client();
  List<Map<String, dynamic>> _seasons = [];
  Map<String, dynamic>? _career;
  List<Map<String, dynamic>> _seasonRows = [];
  int? _seasonId;
  bool _loading = true;
  String? _error;
  int _generation = 0;

  int _number(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  String _display(dynamic v, [String fallback = '—']) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? fallback : s;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _generation++;
    _client.close();
    super.dispose();
  }

  Future<Map<String, dynamic>> _request(
    String action,
    Map<String, String> params,
  ) async {
    final uri = AppConfig.apiUri(
      '/api/standings_public_api.php',
      queryParameters: {'action': action, ...params},
    );
    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        response.statusCode != 200 ||
        decoded['ok'] != true) {
      throw StateError(
        'Could not load racing statistics (HTTP ${response.statusCode}).',
      );
    }
    final message = decoded['message'];
    if (message is! Map) {
      throw const FormatException('Unexpected statistics response');
    }
    return Map<String, dynamic>.from(message);
  }

  List<Map<String, dynamic>> _rows(dynamic value) {
    if (value is! List) return [];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _load({int? selectedSeason}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final memberId = _number(widget.authService.account?['member_id']);
      if (memberId <= 0) {
        throw StateError(
          'This account is not linked to an NDRL member record.',
        );
      }
      final seasonsPayload = await _request('season.list', {'limit': '200'});
      final seasons = _rows(seasonsPayload['items']);
      seasons.sort(
        (a, b) => _number(b['season_id']).compareTo(_number(a['season_id'])),
      );
      int? activeId;
      try {
        activeId = (await SeasonContextService(
          client: _client,
        ).load()).seasonId;
      } catch (_) {
        // Fall back to the latest available season if season context is unavailable.
      }
      final wanted = selectedSeason ?? _seasonId ?? activeId;
      final seasonId = seasons.any((s) => _number(s['season_id']) == wanted)
          ? wanted
          : (seasons.isEmpty ? null : _number(seasons.first['season_id']));
      // Fetch unfiltered career totals so changing the season never changes career figures.
      final careerPayload = await _request('standings.member.stats', {
        'member_id': '$memberId',
        'include_events': '0',
      });
      Map<String, dynamic> career = {};
      if (careerPayload['career'] is Map) {
        career = Map<String, dynamic>.from(careerPayload['career'] as Map);
      }
      final seasonPayload = seasonId == null
          ? careerPayload
          : await _request('standings.member.stats', {
              'member_id': '$memberId',
              'season_id': '$seasonId',
              'include_events': '0',
            });
      final seasonRows = _rows(seasonPayload['seasons']);
      if (!mounted || generation != _generation) return;
      setState(() {
        _seasons = seasons;
        _seasonId = seasonId;
        _career = career;
        _seasonRows = seasonRows
            .where(
              (s) => seasonId == null || _number(s['season_id']) == seasonId,
            )
            .toList();
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _stat(String label, dynamic value) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _display(value, '0'),
          style: const TextStyle(
            fontSize: 26,
            color: _gold,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _classCard(Map<String, dynamic> racingClass) => Card(
    color: _surface,
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _display(racingClass['class_name'], 'Class'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Rank #${_display(racingClass['rank'])}',
                style: const TextStyle(color: _gold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_display(racingClass['points'], '0')} points',
            style: const TextStyle(
              color: _gold,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text('Race wins: ${_display(racingClass['race_wins'], '0')}'),
              if (racingClass.containsKey('round_wins'))
                Text('Rounds won: ${_display(racingClass['round_wins'], '0')}'),
              if (racingClass.containsKey('events_entered'))
                Text('Events: ${_display(racingClass['events_entered'], '0')}'),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final career = _career;
    final selected = _seasons
        .where((s) => _number(s['season_id']) == _seasonId)
        .toList();
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('My Racing Stats'),
        backgroundColor: _background,
      ),
      body: RefreshIndicator(
        color: _red,
        onRefresh: () => _load(selectedSeason: _seasonId),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            const Text(
              'CAREER STATISTICS',
              style: TextStyle(
                color: _gold,
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(color: _red),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
            if (!_loading && _error == null && career != null) ...[
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: [
                  _stat('Career Points', career['career_points']),
                  _stat('Race Wins', career['career_race_wins']),
                  _stat('Rounds Won', career['career_rounds_won']),
                  _stat(
                    'Unique Events Attended',
                    career['member_attended_events'],
                  ),
                  _stat('Seasons Participated', career['seasons_participated']),
                ],
              ),
              const SizedBox(height: 26),
              const Text(
                'SEASON STATISTICS',
                style: TextStyle(
                  color: _gold,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              if (_seasons.isNotEmpty)
                DropdownButtonFormField<int>(
                  key: ValueKey(_seasonId),
                  initialValue: _seasonId,
                  dropdownColor: _surface,
                  decoration: const InputDecoration(
                    labelText: 'Championship Season',
                    border: OutlineInputBorder(),
                  ),
                  items: _seasons
                      .map(
                        (s) => DropdownMenuItem<int>(
                          value: _number(s['season_id']),
                          child: Text(
                            _display(
                              s['season_name'],
                              'Season ${s['season_id']}',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) unawaited(_load(selectedSeason: value));
                  },
                ),
              const SizedBox(height: 14),
              if (_seasonRows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'No racing statistics for this season.',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else
                for (final season in _seasonRows) ...[
                  if (selected.isEmpty) Text(_display(season['season_name'])),
                  for (final racingClass in _rows(season['classes']))
                    _classCard(racingClass),
                ],
            ],
          ],
        ),
      ),
    );
  }
}
