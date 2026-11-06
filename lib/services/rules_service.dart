import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class NdrlRulesService {
  static Future<Map<String, dynamic>> load() async {
    final uri = Uri.parse('${AppConfig.baseUrl}/mobile/api/rules_api.php');
    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Rules API returned HTTP ${response.statusCode}');
    }
    final payload = jsonDecode(response.body);
    if (payload is! Map<String, dynamic> ||
        payload['success'] != true ||
        payload['rulebook'] is! Map<String, dynamic>) {
      throw const FormatException('Invalid rules API response');
    }
    return payload;
  }
}
