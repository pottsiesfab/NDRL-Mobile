import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';

class AppUpdatePolicy {
  const AppUpdatePolicy({
    required this.status,
    required this.installedBuild,
    required this.latestBuild,
    required this.minimumBuild,
    required this.latestVersion,
    required this.message,
    required this.updateUrl,
    required this.channel,
    this.offline = false,
  });
  final String status;
  final int installedBuild, latestBuild, minimumBuild;
  final String latestVersion, message, updateUrl, channel;
  final bool offline;
  bool get mandatory => status == 'mandatory';
  bool get optional => status == 'optional';
  factory AppUpdatePolicy.fromJson(
    Map<String, dynamic> j,
    int installed,
    String channel,
  ) {
    final latest = (j['latest_build'] as num?)?.toInt() ?? 0;
    final minimum = (j['minimum_build'] as num?)?.toInt() ?? 0;
    final url = (j['update_url'] ?? '').toString();
    if (latest < minimum || minimum < 0 || latest < 0) {
      throw const FormatException('Invalid update policy');
    }
    return AppUpdatePolicy(
      status: installed < minimum
          ? 'mandatory'
          : installed < latest
          ? 'optional'
          : 'current',
      installedBuild: installed,
      latestBuild: latest,
      minimumBuild: minimum,
      latestVersion: (j['latest_version'] ?? '').toString(),
      message: (j['release_notes'] ?? '').toString(),
      updateUrl: url,
      channel: channel,
    );
  }
}

class AppUpdateService {
  static const _storage = FlutterSecureStorage();
  static const _channel = String.fromEnvironment(
    'APP_CHANNEL',
    defaultValue: 'website',
  );
  static String get channel {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'appstore';
    if (Platform.isAndroid) return _channel == 'play' ? 'play' : 'website';
    return 'desktop';
  }

  static Future<AppUpdatePolicy> check() async {
    final info = await PackageInfo.fromPlatform();
    final installed = int.tryParse(info.buildNumber) ?? 0;
    final key =
        'update_policy_${AppConfig.environment}_${Platform.operatingSystem}_$channel';
    final uri =
        Uri.parse('${AppConfig.baseUrl}/mobile/api/mobile_version_api.php')
            .replace(
              queryParameters: {
                'platform': Platform.isIOS ? 'ios' : 'android',
                'channel': channel,
              },
            );
    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        throw StateError('Update service HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map ||
          decoded['success'] != true ||
          decoded['policy'] is! Map) {
        throw const FormatException('Invalid update service response');
      }
      final policyJson = Map<String, dynamic>.from(decoded['policy'] as Map);
      final policy = AppUpdatePolicy.fromJson(policyJson, installed, channel);
      // Cache only validated server policy; never store tokens or credentials here.
      await _storage.write(
        key: key,
        value: jsonEncode({
          'at': DateTime.now().toUtc().toIso8601String(),
          'policy': policyJson,
        }),
      );
      return policy;
    } catch (_) {
      // A recent mandatory policy is enforced even if the network goes down.
      // Older policies expire after 24 hours to avoid indefinite offline lockout.
      try {
        final cached = await _storage.read(key: key);
        if (cached != null) {
          final data = jsonDecode(cached) as Map<String, dynamic>;
          final at = DateTime.parse(data['at'] as String).toUtc();
          if (DateTime.now().toUtc().difference(at).inHours < 24) {
            final p = AppUpdatePolicy.fromJson(
              Map<String, dynamic>.from(data['policy'] as Map),
              installed,
              channel,
            );
            return AppUpdatePolicy(
              status: p.status,
              installedBuild: installed,
              latestBuild: p.latestBuild,
              minimumBuild: p.minimumBuild,
              latestVersion: p.latestVersion,
              message: p.message,
              updateUrl: p.updateUrl,
              channel: channel,
              offline: true,
            );
          }
        }
      } catch (_) {
        /* No valid cached policy. */
      }
      // Explicit fail-open when there is no recent server policy.
      return AppUpdatePolicy(
        status: 'current',
        installedBuild: installed,
        latestBuild: installed,
        minimumBuild: 0,
        latestVersion: info.version,
        message: '',
        updateUrl: '',
        channel: channel,
        offline: true,
      );
    }
  }
}
