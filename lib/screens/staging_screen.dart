import '../config/app_config.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../widgets/sponsor_ad_widget.dart';

const _surface = Color(0xFF242428);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);
const _latestSurface = Color(0xFF581A1C);
const _previousSurface = Color(0xFF40351D);

class NdrlStagingScreen extends StatefulWidget {
  const NdrlStagingScreen({
    super.key,
    required this.eventId,
    this.isActive = false,
  });

  final int eventId;

  /// Refresh only while the staging view is selected and the app is foregrounded.
  final bool isActive;

  @override
  State<NdrlStagingScreen> createState() => _NdrlStagingScreenState();
}

class _NdrlStagingScreenState extends State<NdrlStagingScreen>
    with WidgetsBindingObserver {
  static const _refreshInterval = Duration(seconds: 15);
  Timer? _refreshTimer;
  bool _appInForeground = true;
  bool _requestInProgress = false;

  bool get _shouldRefresh => widget.isActive && _appInForeground;

  void _updateRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (_shouldRefresh) {
      _refreshTimer = Timer.periodic(_refreshInterval, (_) => _refresh());
    }
  }

  @override
  void didUpdateWidget(covariant NdrlStagingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive ||
        oldWidget.eventId != widget.eventId) {
      _updateRefreshTimer();
      if (_shouldRefresh) _refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_appInForeground == foreground) return;
    _appInForeground = foreground;
    _updateRefreshTimer();
    if (_shouldRefresh) _refresh();
  }

  bool _loading = true;
  String? _error;
  String? _eventName;
  String? _generatedAt;
  List<_StagingClass> _classes = const [];
  bool _disposed = false;

  // The API determines call priority; retain the configured class order.
  List<_StagingClass> get _displayClasses => _classes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateRefreshTimer();
    if (_shouldRefresh) _refresh();
  }

  Future<void> _refresh() async {
    if (_requestInProgress) return;
    final requestedEventId = widget.eventId;
    _requestInProgress = true;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http
          .get(
            AppConfig.apiUri(
              '/api/notify_staging_board_api.php',
              queryParameters: {'event_id': requestedEventId.toString()},
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw StateError('Server returned HTTP ${response.statusCode}');
      }
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic> || json['success'] != true) {
        throw const FormatException('Unexpected staging API response');
      }
      if (json['event_id'] != requestedEventId || json['classes'] is! List) {
        throw const FormatException('Unexpected event or class data');
      }
      final parsed = (json['classes'] as List).map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid class record');
        }
        return _StagingClass.fromJson(item);
      }).toList()..sort((a, b) => a.order.compareTo(b.order));
      if (!mounted || _disposed || widget.eventId != requestedEventId) return;
      setState(() {
        _classes = parsed;
        _eventName = json['event_name'] as String?;
        _generatedAt = json['generated_at'] as String?;
      });
    } catch (_) {
      if (!mounted || _disposed) return;
      setState(() {
        _error = 'Unable to refresh staging information. Check your connection and try again.';
      });
    } finally {
      _requestInProgress = false;
      if (mounted && !_disposed) setState(() => _loading = false);
    }
  }

  int _highlightRank(_StagingClass item) => switch (item.callPriority) {
    'latest' => 1,
    'previous' => 2,
    _ => 0,
  };

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(decoration: TextDecoration.none),
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: _red,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'CURRENT CLASS CALLS',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh staging',
                  onPressed: _loading ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (AppConfig.isDev)
              const Text(
                'DEV ENVIRONMENT · TEST DATA',
                style: TextStyle(color: _gold, fontSize: 11),
              ),
            const SizedBox(height: 6),
            Text(
              widget.isActive
                  ? 'Auto-refresh every 15 seconds'
                  : 'Auto-refresh paused',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 12),
            Text(
              _eventName ?? 'Loading event...',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            if (_generatedAt != null) ...[
              const SizedBox(height: 5),
              Text(
                'API updated: $_generatedAt',
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(color: _red),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
            const SizedBox(height: 14),
            for (final item in _displayClasses) ...[
              _ClassCard(item: item, highlightRank: _highlightRank(item)),
              const SizedBox(height: 10),
            ],
            if (!_loading && _classes.isEmpty && _error == null)
              const Text('No classes were returned for this event.'),
            const SizedBox(height: 18),
            NdrlSponsorAdWidget(
              placement: 'staging_banner',
              isActive: widget.isActive,
              heading: 'FEATURED NDRL PARTNER',
            ),
          ],
        ),
      ),
    );
  }
}

class _StagingClass {
  const _StagingClass({
    required this.name,
    required this.order,
    required this.state,
    required this.round,
    required this.hasRecord,
    required this.callPriority,
  });

  final String name;
  final int order;
  final String state;
  final String? round;
  final bool hasRecord;
  final String? callPriority;

  factory _StagingClass.fromJson(Map<String, dynamic> json) {
    final name = json['class_name'];
    final order = json['display_order'];
    final state = json['staging_state'];
    if (name is! String || order is! num || state is! String) {
      throw const FormatException('Missing required staging class fields');
    }
    return _StagingClass(
      name: name,
      order: order.toInt(),
      state: state,
      round: json['round_label'] as String?,
      hasRecord: json['has_staging_record'] == true,
      callPriority: switch (json['call_priority']) {
        'latest' => 'latest',
        'previous' => 'previous',
        _ => null,
      },
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.item, required this.highlightRank});

  final _StagingClass item;
  final int highlightRank;

  @override
  Widget build(BuildContext context) {
    final latest = highlightRank == 1;
    final previous = highlightRank == 2;
    final highlighted = latest || previous;
    final accent = latest
        ? _red
        : previous
        ? _gold
        : Colors.white54;
    final background = latest
        ? _latestSurface
        : previous
        ? _previousSurface
        : _surface;
    final status = switch (item.state) {
      'not_called' => 'No call yet',
      'on_deck' => 'On Deck',
      'called' => 'Called',
      _ => item.state.replaceAll('_', ' ').toUpperCase(),
    };
    final hasCall = item.state != 'not_called' && item.hasRecord;
    final round = item.round?.trim() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: highlighted ? accent : Colors.white10,
          width: highlighted ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (highlighted) ...[
                    const SizedBox(height: 4),
                    Text(
                      latest ? 'LATEST CALL' : 'PREVIOUS CALL',
                      style: TextStyle(
                        color: latest ? Colors.white : _gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 6,
              child: Text.rich(
                TextSpan(
                  children: [
                    if (hasCall && round.isNotEmpty)
                      TextSpan(text: '$round - '),
                    TextSpan(
                      text: hasCall ? status : 'No call yet',
                      style: TextStyle(
                        color: hasCall ? _gold : Colors.white54,
                        fontWeight: hasCall
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.right,
                softWrap: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
