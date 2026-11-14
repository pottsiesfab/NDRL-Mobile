class OfficialAccess {
  const OfficialAccess({required this.enabled, required this.roles,
    required this.permissions, required this.allClasses,
    required this.classIds, required this.eventIds});

  final bool enabled;
  final List<String> roles;
  final List<String> permissions;
  final bool allClasses;
  final List<int> classIds;
  final List<int> eventIds;

  static const none = OfficialAccess(enabled: false, roles: [],
    permissions: [], allClasses: false, classIds: [], eventIds: []);

  factory OfficialAccess.fromJson(Map<String, dynamic> json) {
    List<String> strings(dynamic input) => input is List
        ? input.whereType<String>().toList(growable: false) : <String>[];
    List<int> integers(dynamic input) => input is List
        ? input.whereType<int>().toList(growable: false) : <int>[];
    return OfficialAccess(
      enabled: json['enabled'] == true,
      roles: strings(json['roles']),
      permissions: strings(json['permissions']),
      allClasses: json['all_classes'] == true,
      classIds: integers(json['class_ids']),
      eventIds: integers(json['event_ids']),
    );
  }

  bool get canCallLanes => enabled && permissions.contains('lanes.call');
  bool get canAnnounceEvent => enabled && permissions.contains('events.announce');
  bool get canViewHistory => enabled && permissions.contains('notifications.history.read');
}
