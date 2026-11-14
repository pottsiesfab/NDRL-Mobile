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

  Future<Map<String, dynamic>> card(int vehicleId) async {
    final response = await auth.authorizedGet(
      AppConfig.apiUri(
        '/mobile/api/mobile_tech_api.php',
        queryParameters: {
          'action': 'card',
          'member_season_class_id': '$vehicleId',
        },
      ),
    );
    final data = response['data'];
    if (data is! Map || data['tech_card'] is! Map) {
      throw const FormatException('Invalid Tech Card detail response');
    }
    return Map<String, dynamic>.from(data['tech_card'] as Map);
  }

  Future<List<TechModification>> cardModifications(int vehicleId) async {
    final response = await auth.authorizedGet(
      AppConfig.apiUri(
        '/mobile/api/mobile_tech_api.php',
        queryParameters: {
          'action': 'card_mods',
          'member_season_class_id': '$vehicleId',
        },
      ),
    );
    final data = response['data'];
    if (data is! Map || data['rows'] is! List) {
      throw const FormatException('Invalid modifications response');
    }
    return (data['rows'] as List).map((row) {
      if (row is! Map) throw const FormatException('Invalid modification row');
      final mod = TechModification(Map<String, dynamic>.from(row));
      if (mod.id <= 0 || !row.containsKey('member_answered')) {
        throw const FormatException('Modification ID or answer state missing');
      }
      return mod;
    }).toList();
  }

  Future<void> saveModificationDraft(
    int vehicleId,
    List<Map<String, dynamic>> answers,
  ) async {
    await auth.authorizedPost(_uri('save_mods'), {
      'member_season_class_id': vehicleId,
      'save_draft': true,
      'mod_answers': answers,
    });
  }

  Future<void> completeModifications(
    int vehicleId,
    List<int> selectedIds,
  ) async {
    await auth.authorizedPost(_uri('save_mods'), {
      'member_season_class_id': vehicleId,
      'save_draft': false,
      'selected_mod_ids': selectedIds,
    });
  }

  Future<Map<String, dynamic>> equipmentRequirements(int vehicleId) async {
    final response = await auth.authorizedGet(
      AppConfig.apiUri(
        '/mobile/api/mobile_tech_api.php',
        queryParameters: {
          'action': 'equipment_requirements',
          'member_season_class_id': '$vehicleId',
        },
      ),
    );
    final data = response['data'];
    if (data is! Map || data['items'] is! List) {
      throw const FormatException('Invalid equipment requirements response');
    }
    return Map<String, dynamic>.from(data);
  }

  Future<Map<int, Map<String, dynamic>>> cardEquipment(int vehicleId) async {
    final response = await auth.authorizedGet(
      AppConfig.apiUri(
        '/mobile/api/mobile_tech_api.php',
        queryParameters: {
          'action': 'card_equipment',
          'member_season_class_id': '$vehicleId',
        },
      ),
    );
    final data = response['data'];
    if (data is! Map || data['items_by_def_id'] is! Map) {
      throw const FormatException('Invalid saved equipment response');
    }
    final result = <int, Map<String, dynamic>>{};
    for (final entry in (data['items_by_def_id'] as Map).entries) {
      final id = int.tryParse('${entry.key}');
      if (id == null || entry.value is! Map) continue;
      result[id] = Map<String, dynamic>.from(entry.value as Map);
    }
    return result;
  }

  Future<void> saveEquipment(
    int vehicleId,
    int definitionId,
    Map<String, dynamic> fields,
  ) async {
    await auth.authorizedPost(_uri('save_equipment'), {
      'member_season_class_id': vehicleId,
      'tech_item_def_id': definitionId,
      ...fields,
    });
  }

  Future<void> acceptCard(int vehicleId) async {
    await auth.authorizedPost(_uri('accept_card'), {
      'member_season_class_id': vehicleId,
    });
  }

  Future<void> submitCard(int vehicleId) async {
    await auth.authorizedPost(_uri('submit_card'), {
      'member_season_class_id': vehicleId,
    });
  }

  Future<void> saveBasics(int vehicleId, Map<String, dynamic> basics) async {
    await auth.authorizedPost(_uri('save_basics'), {
      'member_season_class_id': vehicleId,
      ...basics,
    });
  }
}

class TechModification {
  const TechModification(this.data);
  final Map<String, dynamic> data;
  int get id => int.tryParse('${data['tech_mod_def_id'] ?? ''}') ?? 0;
  String get label => '${data['label'] ?? data['code'] ?? 'Modification'}';
  String get description => '${data['description'] ?? ''}'.trim();
  String get group => '${data['ui_group'] ?? ''}'.trim();
  String get mode => '${data['ui_mode'] ?? ''}'.trim().toLowerCase();
  bool get required => '${data['ui_required'] ?? 0}' == '1';
  bool get inspectorChecked => '${data['inspector_checked'] ?? 0}' == '1';
  bool? get answer {
    if ('${data['member_answered'] ?? 0}' != '1') return null;
    return '${data['member_checked'] ?? 0}' == '1';
  }
}
