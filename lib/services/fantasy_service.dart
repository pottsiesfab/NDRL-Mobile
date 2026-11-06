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

/// Sort season events newest first. Event ID breaks ties when dates are absent.
int fantasyEventId(Map<String, dynamic> event) =>
    int.tryParse('${event['fantasy_event_id']}') ?? 0;

List<Map<String, dynamic>> fantasyRosterEvents(dynamic raw) {
  if (raw is! List) return <Map<String, dynamic>>[];
  final events = raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
  String eventDate(Map<String, dynamic> e) =>
      '${e['event_date'] ?? e['date'] ?? e['lock_date'] ?? ''}';
  events.sort((a, b) {
    final da = eventDate(a);
    final db = eventDate(b);
    if (da.isNotEmpty && db.isNotEmpty) {
      final byDate = db.compareTo(da);
      if (byDate != 0) return byDate;
    }
    return fantasyEventId(b).compareTo(fantasyEventId(a));
  });
  return events;
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

  static const String mobileEndpoint =
      'https://dev.nostalgiadragleague.com/fantasy/api/mobile_fantasy_api.php';

  Future<Map<String, dynamic>> myRosters({
    required AuthService authService,
    required int fantasySeasonId,
  }) => authService.authorizedGet(
    Uri.parse(mobileEndpoint).replace(
      queryParameters: {
        'action': 'my_rosters',
        'fantasy_season_id': '$fantasySeasonId',
      },
    ),
  );

  Future<Map<String, dynamic>> rosterOptions({
    required AuthService authService,
    required int fantasySeasonId,
    required int fantasyEventId,
  }) => authService.authorizedGet(
    Uri.parse(mobileEndpoint).replace(
      queryParameters: {
        'action': 'roster_options',
        'fantasy_season_id': '$fantasySeasonId',
        'fantasy_event_id': '$fantasyEventId',
      },
    ),
  );

  Future<Map<String, dynamic>> rosterWrite({
    required AuthService authService,
    required int fantasySeasonId,
    required int fantasyEventId,
    required List<Map<String, dynamic>> picks,
    required bool save,
  }) => authService.authorizedPost(
    Uri.parse(mobileEndpoint).replace(
      queryParameters: {'action': save ? 'roster_save' : 'roster_validate'},
    ),
    {
      'fantasy_season_id': fantasySeasonId,
      'fantasy_event_id': fantasyEventId,
      'picks': picks,
    },
  );

  static const String standingsEndpoint =
      'https://dev.nostalgiadragleague.com/fantasy/api/standings_api.php';

  Future<Map<String, dynamic>> _standingsRequest(
    Map<String, String> params,
  ) async {
    final uri = Uri.parse(standingsEndpoint).replace(queryParameters: params);
    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw StateError(
        'Standings request failed (HTTP ${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['ok'] != true || decoded['data'] is! Map) {
      throw const FormatException('Unexpected Fantasy standings response.');
    }
    return Map<String, dynamic>.from(decoded['data'] as Map);
  }

  Future<Map<String, dynamic>> seasonStandings(int seasonId) =>
      _standingsRequest({
        'action': 'season.standings',
        'fantasy_season_id': '$seasonId',
      });

  Future<Map<String, dynamic>> eventStandings(int eventId) => _standingsRequest(
    {'action': 'event.meta', 'fantasy_event_id': '$eventId'},
  );

  Future<Map<String, dynamic>> rosterScoreDetails(int rosterId, int eventId) =>
      _standingsRequest({
        'action': 'roster.meta',
        'fantasy_roster_id': '$rosterId',
        'fantasy_event_id': '$eventId',
      });

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
