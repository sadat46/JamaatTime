import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/screens/admin_tools_screen.dart';

Widget _buildSubject({
  bool isAdmin = false,
  bool isSuperAdmin = false,
  VoidCallback? onManageUsersTap,
  VoidCallback? onEditImportTap,
  VoidCallback? onBroadcastTap,
  VoidCallback? onAutoRulesTap,
  VoidCallback? onNotifHistoryTap,
}) {
  return MaterialApp(
    home: AdminToolsScreen(
      isAdmin: isAdmin,
      isSuperAdmin: isSuperAdmin,
      onManageUsersTap: onManageUsersTap,
      onEditImportTap: onEditImportTap,
      onBroadcastTap: onBroadcastTap,
      onAutoRulesTap: onAutoRulesTap,
      onNotifHistoryTap: onNotifHistoryTap,
    ),
  );
}

void main() {
  testWidgets('shows empty state when no admin role is available', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject());

    expect(find.byKey(adminToolsScreenKey), findsOneWidget);
    expect(find.byKey(adminToolsEmptyStateKey), findsOneWidget);
    expect(find.byKey(adminToolsUserManagementSectionKey), findsNothing);
    expect(find.byKey(adminToolsDataManagementSectionKey), findsNothing);
    expect(find.byKey(adminToolsNotificationSystemSectionKey), findsNothing);
  });

  testWidgets('shows only data management/import section for admin', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject(isAdmin: true));

    expect(find.byKey(adminToolsDataManagementSectionKey), findsOneWidget);
    expect(find.byKey(adminToolsDataManagementCardKey), findsOneWidget);
    expect(find.byKey(adminToolsActionEditImportKey), findsOneWidget);
    expect(find.byKey(adminToolsUserManagementSectionKey), findsNothing);
    expect(find.byKey(adminToolsNotificationSystemSectionKey), findsNothing);
    expect(find.byKey(adminToolsActionManageUsersKey), findsNothing);
    expect(find.byKey(adminToolsActionBroadcastKey), findsNothing);
    expect(find.byKey(adminToolsActionAutoRulesKey), findsNothing);
    expect(find.byKey(adminToolsActionNotifHistoryKey), findsNothing);
  });

  testWidgets('shows all premium admin tool sections for superadmin', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject(isAdmin: true, isSuperAdmin: true));

    expect(find.byKey(adminToolsUserManagementSectionKey), findsOneWidget);
    expect(find.byKey(adminToolsDataManagementSectionKey), findsOneWidget);
    expect(find.byKey(adminToolsNotificationSystemSectionKey), findsOneWidget);
    expect(find.byKey(adminToolsUserManagementCardKey), findsOneWidget);
    expect(find.byKey(adminToolsDataManagementCardKey), findsOneWidget);
    expect(find.byKey(adminToolsNotificationSystemCardKey), findsOneWidget);
    expect(find.byKey(adminToolsActionManageUsersKey), findsOneWidget);
    expect(find.byKey(adminToolsActionEditImportKey), findsOneWidget);
    expect(find.byKey(adminToolsActionBroadcastKey), findsOneWidget);
    expect(find.byKey(adminToolsActionAutoRulesKey), findsOneWidget);
    expect(find.byKey(adminToolsActionNotifHistoryKey), findsOneWidget);
  });

  testWidgets('groups notification tools in notification system section', (
    tester,
  ) async {
    await tester.pumpWidget(_buildSubject(isAdmin: true, isSuperAdmin: true));

    final notificationSection = find.byKey(
      adminToolsNotificationSystemSectionKey,
    );

    expect(
      find.descendant(
        of: notificationSection,
        matching: find.byKey(adminToolsActionBroadcastKey),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: notificationSection,
        matching: find.byKey(adminToolsActionAutoRulesKey),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: notificationSection,
        matching: find.byKey(adminToolsActionNotifHistoryKey),
      ),
      findsOneWidget,
    );
  });

  testWidgets('invokes visible admin tool callbacks on tap', (tester) async {
    final tapped = <String>[];

    await tester.pumpWidget(
      _buildSubject(
        isAdmin: true,
        isSuperAdmin: true,
        onManageUsersTap: () => tapped.add('users'),
        onEditImportTap: () => tapped.add('edit'),
        onBroadcastTap: () => tapped.add('broadcast'),
        onAutoRulesTap: () => tapped.add('rules'),
        onNotifHistoryTap: () => tapped.add('history'),
      ),
    );

    await tester.ensureVisible(find.byKey(adminToolsActionManageUsersKey));
    await tester.tap(find.byKey(adminToolsActionManageUsersKey));
    await tester.pump();

    await tester.ensureVisible(find.byKey(adminToolsActionEditImportKey));
    await tester.tap(find.byKey(adminToolsActionEditImportKey));
    await tester.pump();

    await tester.ensureVisible(find.byKey(adminToolsActionBroadcastKey));
    await tester.tap(find.byKey(adminToolsActionBroadcastKey));
    await tester.pump();

    await tester.ensureVisible(find.byKey(adminToolsActionAutoRulesKey));
    await tester.tap(find.byKey(adminToolsActionAutoRulesKey));
    await tester.pump();

    await tester.ensureVisible(find.byKey(adminToolsActionNotifHistoryKey));
    await tester.tap(find.byKey(adminToolsActionNotifHistoryKey));
    await tester.pump();

    expect(tapped, ['users', 'edit', 'broadcast', 'rules', 'history']);
  });
}
