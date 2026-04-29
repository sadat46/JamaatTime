import 'package:flutter/material.dart';

import '../core/locale_text.dart';
import 'admin_auto_rules_screen.dart';
import 'admin_jamaat_panel.dart';
import 'admin_notification_broadcast_screen.dart';
import 'admin_notification_history_screen.dart';
import 'user_management_screen.dart';

const adminToolsScreenKey = ValueKey<String>('admin-tools-screen');
const adminToolsEmptyStateKey = ValueKey<String>('admin-tools-empty-state');

const adminToolsUserManagementSectionKey = ValueKey<String>(
  'admin-tools-section-user-management',
);
const adminToolsDataManagementSectionKey = ValueKey<String>(
  'admin-tools-section-data-management',
);
const adminToolsNotificationSystemSectionKey = ValueKey<String>(
  'admin-tools-section-notification-system',
);

const adminToolsUserManagementCardKey = ValueKey<String>(
  'admin-tools-card-user-management',
);
const adminToolsDataManagementCardKey = ValueKey<String>(
  'admin-tools-card-data-management',
);
const adminToolsNotificationSystemCardKey = ValueKey<String>(
  'admin-tools-card-notification-system',
);

const adminToolsActionManageUsersKey = ValueKey<String>(
  'admin-tools-action-manage-users',
);
const adminToolsActionEditImportKey = ValueKey<String>(
  'admin-tools-action-edit-import',
);
const adminToolsActionBroadcastKey = ValueKey<String>(
  'admin-tools-action-broadcast',
);
const adminToolsActionAutoRulesKey = ValueKey<String>(
  'admin-tools-action-auto-rules',
);
const adminToolsActionNotifHistoryKey = ValueKey<String>(
  'admin-tools-action-notif-history',
);

class AdminToolsScreen extends StatelessWidget {
  const AdminToolsScreen({
    super.key,
    required this.isAdmin,
    required this.isSuperAdmin,
    this.onManageUsersTap,
    this.onEditImportTap,
    this.onBroadcastTap,
    this.onAutoRulesTap,
    this.onNotifHistoryTap,
    this.brandGreen = const Color(0xFF388E3C),
    this.cardRadius = 18,
  });

  final bool isAdmin;
  final bool isSuperAdmin;
  final VoidCallback? onManageUsersTap;
  final VoidCallback? onEditImportTap;
  final VoidCallback? onBroadcastTap;
  final VoidCallback? onAutoRulesTap;
  final VoidCallback? onNotifHistoryTap;
  final Color brandGreen;
  final double cardRadius;

