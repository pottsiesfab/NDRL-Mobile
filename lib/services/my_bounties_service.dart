import '../config/app_config.dart';
import 'auth_service.dart';
import 'bounty_service.dart';

class MyBounty {
  const MyBounty(this.data);
  final Map<String, dynamic> data;

  int get id => int.tryParse('${data['bounty_id'] ?? ''}') ?? 0;
  int get eventId => int.tryParse('${data['event_id'] ?? ''}') ?? 0;
  int get registrationId =>
      int.tryParse('${data['target_member_season_class_id'] ?? ''}') ?? 0;
  String get rawAmount => '${data['reward_amount'] ?? ''}';
  String get title => _text(data['title'], 'Untitled bounty');
  String get description => _text(data['description'], '');
  String get eventName => _text(data['event_name'], 'NDRL Event');
  String get approvalStatus =>
      _text(data['approval_status'], 'unknown').toLowerCase();
  String get claimStatus =>
      _text(data['claim_status'], 'unknown').toLowerCase();
  bool get editable => data['editable'] == true;
  String get statusLabel {
    switch (approvalStatus) {
      case 'pending':
        return 'Awaiting Approval';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'withdrawn':
        return 'Withdrawn';
      default:
        return approvalStatus.toUpperCase();
    }
  }

  Map<String, dynamic> get target => data['target'] is Map
      ? Map<String, dynamic>.from(data['target'] as Map)
      : const {};
  String get racerName => _text(
    data['target_name'] ?? data['target_racer_name'] ?? target['name'],
    'Racer unavailable',
  );
  String get className => _text(data['class_name'] ?? target['class_name'], '');
  String get carNumber => _text(data['car_number'] ?? target['car_number'], '');
  String get amount {
    final number = double.tryParse('${data['reward_amount'] ?? ''}');
    return number == null
        ? 'Amount unavailable'
        : '\$${number.toStringAsFixed(2)}';
  }

  Uri? get image =>
      BountyRecord.resolveImage(data['bounty_poster_url']) ??
      BountyRecord.resolveImage(data['bounty_target_url']) ??
      BountyRecord.resolveImage(target['car_image_url']);
  Uri? get targetPhoto => BountyRecord.resolveImage(data['bounty_target_url']);
  Uri? get poster => BountyRecord.resolveImage(data['bounty_poster_url']);
  Uri? get claimedPhoto =>
      BountyRecord.resolveImage(data['bounty_claimed_url']);
  static String _text(Object? raw, String fallback) =>
      raw == null || raw.toString().trim().isEmpty
      ? fallback
      : raw.toString().trim();
}

class MyBountiesService {
  const MyBountiesService(this.auth);
  final AuthService auth;
  Uri _uri(String action, [Map<String, String>? params]) => AppConfig.apiUri(
    '/api/bounty_api.php',
    queryParameters: {'action': action, ...?params},
  );

  Future<List<MyBounty>> list() async {
    final result = await auth.authorizedGet(_uri('my_bounties'));
    final raw = result['bounties'];
    if (raw is! List) {
      throw const FormatException(
        'Invalid My Bounties response: missing bounties list',
      );
    }
    return raw.map((item) {
      if (item is! Map) throw const FormatException('Invalid bounty record');
      return MyBounty(Map<String, dynamic>.from(item));
    }).toList();
  }

  Future<void> update({
    required int bountyId,
    required int registrationId,
    required String title,
    required String description,
    required String amount,
  }) async {
    await auth.authorizedPost(_uri('update'), {
      'bounty_id': bountyId,
      'target_member_season_class_id': registrationId,
      'title': title,
      'description': description,
      'reward_amount': amount,
    });
  }

  Future<void> removeImage(int bountyId, String type) async {
    if (type != 'target' && type != 'poster') {
      throw const AuthException('Invalid image type');
    }
    await auth.authorizedPost(_uri('remove_image'), {
      'bounty_id': bountyId,
      'image_type': type,
    });
  }

  Future<MyBounty> detail(int bountyId) async {
    final result = await auth.authorizedGet(
      _uri('my_bounty', {'bounty_id': '$bountyId'}),
    );
    // Accept only the documented top-level bounty object; report schema differences.
    final raw = result['bounty'];
    if (raw is! Map) {
      throw const FormatException(
        'Unexpected my_bounty response: missing bounty object',
      );
    }
    return MyBounty(Map<String, dynamic>.from(raw));
  }
}
