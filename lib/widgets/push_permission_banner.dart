import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../services/device_service.dart';

const _gold = Color(0xFFD1AC67);
const _red = Color(0xFFB91C1C);

class PushPermissionBanner extends StatelessWidget {
  const PushPermissionBanner({
    super.key,
    required this.deviceService,
    this.compact = false,
  });

  final DeviceService deviceService;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: deviceService,
      builder: (context, _) {
        // Hide automatically once permission is granted or provisional,
        // or before the initial permission check has completed.
        if (!deviceService.permissionChecked ||
            deviceService.notificationsPermitted) {
          return const SizedBox.shrink();
        }

        final isDenied =
            deviceService.authorizationStatus == AuthorizationStatus.denied;

        if (compact) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2B1717),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _red.withValues(alpha: 0.85)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.notifications_off_outlined,
                  color: _gold,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Push Notifications Are Off',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Turn on alerts for staging calls and race updates.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: deviceService.isBusy
                      ? null
                      : () => deviceService.enableNotifications(),
                  child: Text(
                    isDenied ? 'Settings' : 'Enable',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Full banner for Notification Settings screen
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2B1717),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _red),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    color: _gold,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Device Push Notifications Disabled',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isDenied
                    ? 'Push notifications are blocked in your device settings. '
                          'You can save your alert preferences below, but this device '
                          'will not receive staging calls or race alerts until you '
                          'allow notifications in system settings.'
                    : 'Push notifications have not been enabled on this device yet. '
                          'Enable permissions to receive live staging calls and race alerts.',
                style: const TextStyle(color: Colors.white70, height: 1.35),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: deviceService.isBusy
                      ? null
                      : () => deviceService.enableNotifications(),
                  icon: Icon(
                    isDenied
                        ? Icons.settings_outlined
                        : Icons.notifications_active_outlined,
                    size: 18,
                  ),
                  label: Text(
                    isDenied
                        ? 'Open Device Notification Settings'
                        : 'Allow Push Notifications',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
