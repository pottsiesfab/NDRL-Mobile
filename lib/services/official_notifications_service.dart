import 'dart:math';

import '../config/app_config.dart';
import 'auth_service.dart';

/// DEV-only transport for the already deployed Race Control mobile APIs.
///
/// This layer intentionally returns the backend's JSON unchanged until the
/// exact response contracts are available. It does not infer authorization
/// from the client, and never sends push messages directly to Firebase.
class OfficialNotificationsService {
  OfficialNotificationsService(this.auth);

  final AuthService auth;

  void _requireDev() {
    if (!AppConfig.isDev) {
      throw const AuthException(
        'Race Control publishing is not enabled in production.',
      );
    }
  }

  Future<Map<String, dynamic>> targets({int seasonId = 3}) {
    _requireDev();
    return auth.authorizedGet(
      AppConfig.apiUri(
        '/mobile/api/mobile_official_targets_api.php',
        queryParameters: {'season_id': '$seasonId'},
      ),
    );
  }

  /// Preview only. Does not enqueue a notification.
  Future<Map<String, dynamic>> previewLaneCall(LaneCallDraft draft) {
    _requireDev();
    return auth.authorizedPost(
      AppConfig.apiUri(
        '/mobile/api/mobile_lanes_call_api.php',
        queryParameters: {'action': 'preview'},
      ),
      draft.toJson(),
    );
  }

  /// A send must only be called after an explicit user confirmation.
  ///
  /// The caller owns [idempotencyKey]. Keep the same key and the identical
  /// draft for retries after timeouts or uncertain network failures. Never
  /// automatically generate a new key when retrying a submission.
  Future<Map<String, dynamic>> sendLaneCall(
    LaneCallDraft draft, {
    required String idempotencyKey,
  }) {
    _requireDev();
    if (idempotencyKey.trim().isEmpty) {
      throw ArgumentError('An idempotency key is required');
    }
    return auth.authorizedPost(
      AppConfig.apiUri(
        '/mobile/api/mobile_lanes_call_api.php',
        queryParameters: {'action': 'send'},
      ),
      {...draft.toJson(), 'idempotency_key': idempotencyKey},
    );
  }

  /// Event announcements use the same authenticated DEV transport as lane calls.
  Future<Map<String, dynamic>> previewAnnouncement(AnnouncementDraft draft) {
    _requireDev();
    return auth.authorizedPost(
      AppConfig.apiUri(
        '/mobile/api/mobile_event_announcement_api.php',
        queryParameters: {'action': 'preview'},
      ),
      draft.toJson(),
    );
  }

  Future<Map<String, dynamic>> sendAnnouncement(
    AnnouncementDraft draft, {
    required String idempotencyKey,
  }) {
    _requireDev();
    if (idempotencyKey.trim().isEmpty) {
      throw ArgumentError('An idempotency key is required');
    }
    return auth.authorizedPost(
      AppConfig.apiUri(
        '/mobile/api/mobile_event_announcement_api.php',
        queryParameters: {'action': 'send'},
      ),
      {...draft.toJson(), 'idempotency_key': idempotencyKey},
    );
  }

  Future<Map<String, dynamic>> history({
    required int eventId,
    int? classId,
    int limit = 10,
    int? beforeId,
  }) {
    _requireDev();
    return auth.authorizedGet(
      AppConfig.apiUri(
        '/mobile/api/mobile_official_history_api.php',
        queryParameters: {
          'event_id': '$eventId',
          'limit': '$limit',
          if (classId != null) 'class_id': '$classId',
          if (beforeId != null) 'before_id': '$beforeId',
        },
      ),
    );
  }

  /// Generate once when a user confirms a reviewed submission.
  /// This uses a cryptographically secure RNG rather than a timestamp.
  static String newSubmissionKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}

/// Immutable draft so preview and confirmed submission share the same data.
class LaneCallDraft {
  LaneCallDraft({
    required this.eventId,
    required List<int> classIds,
    required this.callType,
    this.roundLabel,
    this.message,
  }) : classIds = List<int>.unmodifiable(classIds);

  final int eventId;
  final List<int> classIds;
  final String callType;
  final String? roundLabel;
  final String? message;

  Map<String, dynamic> toJson() => {
    'event_id': eventId,
    'class_ids': classIds,
    'call_type': callType,
    if (roundLabel != null) 'round_label': roundLabel,
    if (message != null) 'message': message,
  };
}

/// Immutable, validated-by-server announcement snapshot for preview/send.
class AnnouncementDraft {
  AnnouncementDraft({
    required this.eventId,
    required this.audience,
    required List<int> classIds,
    required this.title,
    required this.body,
  }) : classIds = List<int>.unmodifiable([...classIds]..sort());

  final int eventId;
  final String audience;
  final List<int> classIds;
  final String title;
  final String body;

  Map<String, dynamic> toJson() => {
    'event_id': eventId,
    'audience': audience,
    'class_ids': classIds,
    'title': title,
    'body': body,
  };
}
