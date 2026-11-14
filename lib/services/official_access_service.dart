import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'season_context_service.dart';
import '../models/official_access.dart';
import 'auth_service.dart';

/// Permission discovery is fail-closed: any error clears previously granted access.
class OfficialAccessService extends ChangeNotifier {
  OfficialAccessService(this.auth) {
    auth.addListener(_authChanged);
    _authChanged();
  }

  final AuthService auth;
  final SeasonContextService _seasonContext = SeasonContextService();
  int seasonId = 0;
  OfficialAccess access = OfficialAccess.none;
  bool loading = false;
  String? error;
  int _generation = 0;
  Object? _accountIdentity;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _authChanged() {
    // Object identity is used to detect account replacement; the API remains
    // authoritative even if the same member signs in again.
    final identity = auth.account;
    if (identical(identity, _accountIdentity)) return;
    _accountIdentity = identity;
    _generation++;
    access = OfficialAccess.none;
    error = null;
    loading = false;
    _notify();
    if (auth.signedIn) {
      // A rejected or unreachable discovery never grants access.
      refresh();
    }
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    access = OfficialAccess.none;
    error = null;
    if (!auth.signedIn) {
      loading = false;
      _notify();
      return;
    }
    loading = true;
    _notify();
    try {
      final seasonContext = await _seasonContext.load();
      if (generation != _generation || !auth.signedIn || _disposed) return;
      seasonId = seasonContext.seasonId;
      final response = await auth.authorizedGet(
        AppConfig.apiUri(
          '/mobile/api/mobile_official_access_api.php',
          queryParameters: {'season_id': '$seasonId'},
        ),
      );
      final raw = response['official_access'];
      if (raw is! Map<String, dynamic>) {
        throw const AuthException('Invalid official access response');
      }
      if (generation != _generation || !auth.signedIn || _disposed) return;
      access = OfficialAccess.fromJson(raw);
    } catch (_) {
      if (generation != _generation || _disposed) return;
      access = OfficialAccess.none;
      error = 'Unable to verify official access. Please retry.';
    } finally {
      if (generation == _generation && !_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    auth.removeListener(_authChanged);
    _seasonContext.dispose();
    super.dispose();
  }
}
