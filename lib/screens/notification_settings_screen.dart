import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _surface = Color(0xFF242428);
const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);
const _seasonId = 3; // DEV notification season only.
const _credentialKey = 'ndrl_dev_device_credential';
const _base = 'https://dev.nostalgiadragleague.com/api';

class NdrlNotificationSettingsScreen extends StatefulWidget {
  const NdrlNotificationSettingsScreen({super.key});

  @override
  State<NdrlNotificationSettingsScreen> createState() => _NdrlNotificationSettingsScreenState();
}

class _NdrlNotificationSettingsScreenState extends State<NdrlNotificationSettingsScreen> {
  final _storage = const FlutterSecureStorage();
  final _client = http.Client();
  bool _loading = true;
  String? _error;
  String? _seasonName;
  bool? _notificationsEnabled;
  List<_ClassSubscription> _classes = [];
  List<_EventSubscription> _events = [];
  Map<String, bool> _preferences = {};
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<Map<String, dynamic>> _request(
    String action, {
    Map<String, dynamic>? data,
  }) async {
    // DeviceService creates and stores this credential. Never create a second
    // device identity or display the credential in the UI.
    final credential = await _storage.read(key: _credentialKey);
    if (credential == null || credential.isEmpty) {
      throw StateError('Device registration is not ready. Try again shortly.');
    }
    final uri = Uri.parse('$_base/notify_subscriptions_api.php').replace(
      queryParameters: {
        'action': action,
        if (action == 'status') 'season_id': '$_seasonId',
      },
    );
    final headers = <String, String>{
      'Authorization': 'Bearer $credential',
      if (data != null) 'Content-Type': 'application/json',
    };
    final response = await (data == null
            ? _client.get(uri, headers: headers)
            : _client.post(uri, headers: headers, body: jsonEncode(data)))
        .timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unexpected server response');
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] != true) {
      // Do not expose response bodies, tokens, or credentials.
      final reason = decoded['error'];
      throw StateError(reason is String ? reason : 'Request failed');
    }
    return decoded;
  }

  Future<void> _load() async {
    if (_saving.isNotEmpty) return;
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await _request('status');
      final rawClasses = result['classes'];
      final rawEvents = result['events'];
      final rawPrefs = result['preferences'];
      if (rawClasses is! List || rawEvents is! List || rawPrefs is! Map) {
        throw const FormatException('Incomplete subscription response');
      }
      final classes = rawClasses.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid class');
        }
        return _ClassSubscription.fromJson(item);
      }).toList();
      final events = rawEvents.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid event');
        }
        return _EventSubscription.fromJson(item);
      }).toList();
      final season = result['season'];
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _events = events;
        _preferences = {
          'news': rawPrefs['news'] == true,
          'event_general': rawPrefs['event_general'] == true,
        };
        _notificationsEnabled = result['notifications_enabled'] == true;
        _seasonName = season is Map ? season['name']?.toString() : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    if (e is StateError) return e.message.toString();
    return 'Unable to contact NDRL DEV. Check your connection and try again.';
  }

  Future<void> _changeClass(_ClassSubscription item, bool enabled) async {
    final key = 'class:${item.id}';
    if (_saving.contains(key)) return;
    setState(() => _saving.add(key));
    try {
      await _request('class.set', data: {
        'class_id': item.id,
        'enabled': enabled,
        if (enabled) 'season_id': _seasonId,
      });
      if (!mounted) return;
      setState(() => item.subscribed = enabled);
    } catch (e) {
      _showError(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  Future<void> _changePreference(String type, bool enabled) async {
    final key = 'pref:$type';
    if (_saving.contains(key)) return;
    setState(() => _saving.add(key));
    try {
      await _request('preference.set', data: {'type': type, 'enabled': enabled});
      if (!mounted) return;
      setState(() => _preferences[type] = enabled);
    } catch (e) {
      _showError(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  Future<void> _changeEvent(_EventSubscription item, bool muted) async {
    final key = 'event:${item.id}';
    if (_saving.contains(key)) return;
    setState(() => _saving.add(key));
    try {
      await _request('event.mute', data: {'event_id': item.id, 'muted': muted});
      if (!mounted) return;
      setState(() => item.muted = muted);
    } catch (e) {
      _showError(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: _red,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            const Expanded(child: Text('NOTIFICATION SETTINGS', style: TextStyle(
              color: _gold, fontSize: 23, fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ))),
            IconButton(onPressed: _loading || _saving.isNotEmpty ? null : _load,
              tooltip: 'Refresh preferences', icon: const Icon(Icons.refresh)),
          ]),
          const Text('DEV TEST · NOT LIVE RACE NOTIFICATIONS',
              style: TextStyle(color: _gold, fontSize: 11)),
          const SizedBox(height: 16),
          Card(color: _surface, child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.notifications_active_outlined, color: _gold),
                SizedBox(width: 10), Text('Notification Preferences',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 8),
              const Text('Choose the racing classes and updates you want to receive.',
                style: TextStyle(color: Colors.white70)),
              if (_seasonName != null) ...[
                const SizedBox(height: 8),
                Text('Season: $_seasonName', style: const TextStyle(color: _gold)),
              ],
              if (_notificationsEnabled == false) ...[
                const SizedBox(height: 12),
                const Text('This device has notifications disabled on the server. '
                  'Your choices can be saved, but delivery may remain disabled.',
                  style: TextStyle(color: Colors.orangeAccent)),
              ],
            ]),
          )),
          if (_loading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(color: _red),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh), label: const Text('Try again')),
          ],
          if (_classes.isNotEmpty || _preferences.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionTitle('CLASS STAGING ALERTS'),
            const SizedBox(height: 8),
            for (final item in _classes)
              Card(color: _surface, margin: const EdgeInsets.only(bottom: 8),
                child: SwitchListTile(
                  activeThumbColor: _gold,
                  title: Text(item.name),
                  subtitle: !item.available
                    ? const Text('Unavailable this season', style: TextStyle(color: Colors.white54))
                    : null,
                  value: item.subscribed,
                  onChanged: (_saving.contains('class:${item.id}') ||
                          (!item.available && !item.subscribed))
                      ? null : (value) => _changeClass(item, value),
                )),
            const SizedBox(height: 20),
            const _SectionTitle('GENERAL NOTIFICATIONS'),
            const SizedBox(height: 8),
            _preferenceTile('event_general', 'Event Announcements',
              'General race event updates'),
            _preferenceTile('news', 'NDRL News',
              'League news and announcements'),
          ],
          if (_events.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _SectionTitle('MUTE INDIVIDUAL EVENTS'),
            const SizedBox(height: 6),
            const Text('Muting an event suppresses its notifications for this device.',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            for (final item in _events)
              Card(color: _surface, margin: const EdgeInsets.only(bottom: 8),
                child: SwitchListTile(
                  activeThumbColor: _gold,
                  title: Text(item.name),
                  subtitle: Text(item.muted ? 'Muted' : 'Notifications allowed',
                    style: const TextStyle(color: Colors.white70)),
                  value: item.muted,
                  onChanged: _saving.contains('event:${item.id}')
                    ? null : (value) => _changeEvent(item, value),
                )),
          ],
          const SizedBox(height: 24),
          const _SectionTitle('FEATURED NDRL PARTNER'),
          const SizedBox(height: 8),
          Container(height: 110, alignment: Alignment.center,
            decoration: BoxDecoration(color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24)),
            child: const Text('Sponsor placement',
              style: TextStyle(color: Colors.white70))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _preferenceTile(String type, String title, String subtitle) {
    return Card(color: _surface, margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        activeThumbColor: _gold,
        title: Text(title),
        subtitle: Text(subtitle),
        value: _preferences[type] ?? false,
        onChanged: _saving.contains('pref:$type')
          ? null : (value) => _changePreference(type, value),
      ));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(
    color: _gold, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2));
}

class _ClassSubscription {
  _ClassSubscription({required this.id, required this.name,
    required this.available, required this.subscribed});
  final int id;
  final String name;
  final bool available;
  bool subscribed;
  factory _ClassSubscription.fromJson(Map<String, dynamic> json) {
    final id = json['class_id'];
    final name = json['name'];
    if (id is! num || name is! String) {
      throw const FormatException('Invalid class subscription data');
    }
    return _ClassSubscription(id: id.toInt(), name: name,
      available: json['available'] == true, subscribed: json['subscribed'] == true);
  }
}

class _EventSubscription {
  _EventSubscription({required this.id, required this.name, required this.muted});
  final int id;
  final String name;
  bool muted;
  factory _EventSubscription.fromJson(Map<String, dynamic> json) {
    final id = json['event_id'];
    final name = json['name'];
    if (id is! num || name is! String) {
      throw const FormatException('Invalid event subscription data');
    }
    return _EventSubscription(id: id.toInt(), name: name, muted: json['muted'] == true);
  }
}
