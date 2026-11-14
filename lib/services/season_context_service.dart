import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Reads the authoritative Portal season context.
///
/// Portal season IDs must never be hardcoded in the mobile client. Fantasy
/// seasons are a separate identifier space and must continue using their
/// Fantasy APIs.
class SeasonContext {
  const SeasonContext({
    required this.seasonId,
    required this.seasonYear,
    required this.seasonName,
    required this.payload,
  });

  final int seasonId;
  final int seasonYear;
  final String seasonName;
  final Map<String, dynamic> payload;

  factory SeasonContext.fromJson(Map<String, dynamic> json) {
    if (json['success'] != true) {
      throw const FormatException('NDRL context request was unsuccessful');
    }

    final rawId = json['active_season_id'];
    final rawYear = json['active_season_year'];
    final active = json['active_season'];
    final id = rawId is num ? rawId.toInt() : int.tryParse('$rawId') ?? 0;
    final year = rawYear is num
        ? rawYear.toInt()
        : int.tryParse('$rawYear') ?? 0;

    if (id <= 0) {
      throw const FormatException('No active NDRL season is configured');
    }

    final season = active is Map
        ? Map<String, dynamic>.from(active)
        : const <String, dynamic>{};
    final name = season['name']?.toString().trim();

    return SeasonContext(
      seasonId: id,
      seasonYear: year,
      seasonName: name == null || name.isEmpty
          ? (year > 0 ? '$year Championship Season' : 'Active Season')
          : name,
      payload: Map<String, dynamic>.from(json),
    );
  }
}

/// Shared transport/parser for the Portal context endpoint.
class SeasonContextService {
  SeasonContextService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<SeasonContext> load() async {
    final response = await _client
        .get(
          AppConfig.apiUri('/api/ndrl_context_api.php'),
          headers: const {
            'Accept': 'application/json',
            'Cache-Control': 'no-cache',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw StateError(
        'NDRL context request failed (HTTP ${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid NDRL context response');
    }

    return SeasonContext.fromJson(decoded);
  }

  void dispose() => _client.close();
}
