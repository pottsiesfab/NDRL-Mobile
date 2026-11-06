import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class FantasySeason {
  const FantasySeason({
    required this.id,
    required this.year,
    required this.name,
    required this.status,
  });
  final int id;
  final int year;
  final String name;
  final String status;

  factory FantasySeason.fromJson(Map<String, dynamic> json) => FantasySeason(
    id: int.tryParse('${json['fantasy_season_id']}') ?? 0,
    year: int.tryParse('${json['year']}') ?? 0,
    name: '${json['name'] ?? json['season_name'] ?? 'Fantasy Season'}',
    status: '${json['status'] ?? ''}',
  );
}

class NdrlFantasyService {
  // DEV only. Switch to production after testing and approval.
  static const String seasonsEndpoint =
      'https://dev.nostalgiadragleague.com/fantasy/api/seasons_api.php';
  final http.Client _client = http.Client();
  void dispose() => _client.close();

  Future<Map<String, dynamic>> myStats({
    required AuthService authService,
    required int fantasySeasonId,
  }) async {
    final uri =
        Uri.parse(
          'https://dev.nostalgiadragleague.com/fantasy/api/mobile_fantasy_api.php',
        ).replace(
          queryParameters: {
            'action': 'my_stats',
            'fantasy_season_id': '$fantasySeasonId',
          },
        );
    return authService.authorizedGet(uri);
  }

  static const String driversEndpoint =
      'https://dev.nostalgiadragleague.com/fantasy/api/drivers_api.php';

  Future<Map<String, dynamic>> _driversRequest(
    Map<String, String> params,
  ) async {
    final uri = Uri.parse(driversEndpoint).replace(queryParameters: params);
    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw StateError('Driver request failed (HTTP ${response.statusCode}).');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['ok'] != true || decoded['data'] is! Map) {
      throw const FormatException('Unexpected Fantasy drivers response.');
    }
    return Map<String, dynamic>.from(decoded['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> driverPrices(int seasonId) async {
    final result = <Map<String, dynamic>>[];
    const pageSize = 250;
    for (var offset = 0; ; offset += pageSize) {
      final data = await _driversRequest({
        'action': 'drivers.list',
        'fantasy_season_id': '$seasonId',
        'limit': '$pageSize',
        'offset': '$offset',
      });
      final page = (data['items'] as List? ?? const [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      result.addAll(page);
      if (page.length < pageSize) break;
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> driverStats(
    int seasonId,
    int classId, {
    bool includeEvents = false,
  }) async {
    final data = await _driversRequest({
      'action': 'drivers.stats',
      'fantasy_season_id': '$seasonId',
      'portal_class_id': '$classId',
      'include_events': includeEvents ? '1' : '0',
    });
    return (data['items'] as List? ?? const [])
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
  }

  Future<List<FantasySeason>> seasons() async {
    final uri = Uri.parse(seasonsEndpoint)
        .replace(queryParameters: {'action': 'list'});
    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError(
        'Fantasy seasons request failed (HTTP ${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['ok'] != true || decoded['data'] is! Map) {
      throw const FormatException('Unexpected Fantasy seasons response.');
    }
    final raw = (decoded['data'] as Map)['seasons'];
    if (raw is! List)
      throw const FormatException('Fantasy seasons list missing.');
    final seasons = raw
        .map(
          (item) =>
              FantasySeason.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .where((season) => season.id > 0)
        .toList();
    seasons.sort((a, b) {
      final byYear = b.year.compareTo(a.year);
      return byYear != 0 ? byYear : b.id.compareTo(a.id);
    });
    return seasons;
  }
}
