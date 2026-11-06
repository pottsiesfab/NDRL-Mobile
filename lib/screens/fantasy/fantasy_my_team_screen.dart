import 'package:flutter/material.dart';

import '../../widgets/sponsor_ad_widget.dart';

import '../../services/auth_service.dart';
import '../../services/fantasy_service.dart';

const _background = Color(0xFF080A12);
const _panel = Color(0xFF101525);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFC52A35);

class NdrlFantasyMyTeamScreen extends StatefulWidget {
  const NdrlFantasyMyTeamScreen({
    super.key,
    required this.authService,
    required this.season,
  });

  final AuthService authService;
  final FantasySeason season;

  @override
  State<NdrlFantasyMyTeamScreen> createState() =>
      _NdrlFantasyMyTeamScreenState();
}

class _NdrlFantasyMyTeamScreenState extends State<NdrlFantasyMyTeamScreen> {
  final _service = NdrlFantasyService();
  Map<String, dynamic>? _result;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!widget.authService.signedIn) {
        throw const AuthException(
          'Sign in to your NDRL account to view your Fantasy team.',
        );
      }
      final result = await _service.myStats(
        authService: widget.authService,
        fantasySeasonId: widget.season.id,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  String _value(dynamic v, {int decimals = 0, String prefix = ''}) {
    if (v == null) return '—';
    if (v is num)
      return '$prefix${decimals == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(decimals)}';
    return '$prefix$v';
  }

  Widget _stat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _gold, size: 23),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _result;
    final hasTeam = data?['has_team'] == true;
    final team = data?['team'] is Map
        ? Map<String, dynamic>.from(data!['team'] as Map)
        : <String, dynamic>{};
    final stats = data?['season_stats'] is Map
        ? Map<String, dynamic>.from(data!['season_stats'] as Map)
        : <String, dynamic>{};

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('MY FANTASY TEAM'),
        backgroundColor: _background,
        foregroundColor: Colors.white,
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
            const SizedBox(height: 16),
            const NdrlSponsorAdWidget(
              placement: 'fantasy_banner',
              heading: 'FANTASY LEAGUE SPONSORS',
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 50),
                child: Center(child: CircularProgressIndicator(color: _red)),
              )
            else if (_error != null) ...[
              const Icon(Icons.error_outline, color: _gold, size: 36),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.white70)),
              TextButton(onPressed: _load, child: const Text('Try again')),
            ] else if (!hasTeam) ...[
              const Icon(Icons.groups_outlined, color: _gold, size: 42),
              const SizedBox(height: 14),
              const Text(
                'No Fantasy team for this season',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your account does not have a team registered for the selected Fantasy season.',
                style: TextStyle(color: Colors.white70),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2B0C13), _panel],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _red),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR TEAM',
                      style: TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${team['name'] ?? 'Fantasy Team'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Championship performance • ${widget.season.year}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'SEASON PERFORMANCE',
                style: TextStyle(
                  color: _gold,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: width,
                        child: _stat(
                          'Season rank',
                          _value(stats['rank'], prefix: '#'),
                          Icons.emoji_events_outlined,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _stat(
                          'Total points',
                          _value(stats['total_points']),
                          Icons.stars_outlined,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _stat(
                          'Events scored',
                          '${_value(stats['events_scored'])} / ${_value(stats['events_total'])}',
                          Icons.flag_outlined,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _stat(
                          'Best finish',
                          _value(stats['best_finish'], prefix: '#'),
                          Icons.workspace_premium_outlined,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _stat(
                          'Average finish',
                          _value(stats['avg_finish'], decimals: 1),
                          Icons.query_stats_outlined,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _stat(
                          'Total teams',
                          _value(stats['total_teams']),
                          Icons.groups_outlined,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
