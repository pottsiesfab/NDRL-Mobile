import '../config/app_config.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const _background = Color(0xFF111111);
const _surface = Color(0xFF242428);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);
const _catalogUrl = '${AppConfig.baseUrl}/api/notify_catalog_api.php';

class NdrlEventsScreen extends StatefulWidget {
  const NdrlEventsScreen({super.key});

  @override
  State<NdrlEventsScreen> createState() => _NdrlEventsScreenState();
}

class _NdrlEventsScreenState extends State<NdrlEventsScreen> {
  final http.Client _client = http.Client();
  List<_RaceEvent> _events = [];
  bool _loading = true;
  String? _error;
  String? _seasonLabel;

  @override
  void initState() {
    super.initState();
    unawaited(_loadEvents());
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      // The context API reads the active season from the authoritative Portal
      // database, so this screen never needs a hardcoded season ID.
      final contextResponse = await _client
          .get(
            AppConfig.apiUri('/api/ndrl_context_api.php'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 20));

      final contextData = jsonDecode(contextResponse.body);
      if (contextData is! Map<String, dynamic> ||
          contextResponse.statusCode != 200 ||
          contextData['success'] != true) {
        throw const FormatException('Unable to load NDRL season context');
      }

      final seasonId = contextData['active_season_id'];
      if (seasonId is! num || seasonId.toInt() <= 0) {
        throw const FormatException('No active NDRL season is configured');
      }

      final activeSeason = contextData['active_season'];
      final seasonName = activeSeason is Map<String, dynamic>
          ? activeSeason['name']?.toString()
          : null;
      final seasonYear = contextData['active_season_year'];
      final seasonLabel = seasonName?.trim().isNotEmpty == true
          ? seasonName!.trim()
          : seasonYear != null
          ? '$seasonYear Season'
          : 'Active Season';

      final uri = Uri.parse(_catalogUrl).replace(
        queryParameters: {
          'action': 'events',
          'season_id': seasonId.toInt().toString(),
        },
      );
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> ||
          response.statusCode != 200 ||
          data['success'] != true) {
        throw const FormatException('Unable to load events');
      }
      final raw = data['events'];
      if (raw is! List) {
        throw const FormatException('Invalid event list');
      }
      final events = raw.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid event');
        }
        return _RaceEvent.fromJson(item);
      }).toList();
      events.sort((a, b) {
        final dateOrder = _compareDates(a.startDate, b.startDate);
        return dateOrder != 0 ? dateOrder : a.id.compareTo(b.id);
      });
      if (!mounted) return;
      setState(() {
        _events = events;
        _seasonLabel = seasonLabel;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load NDRL events. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static int _compareDates(DateTime? a, DateTime? b) {
    if (a == null) return b == null ? 0 : 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  Future<void> _openInfo(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw StateError('Could not open link');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the event information link.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _background,
      child: RefreshIndicator(
        color: _red,
        onRefresh: _loadEvents,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'NDRL EVENTS',
                    style: TextStyle(
                      color: _gold,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh events',
                  icon: const Icon(Icons.refresh),
                  onPressed: _loading ? null : _loadEvents,
                ),
              ],
            ),
            Text(
              (_seasonLabel ?? 'ACTIVE SEASON SCHEDULE').toUpperCase(),
              style: const TextStyle(color: _gold, fontSize: 11),
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(color: _red),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _loadEvents,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
            if (!_loading && _error == null && _events.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64, horizontal: 16),
                child: Column(
                  children: [
                    Icon(Icons.event_busy_outlined, size: 56, color: _gold),
                    SizedBox(height: 12),
                    Text(
                      'No events scheduled',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Pull down to check for schedule updates.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            for (final event in _events)
              _EventCard(event: event, onOpenInfo: _openInfo),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _RaceEvent {
  const _RaceEvent({
    required this.id,
    required this.name,
    required this.status,
    this.startDate,
    this.endDate,
    this.raceDayDate,
    this.adUrl,
    this.infoUrl,
  });

  final int id;
  final String name;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? raceDayDate;
  final Uri? adUrl;
  final Uri? infoUrl;

  factory _RaceEvent.fromJson(Map<String, dynamic> json) {
    final id = json['event_id'];
    final name = json['name'];
    if (id is! num || name is! String) {
      throw const FormatException('Invalid event data');
    }
    return _RaceEvent(
      id: id.toInt(),
      name: name,
      status: json['status']?.toString() ?? 'scheduled',
      startDate: _parseDate(json['start_date']),
      endDate: _parseDate(json['end_date']),
      raceDayDate: _parseDate(json['race_day_date']),
      adUrl: _parseWebUrl(json['event_ad_url']),
      infoUrl: _parseWebUrl(json['event_info_url']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    // Calendar dates are treated as dates, not UTC timestamps, to avoid
    // shifting a race day across time zones.
    final text = value.toString().trim();
    return DateTime.tryParse(text.length >= 10 ? text.substring(0, 10) : text);
  }

  static Uri? _parseWebUrl(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;

    final parsed = Uri.tryParse(value.trim());
    if (parsed == null) return null;

    // Portal stores event flyers and information links as relative paths.
    // Resolve them against the current DEV/PROD base URL.
    final uri = parsed.hasScheme
        ? parsed
        : Uri.parse(AppConfig.baseUrl).resolveUri(parsed);

    return (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty
        ? uri
        : null;
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onOpenInfo});

  final _RaceEvent event;
  final Future<void> Function(Uri) onOpenInfo;

  @override
  Widget build(BuildContext context) {
    final dateRange = _formatDateRange(event.startDate, event.endDate);
    final raceDay = event.raceDayDate;
    final infoUrl = event.infoUrl;
    return Card(
      color: _surface,
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.adUrl != null)
            Image.network(
              event.adUrl.toString(),
              width: double.infinity,
              fit: BoxFit.contain, // Keep the complete flyer and sponsor logos.
              errorBuilder: (context, error, stackTrace) => const Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.broken_image_outlined, color: Colors.white54),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Event advertisement unavailable',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 18,
                      color: _gold,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dateRange,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
                if (raceDay != null &&
                    !(_sameDay(raceDay, event.startDate) &&
                        _sameDay(raceDay, event.endDate))) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Race day: ${_formatDate(raceDay)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  event.status.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: _gold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                if (infoUrl != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => onOpenInfo(infoUrl),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('More Information'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime? a, DateTime? b) =>
      a != null &&
      b != null &&
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  static String _formatDateRange(DateTime? start, DateTime? end) {
    if (start == null) return 'Date to be announced';
    if (end == null || _sameDay(start, end)) return _formatDate(start);
    if (start.year == end.year && start.month == end.month) {
      return '${_month(start.month)} ${start.day}–${end.day}, ${start.year}';
    }
    return '${_formatDate(start)} – ${_formatDate(end)}';
  }

  static String _formatDate(DateTime date) =>
      '${_month(date.month)} ${date.day}, ${date.year}';

  static String _month(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}
