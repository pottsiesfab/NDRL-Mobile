import 'dart:async';

import 'package:flutter/material.dart';

import '../services/members_service.dart';
import 'member_profile_screen.dart';

const _background = Color(0xFF111111);
const _surface = Color(0xFF242428);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);

class NdrlMembersScreen extends StatefulWidget {
  const NdrlMembersScreen({super.key});

  @override
  State<NdrlMembersScreen> createState() => _NdrlMembersScreenState();
}

class _NdrlMembersScreenState extends State<NdrlMembersScreen> {
  final _service = NdrlMembersService();
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _seasons = [];
  List<Map<String, dynamic>> _members = [];
  int? _seasonId;
  int? _classId;
  Map<int, String> _availableClasses = {};
  bool _classesLoading = false;
  int _classGeneration = 0;
  bool _associates = false;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _total = 0;
  int _generation = 0;
  String? _error;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _generation++;
    _classGeneration++;
    _debounce?.cancel();
    _searchController.dispose();
    _service.dispose();
    super.dispose();
  }

  int _number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  String _string(dynamic value) => value?.toString() ?? '';

  Future<void> _initialize() async {
    final token = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final seasons = await _service.seasons();
      if (seasons.isEmpty) throw StateError('No seasons found');
      seasons.sort((a, b) => _number(b['year']).compareTo(_number(a['year'])));
      final seasonId = seasons.any((s) => _number(s['season_id']) == _seasonId)
          ? _seasonId!
          : _number(seasons.first['season_id']);
      if (!mounted || token != _generation) return;
      setState(() {
        _seasons = seasons;
        _seasonId = seasonId;
      });
      unawaited(_loadClasses());
      await _load(reset: true);
    } catch (_) {
      if (mounted && token == _generation) {
        setState(() {
          _error = 'Unable to load NDRL seasons.';
          _loading = false;
        });
      }
    }
  }

  // Discover classes from ALL pages of drivers for this season.
  // A first-page-only scan could miss classes further down the directory.
  Future<void> _loadClasses() async {
    final seasonId = _seasonId;
    if (seasonId == null) return;
    final token = ++_classGeneration;
    setState(() {
      _classesLoading = true;
      _availableClasses = {};
    });
    final found = <int, String>{};
    try {
      var offset = 0;
      const limit = 50;
      while (true) {
        final data = await _service.search(
          associates: false,
          seasonId: seasonId,
          offset: offset,
          limit: limit,
        );
        if (!mounted || token != _classGeneration) return;
        final rows = NdrlMembersService.items(data);
        for (final member in rows) {
          final cars = member['cars'];
          if (cars is! List) continue;
          for (final car in cars) {
            if (car is! Map) continue;
            final id = _number(car['class_id']);
            final name = _string(car['class_name']);
            if (id > 0 && name.isNotEmpty) found[id] = name;
          }
        }
        offset += rows.length;
        if (rows.isEmpty || offset >= _number(data['total'])) break;
      }
      if (mounted && token == _classGeneration) {
        setState(
          () => _availableClasses = Map.fromEntries(
            found.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
          ),
        );
      }
    } catch (_) {
      // Keep the directory usable if class discovery fails.
      if (mounted && token == _classGeneration) {
        setState(() => _availableClasses = {});
      }
    } finally {
      if (mounted && token == _classGeneration) {
        setState(() => _classesLoading = false);
      }
    }
  }

  Future<void> _load({required bool reset}) async {
    final seasonId = _seasonId;
    if (seasonId == null) return;
    if (!reset && (_loadingMore || !_hasMore)) return;
    final token = reset ? ++_generation : _generation;
    final offset = reset ? 0 : _members.length;
    setState(() {
      if (reset) {
        _members = [];
        _loading = true;
        _error = null;
        _hasMore = false;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final data = await _service.search(
        associates: _associates,
        seasonId: seasonId,
        query: _searchController.text.trim(),
        offset: offset,
        limit: _pageSize,
        classId: _associates ? null : _classId,
      );
      if (!mounted || token != _generation) return;
      final rows = NdrlMembersService.items(data);
      final total = _number(data['total']);
      setState(() {
        if (reset) {
          _members = rows;
        } else {
          _members.addAll(rows);
        }
        _total = total;
        _hasMore = _members.length < total && rows.isNotEmpty;
      });
    } catch (_) {
      if (mounted && token == _generation) {
        setState(() => _error = 'Unable to load members. Please retry.');
      }
    } finally {
      if (mounted && token == _generation) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_load(reset: true));
    });
  }

  void _selectTab(bool associates) {
    if (_associates == associates) return;
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _associates = associates);
    unawaited(_load(reset: true));
  }

  void _openProfile(Map<String, dynamic> member) {
    final id = _number(member['member_id']);
    if (id <= 0 || _seasonId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            NdrlMemberProfileScreen(memberId: id, seasonId: _seasonId!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        title: const Text('NDRL Members'),
      ),
      body: RefreshIndicator(
        color: _red,
        onRefresh: () => _load(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'MEMBER DIRECTORY',
              style: TextStyle(
                color: _gold,
                fontWeight: FontWeight.w900,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'NDRL membership · DEV',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Drivers'),
                  icon: Icon(Icons.sports_motorsports_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Associates'),
                  icon: Icon(Icons.people_outline),
                ),
              ],
              selected: {_associates},
              onSelectionChanged: (selection) => _selectTab(selection.first),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              key: ValueKey('members-season-$_seasonId'),
              initialValue: _seasonId,
              decoration: const InputDecoration(
                labelText: 'Season',
                border: OutlineInputBorder(),
              ),
              items: _seasons
                  .map(
                    (season) => DropdownMenuItem<int>(
                      value: _number(season['season_id']),
                      child: Text(_string(season['name'])),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null || value == _seasonId) return;
                _classGeneration++;
                setState(() {
                  _seasonId = value;
                  _classId = null;
                  _availableClasses = {};
                });
                unawaited(_loadClasses());
                unawaited(_load(reset: true));
              },
            ),
            const SizedBox(height: 12),
            if (!_associates) ...[
              DropdownButtonFormField<int?>(
                key: ValueKey('directory-class-$_seasonId-$_classId'),
                initialValue: _availableClasses.containsKey(_classId)
                    ? _classId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Racing Class',
                  border: const OutlineInputBorder(),
                  suffixIcon: _classesLoading
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All Classes'),
                  ),
                  for (final entry in _availableClasses.entries)
                    DropdownMenuItem<int?>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: _classesLoading
                    ? null
                    : (value) {
                        if (value == _classId) return;
                        setState(() => _classId = value);
                        unawaited(_load(reset: true));
                      },
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _searchController,
              onChanged: _searchChanged,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: _associates
                    ? 'Search associate name'
                    : 'Search driver name or car number',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _debounce?.cancel();
                    _searchController.clear();
                    unawaited(_load(reset: true));
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (_loading) const LinearProgressIndicator(color: _red),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
              TextButton.icon(
                onPressed: () => _load(reset: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
            if (!_loading && _error == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '$_total ${_associates ? 'associate members' : 'drivers'}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            if (!_loading && _error == null && _members.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No members found.')),
              ),
            for (final member in _members)
              Card(
                color: _surface,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  onTap: () => _openProfile(member),
                  leading: NdrlMemberAvatar(
                    url: _string(member['avatar_person_url']),
                  ),
                  title: Text(
                    '${_string(member['first_name'])} ${_string(member['last_name'])}'
                        .trim(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ([
                        _string(member['city']),
                        _string(member['state']),
                      ].where((s) => s.isNotEmpty).isNotEmpty)
                        Text(
                          [
                            _string(member['city']),
                            _string(member['state']),
                          ].where((s) => s.isNotEmpty).join(', '),
                        ),
                      if (!_associates && member['cars'] is List)
                        for (final car in member['cars'] as List)
                          if (car is Map &&
                              (_classId == null ||
                                  _number(car['class_id']) == _classId))
                            Text(
                              '${_string(car['class_name'])} · #${_string(car['car_number'])}',
                              style: const TextStyle(
                                color: _gold,
                                fontSize: 12,
                              ),
                            ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
            if (_hasMore && !_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: OutlinedButton(
                  onPressed: _loadingMore ? null : () => _load(reset: false),
                  child: Text(_loadingMore ? 'Loading...' : 'Load more'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
