class FocusGuardSettings {
  final bool enabled;
  final Map<String, bool> blockedApps;
  final int tempAllowMinutes;
  final bool quickAllowEnabled;

  const FocusGuardSettings({
    this.enabled = false,
    this.blockedApps = const {'youtube': true},
    this.tempAllowMinutes = 10,
    this.quickAllowEnabled = false,
  });

  FocusGuardSettings copyWith({
    bool? enabled,
    Map<String, bool>? blockedApps,
    int? tempAllowMinutes,
    bool? quickAllowEnabled,
  }) {
    return FocusGuardSettings(
      enabled: enabled ?? this.enabled,
      blockedApps: blockedApps ?? this.blockedApps,
      tempAllowMinutes: tempAllowMinutes ?? this.tempAllowMinutes,
      quickAllowEnabled: quickAllowEnabled ?? this.quickAllowEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'blockedApps': blockedApps,
        'tempAllowMinutes': tempAllowMinutes,
        'quickAllowEnabled': quickAllowEnabled,
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
      quickAllowEnabled: json['quickAllowEnabled'] == true,
    );
  }
}
