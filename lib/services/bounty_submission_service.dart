
import 'package:image_picker/image_picker.dart';

import '../config/app_config.dart';
import 'auth_service.dart';

class EligibleBountyRacer {
  const EligibleBountyRacer(this.data);
  final Map<String, dynamic> data;
  int get registrationId => (data['member_season_class_id'] as num).toInt();
  String get name => data['name']?.toString() ?? 'Unknown racer';
  String get className => data['class_name']?.toString() ?? '';
  String get carNumber => data['car_number']?.toString() ?? '';
  String get carDescription => data['car_desc']?.toString() ?? '';
  String get searchText => '$name $className $carNumber $carDescription'.toLowerCase();
}

class BountySubmissionService {
  BountySubmissionService(this.auth);
  final AuthService auth;
  Uri _uri(String action, [Map<String, String>? extra]) => AppConfig.apiUri(
    '/api/bounty_api.php',
    queryParameters: {'action': action, ...?extra},
  );

  Future<List<EligibleBountyRacer>> eligibleRacers(int eventId) async {
    final result = await auth.authorizedGet(
      _uri('eligible_targets', {'event_id': '$eventId'}),
    );
    final racers = result['racers'];
    if (racers is! List) throw const AuthException('Invalid racer list');
    return racers.map((item) {
      if (item is! Map) throw const AuthException('Invalid racer record');
      return EligibleBountyRacer(Map<String, dynamic>.from(item));
    }).toList();
  }

  Future<int> submit({
    required int eventId,
    required int registrationId,
    required String title,
    required String description,
    required String amount,
  }) async {
    final result = await auth.authorizedPost(_uri('submit'), {
      'event_id': eventId,
      'target_member_season_class_id': registrationId,
      'title': title,
      'description': description,
      'reward_amount': amount,
    });
    final id = result['bounty_id'];
    if (id is! num || id.toInt() <= 0) {
      throw const AuthException('Server did not return a bounty ID');
    }
    return id.toInt();
  }

  Future<void> upload(int bountyId, String type, XFile file) async {
    if (type != 'target' && type != 'poster') {
      throw const AuthException('Invalid image type');
    }
    final result = await auth.authorizedMultipart(
      _uri('upload_image'),
      fields: {'bounty_id': '$bountyId', 'image_type': type},
      file: file,
    );
    if (result['image_url'] is! String) {
      throw const AuthException('Server did not confirm the image URL');
    }
  }
}
