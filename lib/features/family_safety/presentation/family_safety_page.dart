import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import 'activity_summary_page.dart';
import 'digital_wellbeing_page.dart';
import 'parent_control_page.dart';
import 'privacy_explanation_page.dart';
import 'safe_search_setup_page.dart';
import 'website_protection_page.dart';
import 'widgets/family_safety_section_tile.dart';

class FamilySafetyPage extends StatelessWidget {
  const FamilySafetyPage({super.key});

  static const Color _brandGreen = Color(0xFF388E3C);

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.familySafetyTitle),
        centerTitle: true,
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            strings.familySafetyIntro,
            style: TextStyle(color: Colors.grey[700], height: 1.35),
          ),
          const SizedBox(height: 14),
          FamilySafetySectionTile(
            icon: Icons.dns_outlined,
            iconColor: const Color(0xFF2E7D32),
            title: strings.basicWebsiteProtectionTitle,
            subtitle: strings.basicWebsiteProtectionSubtitle,
            onTap: () => _open(context, const BasicWebsiteProtectionPage()),
          ),
          const SizedBox(height: 10),
          FamilySafetySectionTile(
            icon: Icons.self_improvement_outlined,
            iconColor: const Color(0xFF1565C0),
            title: strings.digitalWellbeingTitle,
            subtitle: strings.digitalWellbeingSubtitle,
            onTap: () => _open(context, const DigitalWellbeingPage()),
          ),
          const SizedBox(height: 10),
          FamilySafetySectionTile(
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFF00897B),
            title: strings.websiteProtectionTitle,
            subtitle: strings.websiteProtectionSubtitle,
            onTap: () => _open(context, const WebsiteProtectionPage()),
          ),
          const SizedBox(height: 10),
          FamilySafetySectionTile(
            icon: Icons.travel_explore_outlined,
            iconColor: const Color(0xFF00796B),
            title: strings.safeSearchSetupTitle,
            subtitle: strings.safeSearchSetupSubtitle,
            onTap: () => _open(context, const OtherSafetyGuidePage()),
          ),
          const SizedBox(height: 10),
          FamilySafetySectionTile(
            icon: Icons.lock_outline,
            iconColor: const Color(0xFF6A1B9A),
            title: strings.parentControlTitle,
            subtitle: strings.parentControlSubtitle,
            onTap: () => _open(context, const ParentControlPage()),
          ),
          const SizedBox(height: 10),
          FamilySafetySectionTile(
            icon: Icons.insights_outlined,
            iconColor: const Color(0xFFEF6C00),
            title: strings.activitySummaryTitle,
            subtitle: strings.activitySummarySubtitle,
            onTap: () => _open(context, const ActivitySummaryPage()),
          ),
          const SizedBox(height: 10),
          FamilySafetySectionTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: const Color(0xFF455A64),
            title: strings.privacyExplanationTitle,
            subtitle: strings.privacyExplanationSubtitle,
            onTap: () => _open(context, const PrivacyExplanationPage()),
          ),
        ],
      ),
    );
  }
}
