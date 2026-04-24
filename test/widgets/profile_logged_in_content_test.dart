import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/widgets/profile/profile_logged_in_content.dart';

Widget _buildSubject({
  bool isAdmin = false,
  bool isSuperAdmin = false,
  VoidCallback? onLogout,
  VoidCallback? onBookmarksTap,
  VoidCallback? onSettingsTap,
  VoidCallback? onManageUsersTap,
  VoidCallback? onEditImportTap,
  VoidCallback? onBroadcastTap,
  VoidCallback? onAutoRulesTap,
  VoidCallback? onNotifHistoryTap,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ProfileLoggedInContent(
        email: 'test@example.com',
        roleLabel: 'User',
        roleColor: Colors.green,
        isAdmin: isAdmin,
        isSuperAdmin: isSuperAdmin,
        onLogout: onLogout ?? () {},
        onBookmarksTap: onBookmarksTap ?? () {},
        onSettingsTap: onSettingsTap ?? () {},
        onManageUsersTap: onManageUsersTap ?? () {},
        onEditImportTap: onEditImportTap ?? () {},
        onBroadcastTap: onBroadcastTap ?? () {},
        onAutoRulesTap: onAutoRulesTap ?? () {},
        onNotifHistoryTap: onNotifHistoryTap ?? () {},
        appInfoCard: const SizedBox(
          key: ValueKey<String>('profile-app-info-card'),
          height: 80,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('keeps bookmarks first in main options after account section', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject());

    final accountLabelDy = tester
        .getTopLeft(find.byKey(profileSectionAccountKey))
        .dy;
    final mainOptionsLabelDy = tester
        .getTopLeft(find.byKey(profileSectionMainOptionsKey))
        .dy;
    final accountCardDy = tester
        .getTopLeft(find.byKey(profileAccountCardKey))
        .dy;
    final bookmarksTileDy = tester
        .getTopLeft(find.byKey(profileActionBookmarksKey))
        .dy;
    final settingsTileDy = tester
        .getTopLeft(find.byKey(profileActionSettingsKey))
        .dy;

    expect(find.byKey(profileBookmarksCardKey), findsOneWidget);
    expect(find.byKey(profileSettingsCardKey), findsOneWidget);
    expect(accountLabelDy, lessThan(mainOptionsLabelDy));
    expect(accountCardDy, lessThan(bookmarksTileDy));
    expect(bookmarksTileDy, lessThan(settingsTileDy));
    expect(find.byKey(profileSectionAdminToolsKey), findsNothing);
  });

  testWidgets('shows admin tools between main options and app for admin', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject(isAdmin: true));

    final mainOptionsDy = tester
        .getTopLeft(find.byKey(profileSectionMainOptionsKey))
        .dy;
    final adminToolsDy = tester
        .getTopLeft(find.byKey(profileSectionAdminToolsKey))
        .dy;
    final appDy = tester.getTopLeft(find.byKey(profileSectionAppKey)).dy;

    expect(mainOptionsDy, lessThan(adminToolsDy));
    expect(adminToolsDy, lessThan(appDy));
    expect(find.byKey(profileActionEditImportKey), findsOneWidget);
    expect(find.byKey(profileActionManageUsersKey), findsNothing);
  });

  testWidgets('renders both admin actions for superadmin', (tester) async {
    await tester.pumpWidget(_buildSubject(isAdmin: true, isSuperAdmin: true));

    expect(find.byKey(profileActionManageUsersKey), findsOneWidget);
    expect(find.byKey(profileActionEditImportKey), findsOneWidget);
    expect(find.byKey(profileActionBroadcastKey), findsOneWidget);
    expect(find.byKey(profileActionAutoRulesKey), findsOneWidget);
    expect(find.byKey(profileActionNotifHistoryKey), findsOneWidget);
  });

  testWidgets('hides notification-history tile for non-superadmin admin',
      (tester) async {
    await tester.pumpWidget(_buildSubject(isAdmin: true));

    expect(find.byKey(profileActionNotifHistoryKey), findsNothing);
  });

  testWidgets('invokes notification-history callback on tap', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      _buildSubject(
        isSuperAdmin: true,
        onNotifHistoryTap: () {
          tapCount++;
        },
      ),
    );

    await tester.ensureVisible(find.byKey(profileActionNotifHistoryKey));
    await tester.tap(find.byKey(profileActionNotifHistoryKey));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets('hides broadcast tile for non-superadmin admin', (tester) async {
    await tester.pumpWidget(_buildSubject(isAdmin: true));

    expect(find.byKey(profileActionEditImportKey), findsOneWidget);
    expect(find.byKey(profileActionBroadcastKey), findsNothing);
    expect(find.byKey(profileActionAutoRulesKey), findsNothing);
  });

  testWidgets('invokes auto-rules callback on tap', (tester) async {
    var autoRulesTapCount = 0;

    await tester.pumpWidget(
      _buildSubject(
        isSuperAdmin: true,
        onAutoRulesTap: () {
          autoRulesTapCount++;
        },
      ),
    );

    await tester.ensureVisible(find.byKey(profileActionAutoRulesKey));
    await tester.tap(find.byKey(profileActionAutoRulesKey));
    await tester.pump();

    expect(autoRulesTapCount, 1);
  });

  testWidgets('invokes broadcast callback on tap', (tester) async {
    var broadcastTapCount = 0;

    await tester.pumpWidget(
      _buildSubject(
        isSuperAdmin: true,
        onBroadcastTap: () {
          broadcastTapCount++;
        },
      ),
    );

    await tester.ensureVisible(find.byKey(profileActionBroadcastKey));
    await tester.tap(find.byKey(profileActionBroadcastKey));
    await tester.pump();

    expect(broadcastTapCount, 1);
  });

  testWidgets('invokes main option callbacks on tap', (tester) async {
    var bookmarkTapCount = 0;
    var settingsTapCount = 0;

    await tester.pumpWidget(
      _buildSubject(
        onBookmarksTap: () {
          bookmarkTapCount++;
        },
        onSettingsTap: () {
          settingsTapCount++;
        },
      ),
    );

    await tester.tap(find.byKey(profileActionBookmarksKey));
    await tester.pump();
    await tester.tap(find.byKey(profileActionSettingsKey));
    await tester.pump();

    expect(bookmarkTapCount, 1);
    expect(settingsTapCount, 1);
  });
}
