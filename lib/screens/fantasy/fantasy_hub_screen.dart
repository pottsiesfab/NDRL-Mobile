import 'package:flutter/material.dart';

import '../../services/fantasy_service.dart';
import '../../services/auth_service.dart';
import 'fantasy_my_team_screen.dart';

const _background = Color(0xFF080A12);
const _panel = Color(0xFF101525);
const _accent = Color(0xFFC52A35);
const _gold = Color(0xFFD1AC67);

class NdrlFantasyHubScreen extends StatefulWidget {
  const NdrlFantasyHubScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<NdrlFantasyHubScreen> createState() => _NdrlFantasyHubScreenState();
}

class _NdrlFantasyHubScreenState extends State<NdrlFantasyHubScreen> {
  final _service = NdrlFantasyService();
  List<FantasySeason> _seasons = [];
  int? _selectedSeasonId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSeasons();
  }

  Future<void> _loadSeasons() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final seasons = await _service.seasons();
      if (!mounted) return;
      setState(() {
        _seasons = seasons;
        if (!seasons.any((s) => s.id == _selectedSeasonId)) {
          _selectedSeasonId = seasons.isEmpty ? null : seasons.first.id;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  void _openDestination(String title) {
    if (title == 'My Team') {
      final season = _seasons
          .where((s) => s.id == _selectedSeasonId)
          .firstOrNull;
      if (season == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a Fantasy season first.')),
        );
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NdrlFantasyMyTeamScreen(
            authService: widget.authService,
            season: season,
          ),
        ),
      );
      return;
    }
    final season = _seasons.where((s) => s.id == _selectedSeasonId).firstOrNull;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: _background,
          appBar: AppBar(title: Text(title), backgroundColor: _background),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.construction_outlined, color: _gold, size: 38),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Selected season: ${season?.name ?? 'None'}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This section is ready for its Fantasy API integration.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final season = _seasons.where((s) => s.id == _selectedSeasonId).firstOrNull;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'NDRL FANTASY',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
        ),
        backgroundColor: _background,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh seasons',
            onPressed: _loading ? null : _loadSeasons,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSeasons,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2B0C13), Color(0xFF10101C)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _accent.withValues(alpha: .6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FANTASY RACING',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your Fantasy League Headquarters',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage your team, pick drivers, follow events and chase the championship.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'FANTASY SEASON',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    const LinearProgressIndicator(color: _accent)
                  else if (_error != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Unable to load Fantasy seasons.',
                          style: TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        TextButton(
                          onPressed: _loadSeasons,
                          child: const Text('Retry'),
                        ),
                      ],
                    )
                  else if (_seasons.isEmpty)
                    const Text(
                      'No Fantasy seasons available.',
                      style: TextStyle(color: Colors.white70),
                    )
                  else
                    DropdownButtonFormField<int>(
                      key: ValueKey(_selectedSeasonId),
                      initialValue: _selectedSeasonId,
                      dropdownColor: _panel,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: _panel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: _seasons
                          .map(
                            (s) => DropdownMenuItem<int>(
                              value: s.id,
                              child: Text(
                                '${s.year} — ${s.name}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedSeasonId = value),
                    ),
                  if (season != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Season status: ${season.status}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'MY FANTASY',
              style: TextStyle(
                color: _gold,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _tile(
              'My Team',
              'Dashboard and season performance',
              Icons.dashboard_outlined,
            ),
            _tile(
              'My Rosters',
              'Current selections and roster history',
              Icons.groups_outlined,
            ),
            _tile(
              'Roster Picker',
              'Choose drivers and your captain',
              Icons.edit_note_outlined,
            ),
            const SizedBox(height: 20),
            const Text(
              'LEAGUE & RESEARCH',
              style: TextStyle(
                color: _gold,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _tile(
              'Season Standings',
              'Championship rankings and points',
              Icons.emoji_events_outlined,
            ),
            _tile(
              'Events',
              'Schedule, results and event standings',
              Icons.event_outlined,
            ),
            _tile(
              'Driver Pricing',
              'Prices and price movement by class',
              Icons.attach_money,
            ),
            _tile(
              'Other Teams',
              'Explore teams and eligible public rosters',
              Icons.people_outline,
            ),
            _tile(
              'Driver Stats',
              'Fantasy driver performance research',
              Icons.query_stats_outlined,
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _tile(String title, String subtitle, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: _panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDestination(title),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Icon(icon, color: _gold, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    ),
  );
}
