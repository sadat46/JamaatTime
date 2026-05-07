class FocusGuardSettings {
  static const int defaultTempAllowMinutes = 10;
  static const Set<int> tempAllowMinuteOptions = {5, 10, 15};

  final bool enabled;
  final Map<String, bool> blockedApps;
  final int tempAllowMinutes;
  final bool quickAllowEnabled;

  const FocusGuardSettings({
    this.enabled = false,
    this.blockedApps = const {'youtube': true},
    this.tempAllowMinutes = defaultTempAllowMinutes,
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
      tempAllowMinutes: sanitizeTempAllowMinutes(
        tempAllowMinutes ?? this.tempAllowMinutes,
      ),
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
    final apps =
        (json['blockedApps'] as Map?)?.map(
          (k, v) => MapEntry(k.toString(), v == true),
        ) ??
        const {'youtube': true};
    return FocusGuardSettings(
      enabled: json['enabled'] == true,
      blockedApps: Map<String, bool>.from(apps),
      tempAllowMinutes: sanitizeTempAllowMinutes(
        (json['tempAllowMinutes'] as num?)?.toInt() ?? defaultTempAllowMinutes,
      ),
      quickAllowEnabled: json['quickAllowEnabled'] == true,
    );
  }

  static int sanitizeTempAllowMinutes(int value) {
    return tempAllowMinuteOptions.contains(value)
        ? value
        : defaultTempAllowMinutes;
  }
}
