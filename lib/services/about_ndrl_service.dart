import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class AboutNdrlService {
  static Future<Map<String, dynamic>> fetch() async {
    final uri = Uri.parse('${AppConfig.baseUrl}/mobile/api/about_api.php');
    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception(
        'About NDRL service returned HTTP ${response.statusCode}',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
      throw const FormatException('Invalid About NDRL response');
    }
    if (decoded['sections'] is! List || decoded['contacts'] is! List) {
      throw const FormatException('Missing About NDRL content');
    }
    return decoded;
  }
}
