class FocusGuardSettings {
  final bool enabled;
  final Map<String, bool> blockedApps;
  final int tempAllowMinutes;

  const FocusGuardSettings({
    this.enabled = false,
    this.blockedApps = const {'youtube': true},
    this.tempAllowMinutes = 10,
  });

  FocusGuardSettings copyWith({
    bool? enabled,
    Map<String, bool>? blockedApps,
    int? tempAllowMinutes,
  }) {
    return FocusGuardSettings(
      enabled: enabled ?? this.enabled,
      blockedApps: blockedApps ?? this.blockedApps,
      tempAllowMinutes: tempAllowMinutes ?? this.tempAllowMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'blockedApps': blockedApps,
        'tempAllowMinutes': tempAllowMinutes,
      };

  factory FocusGuardSettings.fromJson(Map<String, dynamic> json) {
    final apps = (json['blockedApps'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v == true),
        ) ??
        const {'youtube': true};
    return FocusGuardSettings(
      enabled: json['enabled'] == true,
      blockedApps: Map<String, bool>.from(apps),
      tempAllowMinutes: (json['tempAllowMinutes'] as num?)?.toInt() ?? 10,
    );
  }
}
