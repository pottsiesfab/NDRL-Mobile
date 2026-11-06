import '../config/app_config.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'notification_settings_screen.dart';

const _surface = Color(0xFF242428);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);
const _api = '${AppConfig.baseUrl}/api/notify_history_api.php';
const _credentialKey = 'ndrl_dev_device_credential';

class NdrlAlertsScreen extends StatefulWidget {
  const NdrlAlertsScreen({super.key});

  @override
  State<NdrlAlertsScreen> createState() => _NdrlAlertsScreenState();
}

class _NdrlAlertsScreenState extends State<NdrlAlertsScreen> {
  final _storage = const FlutterSecureStorage();
  final _client = http.Client();
  final _items = <_HistoryItem>[];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  int? _nextCursor;
  String? _error;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _requestGeneration++;
    _client.close();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetch({int? beforeId}) async {
    final credential = await _storage.read(key: _credentialKey);
    if (credential == null || credential.isEmpty) {
      throw StateError('Device registration is not ready. Please try again.');
    }
    final uri = Uri.parse(_api).replace(
      queryParameters: {
        'limit': '20',
        if (beforeId != null) 'before_id': '$beforeId',
      },
    );
    final response = await _client
        .get(
          uri,
          headers: {
            'Authorization': 'Bearer $credential',
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected server response');
    }
    if (response.statusCode != 200 || decoded['success'] != true) {
      final reason = decoded['error'];
      throw StateError(reason is String ? reason : 'Unable to load alerts');
    }
    return decoded;
  }

  Future<void> _refresh() async {
    final generation = ++_requestGeneration;
    if (mounted)
      setState(() {
        _loading = true;
        _error = null;
      });
    try {
      final result = await _fetch();
      final parsed = _parsePage(result);
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _items
          ..clear()
          ..addAll(parsed.items);
        _hasMore = parsed.hasMore;
        _nextCursor = parsed.nextCursor;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(
        () => _error = 'Could not load notification history. Please retry.',
      );
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _nextCursor == null) return;
    final generation = _requestGeneration;
    final cursor = _nextCursor;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final parsed = _parsePage(await _fetch(beforeId: cursor));
      if (!mounted || generation != _requestGeneration) return;
      final seen = _items.map((e) => e.id).toSet();
      setState(() {
        _items.addAll(parsed.items.where((e) => seen.add(e.id)));
        _hasMore = parsed.hasMore;
        _nextCursor = parsed.nextCursor;
      });
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _error = 'Could not load older alerts. Please retry.');
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() => _loadingMore = false);
      }
    }
  }

  _HistoryPage _parsePage(Map<String, dynamic> result) {
    final raw = result['notifications'];
    final pagination = result['pagination'];
    if (raw is! List || pagination is! Map) {
      throw const FormatException('Incomplete notification history');
    }
    final items = raw.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid notification');
      }
      return _HistoryItem.fromJson(item);
    }).toList();
    final more = pagination['has_more'] == true;
    final cursor = pagination['next_cursor'];
    if (more && (cursor is! int || cursor < 1)) {
      throw const FormatException('Invalid pagination cursor');
    }
    return _HistoryPage(items, more, cursor is int ? cursor : null);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: const Color(0xFF111111),
          appBar: AppBar(
            backgroundColor: const Color(0xFF111111),
            title: const Text('Notification Settings'),
          ),
          body: const NdrlNotificationSettingsScreen(),
        ),
      ),
    );
    if (mounted) unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _red,
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'RECENT ALERTS',
                  style: TextStyle(
                    color: _gold,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Notification settings',
                icon: const Icon(Icons.settings_outlined),
                onPressed: _openSettings,
              ),
              IconButton(
                tooltip: 'Refresh alerts',
                icon: const Icon(Icons.refresh),
                onPressed: _loading ? null : _refresh,
              ),
            ],
          ),
          const Text(
            'DEV TEST · NOT LIVE RACE NOTIFICATIONS',
            style: TextStyle(color: _gold, fontSize: 11),
          ),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(color: _red),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loading ? null : _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
          if (!_loading && _items.isEmpty && _error == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64, horizontal: 16),
              child: Column(
                children: [
                  Icon(Icons.notifications_none, size: 58, color: _gold),
                  SizedBox(height: 16),
                  Text(
                    'No alerts yet',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Notifications accepted for this device will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          for (final item in _items) _AlertCard(item: item),
          if (_hasMore && !_loading) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadingMore ? null : _loadMore,
              icon: _loadingMore
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(_loadingMore ? 'Loading...' : 'Load older alerts'),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _HistoryPage {
  const _HistoryPage(this.items, this.hasMore, this.nextCursor);
  final List<_HistoryItem> items;
  final bool hasMore;
  final int? nextCursor;
}

class _HistoryItem {
  const _HistoryItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.className,
    this.eventName,
    this.roundLabel,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? className;
  final String? eventName;
  final String? roundLabel;

  factory _HistoryItem.fromJson(Map<String, dynamic> json) {
    final id = json['message_id'];
    final title = json['title'];
    final body = json['body'];
    final time = json['created_at'];
    if (id is! int || title is! String || body is! String || time is! String) {
      throw const FormatException('Invalid notification fields');
    }
    return _HistoryItem(
      id: id,
      type: json['message_type']?.toString() ?? 'notification',
      title: title,
      body: body,
      createdAt: DateTime.parse(time).toLocal(),
      className: json['class_name']?.toString(),
      eventName: json['event_name']?.toString(),
      roundLabel: json['round_label']?.toString(),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.item});
  final _HistoryItem item;

  @override
  Widget build(BuildContext context) {
    final date = item.createdAt;
    final dateText =
        '${date.month}/${date.day}/${date.year}  '
        '${_clock(date)}';
    final details = [
      item.className,
      item.roundLabel,
      item.eventName,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
    return Card(
      color: _surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  item.type == 'staging'
                      ? Icons.flag_outlined
                      : Icons.notifications_outlined,
                  size: 17,
                  color: _gold,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.type.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                Text(
                  dateText,
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              item.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (item.body.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.body, style: const TextStyle(color: Colors.white70)),
            ],
            if (details.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(
                details.join(' · '),
                style: const TextStyle(color: _gold, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _clock(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
  }
}
