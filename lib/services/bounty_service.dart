import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class BountyEvent {
  const BountyEvent({required this.id, required this.name});
  final int id;
  final String name;
}

class BountyRecord {
  const BountyRecord({required this.data});
  final Map<String, dynamic> data;
  String get title => _text(data['title'], 'Untitled bounty');
  String get description => _text(data['description'], '');
  String get status => _text(data['claim_status'], 'unclaimed').toLowerCase();
  bool get isClaimed => status == 'claimed';
  String get targetName => _text(target['name'], 'Unknown racer');
  String get className => _text(target['class_name'], 'Class unavailable');
  String get carNumber => _text(target['car_number'], '');
  String get carDescription => _text(target['car_desc'], '');
  String get claimedBy => _text(data['claimed_by_name'], 'Not specified');
  String get round => _text(data['elimination_round'], 'Not specified');
  String get paymentStatus => _text(data['payment_status'], 'Not specified');
  Map<String, dynamic> get target => data['target'] is Map
      ? Map<String, dynamic>.from(data['target'] as Map)
      : const {};
  String get amount {
    final raw = data['reward_amount'];
    final value = double.tryParse(raw?.toString() ?? '');
    final currency = _text(data['reward_currency'], 'USD');
    return value == null
        ? 'Amount unavailable'
        : currency == 'USD'
        ? '\$${value.toStringAsFixed(2)}'
        : '${value.toStringAsFixed(2)} $currency';
  }

  Uri? get poster => resolveImage(data['bounty_poster_url']);
  Uri? get targetPhoto =>
      resolveImage(data['bounty_target_url']) ??
      resolveImage(target['car_image_url']);
  Uri? get claimPhoto => resolveImage(data['bounty_claimed_url']);
  Uri? get artwork => poster ?? targetPhoto;

  static String _text(Object? value, String fallback) =>
      value == null || value.toString().trim().isEmpty
      ? fallback
      : value.toString().trim();

  static Uri? resolveImage(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    final parsed = Uri.tryParse(raw.trim());
    if (parsed == null) return null;
    final resolved = Uri.parse(AppConfig.baseUrl).resolveUri(parsed);
    // Never fetch images from an insecure or unexpected host.
    if (resolved.scheme != 'https') return null;
    return resolved;
  }
}

class BountyBoardData {
  const BountyBoardData({required this.event, required this.bounties});
  final BountyEvent event;
  final List<BountyRecord> bounties;
}

class BountyService {
  BountyService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  void dispose() => _client.close();

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Server returned HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
      throw const FormatException('Unexpected API response');
    }
    return decoded;
  }

  Future<BountyBoardData?> load() async {
    final context = await _get(AppConfig.apiUri('/api/ndrl_context_api.php'));
    final rawEvent =
        context['current_event'] ??
        context['live_event'] ??
        context['next_event'];
    if (rawEvent is! Map) return null;
    final event = Map<String, dynamic>.from(rawEvent);
    final id = int.tryParse('${event['event_id'] ?? ''}');
    if (id == null || id <= 0) {
      throw const FormatException('Invalid current event');
    }
    final name = event['name']?.toString() ?? 'NDRL Event';
    final result = await _get(
      AppConfig.apiUri(
        '/api/bounty_api.php',
        queryParameters: {'action': 'list', 'event_id': '$id'},
      ),
    );
    final rawBounties = result['bounties'];
    if (rawBounties is! List) {
      throw const FormatException('Bounty list is missing or invalid');
    }
    return BountyBoardData(
      event: BountyEvent(id: id, name: name),
      bounties: rawBounties.map((item) {
        if (item is! Map) throw const FormatException('Invalid bounty record');
        return BountyRecord(data: Map<String, dynamic>.from(item));
      }).toList(),
    );
  }
}
