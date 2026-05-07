import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jamaat_time/widgets/profile/profile_logged_in_content.dart';

Widget _buildSubject({
  bool isAdmin = false,
  bool isSuperAdmin = false,
  VoidCallback? onLogout,
  VoidCallback? onSettingsTap,
  VoidCallback? onAdminToolsTap,
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
        onSettingsTap: onSettingsTap ?? () {},
        onAdminToolsTap: onAdminToolsTap ?? () {},
        appInfoCard: const SizedBox(
          key: ValueKey<String>('profile-app-info-card'),
          height: 80,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('keeps settings in main options after account section', (
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
    final settingsTileDy = tester
        .getTopLeft(find.byKey(profileActionSettingsKey))
        .dy;

    expect(find.byKey(profileSettingsCardKey), findsOneWidget);
    expect(accountLabelDy, lessThan(mainOptionsLabelDy));
    expect(accountCardDy, lessThan(settingsTileDy));
    expect(find.byKey(profileSectionAdminToolsKey), findsNothing);
  });

  testWidgets(
    'shows admin tools entry between main options and app for admin',
    (tester) async {
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
      expect(find.byKey(profileActionAdminToolsKey), findsOneWidget);
    },
  );

  testWidgets('invokes admin tools callback on tap', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      _buildSubject(
        isAdmin: true,
        onAdminToolsTap: () {
          tapCount++;
        },
      ),
    );

    await tester.ensureVisible(find.byKey(profileActionAdminToolsKey));
    await tester.tap(find.byKey(profileActionAdminToolsKey));
    await tester.pump();

    expect(tapCount, 1);
  });

  testWidgets('invokes settings callback on tap', (tester) async {
    var settingsTapCount = 0;

    await tester.pumpWidget(
      _buildSubject(
        onSettingsTap: () {
          settingsTapCount++;
        },
      ),
    );

    await tester.tap(find.byKey(profileActionSettingsKey));
    await tester.pump();

    expect(settingsTapCount, 1);
  });
}