  void _push(BuildContext context, Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => screen));
  }

  Widget _buildNoAccessState(BuildContext context) {
    return Center(
      key: adminToolsEmptyStateKey,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.tr(
            bn: 'এই অ্যাকাউন্টের জন্য কোনো অ্যাডমিন টুল নেই।',
            en: 'No admin tools are available for this account.',
          ),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[700]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAccessAnyTool = isAdmin || isSuperAdmin;

    return Scaffold(
      key: adminToolsScreenKey,
      appBar: AppBar(
        title: Text(context.tr(bn: 'অ্যাডমিন টুলস', en: 'Admin Tools')),
        centerTitle: true,
        backgroundColor: brandGreen,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: canAccessAnyTool
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isSuperAdmin) ...[
                    _AdminToolSection(
                      sectionKey: adminToolsUserManagementSectionKey,
                      cardKey: adminToolsUserManagementCardKey,
                      title: context.tr(
                        bn: 'ব্যবহারকারী ব্যবস্থাপনা',
                        en: 'User Management',
                      ),
                      icon: Icons.admin_panel_settings,
                      accentColor: Colors.red,
                      cardRadius: cardRadius,
                      children: [
                        _AdminToolTile(
                          tileKey: adminToolsActionManageUsersKey,
                          icon: Icons.manage_accounts,
                          iconColor: Colors.red,
                          title: context.tr(
                            bn: 'ব্যবহারকারী ব্যবস্থাপনা',
                            en: 'Manage Users',
                          ),
                          subtitle: context.tr(
                            bn: 'রোল, অনুমতি এবং অ্যাকাউন্ট অ্যাক্সেস',
                            en: 'Roles, permissions, and account access',
                          ),
                          onTap:
                              onManageUsersTap ??
                              () =>
                                  _push(context, const UserManagementScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (isAdmin) ...[
                    _AdminToolSection(
                      sectionKey: adminToolsDataManagementSectionKey,
                      cardKey: adminToolsDataManagementCardKey,
                      title: context.tr(
                        bn: 'ডেটা ম্যানেজমেন্ট / ইমপোর্ট',
                        en: 'Data Management / Import',
                      ),
                      icon: Icons.storage,
                      accentColor: Colors.orange,
                      cardRadius: cardRadius,
                      children: [
                        _AdminToolTile(
                          tileKey: adminToolsActionEditImportKey,
                          icon: Icons.file_upload,
                          iconColor: Colors.orange,
                          title: context.tr(
                            bn: 'ডেটা সম্পাদনা/ইমপোর্ট',
                            en: 'Edit/Import Data',
                          ),
                          subtitle: context.tr(
                            bn: 'সময়সূচি ইমপোর্ট ও বার্ষিক জামাত ডেটা ব্যবস্থাপনা',
                            en: 'Import schedules and manage yearly jamaat data',
                          ),
                          onTap:
                              onEditImportTap ??
                              () => _push(context, const AdminJamaatPanel()),
                        ),
                      ],
                    ),
                    if (isSuperAdmin) const SizedBox(height: 16),
                  ],
                  if (isSuperAdmin)
                    _AdminToolSection(
                      sectionKey: adminToolsNotificationSystemSectionKey,
                      cardKey: adminToolsNotificationSystemCardKey,
                      title: context.tr(
                        bn: 'নোটিফিকেশন সিস্টেম',
                        en: 'Notification System',
                      ),
                      icon: Icons.notifications_active,
                      accentColor: Colors.deepPurple,
                      cardRadius: cardRadius,
                      children: [
                        _AdminToolTile(
                          tileKey: adminToolsActionBroadcastKey,
                          icon: Icons.campaign,
                          iconColor: Colors.deepPurple,
                          title: context.tr(
                            bn: 'নোটিফিকেশন ব্রডকাস্ট',
                            en: 'Notification Broadcast',
                          ),
                          subtitle: context.tr(
                            bn: 'সব ব্যবহারকারীর কাছে টেক্সট বা ছবি পাঠান',
                            en: 'Push text or image to every user',
                          ),
                          onTap:
                              onBroadcastTap ??
                              () => _push(
                                context,
                                const AdminNotificationBroadcastScreen(),
                              ),
                        ),
                        _AdminToolTile(
                          tileKey: adminToolsActionAutoRulesKey,
                          icon: Icons.rule,
                          iconColor: Colors.teal,
                          title: context.tr(
                            bn: 'অটো-নোটিফিকেশন নিয়ম',
                            en: 'Auto Notification Rules',
                          ),
                          subtitle: context.tr(
                            bn: 'জামাতের সময় পরিবর্তনের অটো-অ্যালার্ট কনফিগার করুন',
                            en: 'Configure auto-alerts when jamaat times change',
                          ),
                          onTap:
                              onAutoRulesTap ??
                              () =>
                                  _push(context, const AdminAutoRulesScreen()),
                        ),
                        _AdminToolTile(
                          tileKey: adminToolsActionNotifHistoryKey,
                          icon: Icons.history,
                          iconColor: Colors.indigo,
                          title: context.tr(
                            bn: 'নোটিফিকেশন ইতিহাস',
                            en: 'Notification History',
                          ),
                          subtitle: context.tr(
                            bn: 'পাঠানো, ব্যর্থ ও শিডিউল করা ব্রডকাস্ট দেখুন',
                            en: 'View sent, failed, and scheduled broadcasts',
                          ),
                          onTap:
                              onNotifHistoryTap ??
                              () => _push(
                                context,
                                const AdminNotificationHistoryScreen(),
                              ),
                        ),
                      ],
                    ),
                ],
              ),
            )
          : _buildNoAccessState(context),
    );
  }
}

class _AdminToolSection extends StatelessWidget {
  const _AdminToolSection({
    required this.sectionKey,
    required this.cardKey,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.cardRadius,
    required this.children,
  });

  final Key sectionKey;
  final Key cardKey;
  final String title;
  final IconData icon;
  final Color accentColor;
  final double cardRadius;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: sectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
        ),
        Card(
          key: cardKey,
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius),
          ),
          child: Column(children: _withDividers(children)),
        ),
      ],
    );
  }

  List<Widget> _withDividers(List<Widget> tiles) {
    final items = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) {
        items.add(Divider(height: 1, color: Colors.grey[200]));
      }
      items.add(tiles[i]);
    }
    return items;
  }
}

class _AdminToolTile extends StatelessWidget {
  const _AdminToolTile({
    required this.tileKey,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key tileKey;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: tileKey,
      minLeadingWidth: 0,
      horizontalTitleGap: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(26),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
