import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class NdrlNewsService {
  static Future<Map<String, dynamic>> list({int? year}) async {
    final uri = Uri.parse('${AppConfig.baseUrl}/mobile/api/news_api.php')
        .replace(queryParameters: year == null ? null : {'year': '$year'});
    final response = await http
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('News API returned HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic> ||
        data['success'] != true ||
        data['years'] is! List ||
        data['articles'] is! List) {
      throw const FormatException('Invalid news response');
    }
    return data;
  }

  static Uri articleUrl(String slug) =>
      Uri.parse('${AppConfig.baseUrl}/pages/press/view.php')
          .replace(queryParameters: {'slug': slug});
}
