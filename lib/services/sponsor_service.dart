import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;

import '../models/sponsor_ad.dart';
import '../models/sponsor.dart';

class SponsorService {
  SponsorService._();

  static const _baseUrl =
      'https://dev.nostalgiadragleague.com/api/sponsors_api.php';
  static const _cacheDuration = Duration(minutes: 2);
  static final Map<String, ({DateTime fetchedAt, SponsorAdBatch batch})>
  _cache = {};
  static final Map<String, Future<SponsorAdBatch>> _inFlight = {};

  static Future<SponsorAdBatch> getAds(
    String placement, {
    bool refresh = false,
  }) {
    if (!RegExp(r'^[a-z][a-z0-9_]{0,99}$').hasMatch(placement)) {
      return Future.error(const FormatException('Invalid placement'));
    }
    final cached = _cache[placement];
    if (!refresh &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheDuration) {
      return Future.value(cached.batch);
    }
    final pending = _inFlight[placement];
    if (pending != null) return pending;
    final request = _fetch(placement);
    _inFlight[placement] = request;
    return request.whenComplete(() => _inFlight.remove(placement));
  }

  static Future<SponsorAdBatch> _fetch(String placement) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'action': 'ads',
        'placement': placement,
        'platform': 'android',
      },
    );
    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Sponsor API HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true ||
        decoded['placement'] != placement ||
        decoded['ads'] is! List) {
      throw const FormatException('Invalid sponsor API response');
    }
    final rawSeconds = decoded['rotation_seconds'];
    final seconds = rawSeconds is int ? rawSeconds.clamp(5, 3600).toInt() : 15;
    final ads = <SponsorAd>[];
    for (final item in decoded['ads'] as List) {
      if (item is! Map<String, dynamic>) continue;
      try {
        ads.add(SponsorAd.fromJson(item));
      } on FormatException {
        // A malformed ad must not prevent other eligible ads from showing.
        continue;
      }
    }
    final batch = SponsorAdBatch(rotationSeconds: seconds, ads: ads);
    _cache[placement] = (fetchedAt: DateTime.now(), batch: batch);
    return batch;
  }

  /// Fetches the public sponsor directory from the DEV backend.
  static Future<List<NdrlSponsor>> getSponsors() async {
    final uri = Uri.parse(
      _baseUrl,
    ).replace(queryParameters: {'action': 'sponsors', 'platform': 'android'});
    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Sponsor directory HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true ||
        decoded['sponsors'] is! List) {
      throw const FormatException('Invalid sponsor directory response');
    }
    final sponsors = <NdrlSponsor>[];
    for (final item in decoded['sponsors'] as List) {
      if (item is! Map<String, dynamic>) continue;
      try {
        sponsors.add(NdrlSponsor.fromJson(item));
      } on FormatException {
        continue;
      }
    }
    return sponsors;
  }

  /// Sends one genuine ad display event. Never logs signed tokens.
  static Future<bool> recordImpression(String impressionToken) async {
    if (impressionToken.isEmpty) return false;
    final uri = Uri.parse(_baseUrl)
        .replace(queryParameters: {'action': 'impression'});
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'impression_token': impressionToken,
              'event_id': _newUuidV4(),
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint('Sponsor impression HTTP ${response.statusCode}');
        return false;
      }
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> &&
          decoded['success'] == true &&
          decoded['recorded'] == true;
    } catch (error) {
      debugPrint('Sponsor impression request failed: ${error.runtimeType}');
      return false;
    }
  }

  static String _newUuidV4() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
