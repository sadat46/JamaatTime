import 'block_category.dart';

class WebsiteProtectionSettings {
  const WebsiteProtectionSettings({
    this.enabled = false,
    this.blockedCategories = const <BlockCategory>{
      BlockCategory.adult,
      BlockCategory.gambling,
      BlockCategory.proxyBypass,
    },
  });

  final bool enabled;
  final Set<BlockCategory> blockedCategories;

  WebsiteProtectionSettings copyWith({
    bool? enabled,
    Set<BlockCategory>? blockedCategories,
  }) {
    return WebsiteProtectionSettings(
      enabled: enabled ?? this.enabled,
      blockedCategories: blockedCategories ?? this.blockedCategories,
    );
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'enabled': enabled,
      'blockedCategories': blockedCategories
          .map((category) => category.name)
          .toList(growable: false),
    };
  }

  factory WebsiteProtectionSettings.fromJson(Map<String, Object?> json) {
    final categories = json['blockedCategories'];
    return WebsiteProtectionSettings(
      enabled: json['enabled'] == true,
      blockedCategories: categories is List
          ? categories
                .whereType<String>()
                .map(
                  (name) => BlockCategory.values.firstWhere(
                    (category) => category.name == name,
                    orElse: () => BlockCategory.adult,
                  ),
                )
                .where((category) => category.isWebsiteProtectionCategory)
                .toSet()
          : const <BlockCategory>{
              BlockCategory.adult,
              BlockCategory.gambling,
              BlockCategory.proxyBypass,
            },
    );
  }
}
