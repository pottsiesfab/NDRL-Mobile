import '../config/app_config.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../widgets/sponsor_ad_widget.dart';

const _surface = Color(0xFF242428);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);
const _apiUrl =
    '${AppConfig.baseUrl}/api/notify_staging_board_api.php?event_id=14';

class NdrlStagingScreen extends StatefulWidget {
  const NdrlStagingScreen({super.key, this.isActive = false});

  /// The IndexedStack keeps this screen mounted while other tabs are shown.
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
    if (oldWidget.isActive != widget.isActive) {
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateRefreshTimer();
    if (_shouldRefresh) _refresh();
  }

  Future<void> _refresh() async {
    if (_requestInProgress) return;
    _requestInProgress = true;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw StateError('Server returned HTTP ${response.statusCode}');
      }
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic> || json['success'] != true) {
        throw const FormatException('Unexpected staging API response');
      }
      if (json['event_id'] != 14 || json['classes'] is! List) {
        throw const FormatException('Unexpected event or class data');
      }
      final parsed = (json['classes'] as List).map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid class record');
        }
        return _StagingClass.fromJson(item);
      }).toList()..sort((a, b) => a.order.compareTo(b.order));
      if (!mounted || _disposed) return;
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

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
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
                  'LIVE STAGING',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 23,
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
          const Text(
            'DEV TEST EVENT · NOT LIVE RACE INFORMATION',
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
          for (final item in _classes) ...[
            _ClassCard(item: item),
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
  });

  final String name;
  final int order;
  final String state;
  final String? round;
  final bool hasRecord;

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
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.item});

  final _StagingClass item;

  @override
  Widget build(BuildContext context) {
    final label = switch (item.state) {
      'on_deck' => 'ON DECK',
      'not_called' => 'NOT CALLED',
      _ => item.state.replaceAll('_', ' ').toUpperCase(),
    };
    final accent = item.state == 'on_deck' ? _gold : Colors.white54;

    return Card(
      color: _surface,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 58,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  if (item.round != null && item.round!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.round!,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
                if (!item.hasRecord)
                  const Text(
                    'No call yet',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
