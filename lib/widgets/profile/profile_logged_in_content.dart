import 'package:flutter/material.dart';
import '../../core/locale_text.dart';

const profileSectionAccountKey = ValueKey<String>(
  'profile-section-account-label',
);
const profileSectionMainOptionsKey = ValueKey<String>(
  'profile-section-main-options-label',
);
const profileSectionAdminToolsKey = ValueKey<String>(
  'profile-section-admin-tools-label',
);
const profileSectionAppKey = ValueKey<String>('profile-section-app-label');

const profileAccountCardKey = ValueKey<String>('profile-card-account');
const profileBookmarksCardKey = ValueKey<String>('profile-card-bookmarks');
const profileSettingsCardKey = ValueKey<String>('profile-card-settings');
const profileAdminToolsCardKey = ValueKey<String>('profile-card-admin-tools');

const profileActionBookmarksKey = ValueKey<String>(
  'profile-action-my-bookmarks',
);
const profileActionSettingsKey = ValueKey<String>('profile-action-settings');
const profileActionManageUsersKey = ValueKey<String>(
  'profile-action-manage-users',
);
const profileActionEditImportKey = ValueKey<String>(
  'profile-action-edit-import',
);

class ProfileLoggedInContent extends StatelessWidget {
  const ProfileLoggedInContent({
    super.key,
    required this.email,
    required this.roleLabel,
    required this.roleColor,
    required this.isAdmin,
    required this.isSuperAdmin,
    required this.onLogout,
    required this.onBookmarksTap,
    required this.onSettingsTap,
    required this.onManageUsersTap,
    required this.onEditImportTap,
    required this.appInfoCard,
    this.brandGreen = const Color(0xFF388E3C),
    this.cardRadius = 18,
  });

  final String email;
  final String roleLabel;
  final Color roleColor;
  final bool isAdmin;
  final bool isSuperAdmin;
  final VoidCallback onLogout;
  final VoidCallback onBookmarksTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onManageUsersTap;
  final VoidCallback onEditImportTap;
  final Widget appInfoCard;
  final Color brandGreen;
  final double cardRadius;

  Widget _buildSectionLabel(String text, Key key) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required Key tileKey,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
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

  List<Widget> _tilesWithDividers(List<Widget> tiles) {
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) {
        children.add(Divider(height: 1, color: Colors.grey[200]));
      }
      children.add(tiles[i]);
    }
    return children;
  }

  Widget _buildSingleActionCard({required Key cardKey, required Widget child}) {
    return Card(
      key: cardKey,
      elevation: 1.8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final showAdminTools = isAdmin || isSuperAdmin;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionLabel(
            context.tr(bn: 'অ্যাকাউন্ট', en: 'Account'),
            profileSectionAccountKey,
          ),
          Card(
            key: profileAccountCardKey,
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(cardRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: brandGreen.withAlpha(26),
                        child: Icon(Icons.person, color: brandGreen),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              email,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: roleColor.withAlpha(30),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                roleLabel,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: roleColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout),
                      label: Text(context.tr(bn: 'লগআউট', en: 'Logout')),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSectionLabel(
            context.tr(bn: 'প্রধান অপশন', en: 'Main Options'),
            profileSectionMainOptionsKey,
          ),
          _buildSingleActionCard(
            cardKey: profileBookmarksCardKey,
            child: _buildActionTile(
              tileKey: profileActionBookmarksKey,
              icon: Icons.bookmark,
              iconColor: brandGreen,
              title: context.tr(bn: 'আমার বুকমার্ক', en: 'My Bookmarks'),
              subtitle: context.tr(
                bn: 'দ্রুত পড়ার জন্য সংরক্ষিত আয়াত ও দোয়া',
                en: 'Saved ayat and dua for quick reading',
              ),
              onTap: onBookmarksTap,
            ),
          ),
          const SizedBox(height: 10),
          _buildSingleActionCard(
            cardKey: profileSettingsCardKey,
            child: _buildActionTile(
              tileKey: profileActionSettingsKey,
              icon: Icons.settings,
              iconColor: brandGreen,
              title: context.tr(bn: 'সেটিংস', en: 'Settings'),
              subtitle: context.tr(
                bn: 'নামাজ গণনা, হিজরি তারিখ এবং রিমাইন্ডার সাউন্ড',
                en: 'Prayer calculation, Hijri date, and reminder sound',
              ),
              onTap: onSettingsTap,
            ),
          ),
          if (showAdminTools) ...[
            const SizedBox(height: 16),
            _buildSectionLabel(
              context.tr(bn: 'অ্যাডমিন টুলস', en: 'Admin Tools'),
              profileSectionAdminToolsKey,
            ),
            Card(
              key: profileAdminToolsCardKey,
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(cardRadius),
              ),
              child: Column(
                children: _tilesWithDividers([
                  if (isSuperAdmin)
                    _buildActionTile(
                      tileKey: profileActionManageUsersKey,
                      icon: Icons.admin_panel_settings,
                      iconColor: Colors.red,
                      title: context.tr(bn: 'ব্যবহারকারী ব্যবস্থাপনা', en: 'Manage Users'),
                      subtitle: context.tr(
                        bn: 'রোল, অনুমতি এবং অ্যাকাউন্ট অ্যাক্সেস',
                        en: 'Roles, permissions, and account access',
                      ),
                      onTap: onManageUsersTap,
                    ),
                  if (isAdmin)
                    _buildActionTile(
                      tileKey: profileActionEditImportKey,
                      icon: Icons.file_upload,
                      iconColor: Colors.orange,
                      title: context.tr(bn: 'ডেটা সম্পাদনা/ইমপোর্ট', en: 'Edit/Import Data'),
                      subtitle: context.tr(
                        bn: 'সময়সূচি ইমপোর্ট ও বার্ষিক জামাত ডেটা ব্যবস্থাপনা',
                        en: 'Import schedules and manage yearly jamaat data',
                      ),
                      onTap: onEditImportTap,
                    ),
                ]),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildSectionLabel(context.tr(bn: 'অ্যাপ', en: 'App'), profileSectionAppKey),
          appInfoCard,
        ],
      ),
    );
  }
}
