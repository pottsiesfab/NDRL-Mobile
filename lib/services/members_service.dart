import 'dart:convert';

import 'package:http/http.dart' as http;

class NdrlMembersService {
  static const endpoint =
      'https://dev.nostalgiadragleague.com/api/members_public_api.php';

  final http.Client _client = http.Client();

  void dispose() => _client.close();

  Future<Map<String, dynamic>> _request(
    String action,
    Map<String, String> params,
  ) async {
    final uri = Uri.parse(endpoint)
        .replace(queryParameters: {'action': action, ...params});
    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        response.statusCode != 200 ||
        decoded['ok'] != true ||
        decoded['data'] is! Map) {
      throw StateError(
        'Unable to load NDRL members (HTTP ${response.statusCode}).',
      );
    }
    return Map<String, dynamic>.from(decoded['data'] as Map);
  }

  static List<Map<String, dynamic>> items(Map<String, dynamic> payload) {
    final raw = payload['items'];
    if (raw is! List) throw const FormatException('Invalid members list');
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> seasons() async =>
      items(await _request('seasons.list', {}));

  Future<Map<String, dynamic>> search({
    required bool associates,
    required int seasonId,
    String query = '',
    int offset = 0,
    int limit = 20,
    int? classId,
  }) => _request(associates ? 'associates.search' : 'drivers.search', {
    'season_id': '$seasonId',
    'q': query,
    'offset': '$offset',
    'limit': '$limit',
    if (!associates && classId != null) 'class_id': '$classId',
  });

  Future<Map<String, dynamic>> driverStats({required int memberId}) async {
    final uri =
        Uri.parse(
          'https://dev.nostalgiadragleague.com/api/standings_public_api.php',
        ).replace(
          queryParameters: {
            'action': 'standings.member.stats',
            'member_id': '$memberId',
            'include_events': '0',
          },
        );
    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 20));
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        response.statusCode != 200 ||
        decoded['ok'] != true ||
        decoded['message'] is! Map) {
      throw StateError('Unable to load driver statistics.');
    }
    return Map<String, dynamic>.from(decoded['message'] as Map);
  }

  Future<Map<String, dynamic>> profile({
    required int memberId,
    required int seasonId,
  }) => _request('member.get', {
    'member_id': '$memberId',
    'season_id': '$seasonId',
  });
}
