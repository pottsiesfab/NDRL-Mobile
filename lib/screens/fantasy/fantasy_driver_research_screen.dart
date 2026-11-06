import 'package:flutter/material.dart';

import '../../widgets/sponsor_ad_widget.dart';

import '../../services/fantasy_service.dart';

const _bg = Color(0xFF080A12);
const _panel = Color(0xFF101525);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFC52A35);

int _number(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double _decimal(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
String _money(dynamic cents) =>
    '\$${(_number(cents) / 100).toStringAsFixed(0)}';

class NdrlFantasyDriverResearchScreen extends StatefulWidget {
  const NdrlFantasyDriverResearchScreen({super.key, required this.season});
  final FantasySeason season;
  @override
  State<NdrlFantasyDriverResearchScreen> createState() =>
      _DriverResearchState();
}

class _DriverResearchState extends State<NdrlFantasyDriverResearchScreen> {
  final _service = NdrlFantasyService();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _drivers = [];
  final Map<int, List<Map<String, dynamic>>> _stats = {};
  final Set<int> _expanded = {};
  bool _loading = true;
  String? _error;
  String _sort = 'price';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final drivers = await _service.driverPrices(widget.season.id);
      final classIds =
          drivers
              .map((d) => _number(d['portal_class_id']))
              .where((id) => id > 0)
              .toSet()
              .toList()
            ..sort();
      final stats = <int, List<Map<String, dynamic>>>{};
      for (final classId in classIds) {
        stats[classId] = await _service.driverStats(widget.season.id, classId);
      }
      if (!mounted) return;
      setState(() {
        _drivers = drivers;
        _stats
          ..clear()
          ..addAll(stats);
        _expanded.addAll(classIds);
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

  Map<String, dynamic>? _statFor(Map<String, dynamic> driver) {
    final classId = _number(driver['portal_class_id']);
    final msc = _number(driver['portal_msc_id']);
    for (final stat in _stats[classId] ?? const <Map<String, dynamic>>[]) {
      if (_number(stat['portal_msc_id']) == msc) return stat;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final driver in _drivers) {
      if (!'${driver['display_name'] ?? ''}'.toLowerCase().contains(query))
        continue;
      grouped
          .putIfAbsent(_number(driver['portal_class_id']), () => [])
          .add(driver);
    }
    for (final group in grouped.values) {
      group.sort((a, b) {
        switch (_sort) {
          case 'name':
            return '${a['display_name']}'.compareTo('${b['display_name']}');
          case 'points':
            return _number(_statFor(b)?['total_points'])
                .compareTo(_number(_statFor(a)?['total_points']));
          case 'value':
            final aPrice = _number(a['effective_price_cents']);
            final bPrice = _number(b['effective_price_cents']);
            final aValue = aPrice > 0
                ? _decimal(_statFor(a)?['ppd']) / (aPrice / 100)
                : 0.0;
            final bValue = bPrice > 0
                ? _decimal(_statFor(b)?['ppd']) / (bPrice / 100)
                : 0.0;
            return bValue.compareTo(aValue);
          default:
            return _number(b['effective_price_cents'])
                .compareTo(_number(a['effective_price_cents']));
        }
      });
    }
    final ids = grouped.keys.toList()..sort();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        title: const Text('DRIVER RESEARCH'),
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
              widget.season.name,
              style: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Compare driver prices and performance by class.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            const NdrlSponsorAdWidget(
              placement: 'fantasy_banner',
              heading: 'FANTASY LEAGUE SPONSORS',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: _gold),
                hintText: 'Search drivers',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: _panel,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Sort:', style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _sort,
                  dropdownColor: _panel,
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(
                      value: 'price',
                      child: Text('Price (high first)'),
                    ),
                    DropdownMenuItem(value: 'name', child: Text('Driver name')),
                    DropdownMenuItem(
                      value: 'points',
                      child: Text('Season points'),
                    ),
                    DropdownMenuItem(
                      value: 'value',
                      child: Text('Points per dollar'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _sort = v);
                  },
                ),
              ],
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: _red)),
              )
            else if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.white70)),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ] else if (ids.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No drivers found.',
                  style: TextStyle(color: Colors.white70),
                ),
              )
            else
              ...ids.map((classId) {
                final drivers = grouped[classId]!;
                final expanded =
                    _expanded.contains(classId) || query.isNotEmpty;
                final className =
                    '${drivers.first['class_name'] ?? 'Class $classId'}';
                return Card(
                  color: _panel,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(
                          className,
                          style: const TextStyle(
                            color: _gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${drivers.length} drivers',
                          style: const TextStyle(color: Colors.white60),
                        ),
                        trailing: Icon(
                          expanded ? Icons.expand_less : Icons.expand_more,
                          color: _gold,
                        ),
                        onTap: () => setState(() {
                          if (!_expanded.add(classId))
                            _expanded.remove(classId);
                        }),
                      ),
                      if (expanded)
                        ...drivers.map((driver) {
                          final stat = _statFor(driver);
                          final delta = _number(driver['last_delta_cents']);
                          return Column(
                            children: [
                              const Divider(height: 1, color: Colors.white12),
                              ListTile(
                                title: Text(
                                  '${driver['display_name']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Pts/event: ${stat == null ? '—' : _decimal(stat['ppd']).toStringAsFixed(1)}  •  Season pts: ${stat?['total_points'] ?? '—'}',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _money(
                                            driver['effective_price_cents'],
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        Text(
                                          delta == 0
                                              ? 'No change'
                                              : '${delta > 0 ? '+' : '-'}${_money(delta.abs())}',
                                          style: TextStyle(
                                            color: delta > 0
                                                ? Colors.greenAccent
                                                : delta < 0
                                                ? Colors.redAccent
                                                : Colors.white54,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: _gold,
                                    ),
                                  ],
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        NdrlFantasyDriverProfileScreen(
                                          season: widget.season,
                                          driver: driver,
                                          initialStats: stat,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class NdrlFantasyDriverProfileScreen extends StatefulWidget {
  const NdrlFantasyDriverProfileScreen({
    super.key,
    required this.season,
    required this.driver,
    this.initialStats,
  });
  final FantasySeason season;
  final Map<String, dynamic> driver;
  final Map<String, dynamic>? initialStats;
  @override
  State<NdrlFantasyDriverProfileScreen> createState() => _DriverProfileState();
}

class _DriverProfileState extends State<NdrlFantasyDriverProfileScreen> {
  final _service = NdrlFantasyService();
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _stats = widget.initialStats;
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
      final list = await _service.driverStats(
        widget.season.id,
        _number(widget.driver['portal_class_id']),
        includeEvents: true,
      );
      final id = _number(widget.driver['portal_msc_id']);
      final found = list.where((s) => _number(s['portal_msc_id']) == id);
      if (!mounted) return;
      setState(() {
        _stats = found.isEmpty ? _stats : found.first;
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

  Widget _metric(String label, String value) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final stat = _stats;
    final trend = stat?['trends'] is Map
        ? Map<String, dynamic>.from(stat!['trends'] as Map)
        : <String, dynamic>{};
    final events = stat?['events'] is List
        ? (stat!['events'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];
    final delta = _number(widget.driver['last_delta_cents']);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        title: const Text('DRIVER PROFILE'),
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
              '${widget.driver['class_name'] ?? ''}',
              style: const TextStyle(color: _gold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.driver['display_name']}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (stat?['car_number'] != null)
              Text(
                'Car #${stat!['car_number']}',
                style: const TextStyle(color: Colors.white60),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF26111B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _red),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Current Fantasy price',
                    style: TextStyle(color: _gold, fontWeight: FontWeight.bold),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _money(widget.driver['effective_price_cents']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        delta == 0
                            ? 'No change'
                            : '${delta > 0 ? '+' : '-'}${_money(delta.abs())}',
                        style: TextStyle(
                          color: delta > 0
                              ? Colors.greenAccent
                              : delta < 0
                              ? Colors.redAccent
                              : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const NdrlSponsorAdWidget(
              placement: 'fantasy_banner',
              heading: 'FANTASY LEAGUE SPONSORS',
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator(color: _red)),
            if (_error != null)
              Text(
                'Unable to refresh event history: $_error',
                style: const TextStyle(color: Colors.white70),
              ),
            if (stat != null) ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 12) / 2;
                  final metrics = <Widget>[
                    _metric(
                      'Class rank',
                      stat['rank_in_class'] == null
                          ? '—'
                          : '#${stat['rank_in_class']}',
                    ),
                    _metric(
                      'Championship points',
                      '${stat['total_points'] ?? '—'}',
                    ),
                    _metric(
                      'Points / event',
                      _decimal(stat['ppd']).toStringAsFixed(1),
                    ),
                    _metric(
                      'Events entered',
                      '${stat['events_entered'] ?? '—'}',
                    ),
                    _metric('Rounds won', '${stat['total_rounds_won'] ?? '—'}'),
                    _metric('Event wins', '${stat['event_wins'] ?? '—'}'),
                    _metric(
                      'Avg. qualifying position',
                      stat['avg_qual_pos'] == null
                          ? '—'
                          : _decimal(stat['avg_qual_pos']).toStringAsFixed(1),
                    ),
                    _metric(
                      'Fantasy selections',
                      '${stat['pick_count'] ?? '—'}',
                    ),
                  ];
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: metrics
                        .map((m) => SizedBox(width: width, child: m))
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'PERFORMANCE TREND',
                style: TextStyle(color: _gold, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Direction: ${trend['trend_direction'] ?? 'Not available'}  •  Last 3 avg: ${trend['avg_last3_pts'] == null ? '—' : _decimal(trend['avg_last3_pts']).toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white70),
              ),
              if (trend['value_score'] != null)
                Text(
                  'API value score: ${_decimal(trend['value_score']).toStringAsFixed(3)}',
                  style: const TextStyle(color: Colors.white70),
                ),
              const SizedBox(height: 20),
              const Text(
                'EVENT-BY-EVENT RESULTS',
                style: TextStyle(color: _gold, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (!_loading && events.isEmpty)
                const Text(
                  'No event history available.',
                  style: TextStyle(color: Colors.white70),
                ),
              ...events.map(
                (e) => Card(
                  color: _panel,
                  child: ListTile(
                    title: Text(
                      '${e['event_nick_name'] ?? e['event_name'] ?? 'Event'}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${e['event_date'] ?? ''} • Qual: ${e['qual_pos'] ?? '—'} • Rounds won: ${e['rounds_won'] ?? '—'}${_number(e['is_event_winner']) == 1 ? ' • WINNER' : ''}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Text(
                      '${e['pts_total'] ?? '—'} pts',
                      style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Event results and season points are NDRL championship statistics, not Fantasy roster points.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
