import '../config/app_config.dart';
import 'auth_service.dart';

class TechCardRecord {
  const TechCardRecord(this.data);
  final Map<String, dynamic> data;

  int get vehicleId =>
      int.tryParse('${data['member_season_class_id'] ?? ''}') ?? 0;
  int? get cardId => int.tryParse('${data['tech_card_id'] ?? ''}');
  String get className => _label(data['class_name'], 'Unknown class');
  String get seasonName => _label(data['season_name'], 'Unknown season');
  String get carNumber => _label(data['car_number'], '');
  String get status =>
      _label(data['tech_status'] ?? data['status'], 'Not started');
  bool get hasCard => cardId != null && cardId! > 0;
  bool get isLocked =>
      data['locked_at'] != null ||
      const ['approved', 'ready'].contains(status.toLowerCase());
  String get et => _label(data['et_index'], '');

  static String _label(Object? value, String fallback) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}

class TechCardsService {
  const TechCardsService(this.auth);
  final AuthService auth;

  Uri _uri(String action) => AppConfig.apiUri(
    '/mobile/api/mobile_tech_api.php',
    queryParameters: {'action': action},
  );

  Future<List<TechCardRecord>> _list(String action) async {
    final response = await auth.authorizedGet(_uri(action));
    final data = response['data'];
    if (data is! Map || data['rows'] is! List) {
      throw const FormatException('Unexpected Tech Cards response');
    }
    return (data['rows'] as List).map((row) {
      if (row is! Map) throw const FormatException('Invalid Tech Card record');
      return TechCardRecord(Map<String, dynamic>.from(row));
    }).toList();
  }

  Future<List<TechCardRecord>> vehicles() => _list('vehicles');
  Future<List<TechCardRecord>> mine() => _list('mine');
}
