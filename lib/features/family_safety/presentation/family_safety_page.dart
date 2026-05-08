import 'package:flutter/material.dart';

import '../../../core/feature_flags.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/focus_guard_service.dart';
import '../data/parent_control_storage.dart';
import '../platform/family_safety_channel.dart';
import 'activity_summary_page.dart';
import 'digital_wellbeing_page.dart';
import 'parent_control_page.dart';
import 'parent_pin_session.dart';
import 'privacy_explanation_page.dart';
import 'safe_search_setup_page.dart';
import 'website_protection_page.dart';
import 'widgets/family_safety_section_tile.dart';
import 'widgets/parent_pin_prompt_dialog.dart';

class FamilySafetyPage extends StatefulWidget {
  const FamilySafetyPage({super.key});

  @override
  State<FamilySafetyPage> createState() => _FamilySafetyPageState();
}

class _FamilySafetyPageState extends State<FamilySafetyPage>
    with WidgetsBindingObserver {
  static const Color _brandGreen = Color(0xFF388E3C);
  static const int _activitySummaryRangeDays = 30;
  static const String _familyDnsHost = 'family-filter-dns.cleanbrowsing.org';

  final FamilySafetyChannel _familySafetyChannel = FamilySafetyChannel();
  final FocusGuardService _focusGuardService = FocusGuardService();
  final ParentControlStorage _parentControlStorage = ParentControlStorage();

  bool? _basicProtectionOn;
  bool? _digitalWellbeingOn;
  bool? _advancedProtectionOn;
  bool? _parentControlOn;
  bool? _activitySummaryOn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ParentPinSession.clear();
    _loadStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ParentPinSession.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      ParentPinSession.clear();
    }
  }

  Future<void> _loadStatuses() async {
    final dns = await _familySafetyChannel.getPrivateDnsState();
    final vpn = kFamilySafetyFull
        ? await _familySafetyChannel.getVpnStatus()
        : VpnStatus.unsupported();
    final focusGuard = kFamilySafetyFull
        ? await _focusGuardService.loadSettings()
        : null;
    final parentControl = kFamilySafetyFull
        ? await _parentControlStorage.loadStatus()
        : null;
    final activitySummary = kFamilySafetyFull
        ? await _familySafetyChannel.getActivitySummary(
            rangeDays: _activitySummaryRangeDays,
          )
        : const <Object?>[];
    if (!mounted) return;
    setState(() {
      _basicProtectionOn =
          dns.isHostnameMode &&
          dns.host?.trim().toLowerCase() == _familyDnsHost;
      _digitalWellbeingOn = focusGuard?.enabled;
      _advancedProtectionOn = vpn.running;
      _parentControlOn = parentControl?.hasPin;
      _activitySummaryOn = activitySummary.isNotEmpty;
    });
  }

  Future<void> _open(BuildContext context, Widget page) async {
    final allowed = await requireParentPin(context);
    if (!allowed || !context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    await _loadStatuses();
  }

  Future<void> _openInfoPage(BuildContext context, Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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
            statusOn: _basicProtectionOn,
            onTap: () => _open(context, const BasicWebsiteProtectionPage()),
          ),
          if (kFamilySafetyFull) ...[
            const SizedBox(height: 10),
            FamilySafetySectionTile(
              icon: Icons.self_improvement_outlined,
              iconColor: const Color(0xFF1565C0),
              title: strings.digitalWellbeingTitle,
              subtitle: strings.digitalWellbeingSubtitle,
              statusOn: _digitalWellbeingOn,
              onTap: () => _open(context, const DigitalWellbeingPage()),
            ),
            const SizedBox(height: 10),
            FamilySafetySectionTile(
              icon: Icons.shield_outlined,
              iconColor: const Color(0xFF00897B),
              title: strings.websiteProtectionTitle,
              subtitle: strings.websiteProtectionSubtitle,
              statusOn: _advancedProtectionOn,
              onTap: () => _open(context, const WebsiteProtectionPage()),
            ),
            const SizedBox(height: 10),
            FamilySafetySectionTile(
              icon: Icons.lock_outline,
              iconColor: const Color(0xFF6A1B9A),
              title: strings.parentControlTitle,
              subtitle: strings.parentControlSubtitle,
              statusOn: _parentControlOn,
              onTap: () => _open(context, const ParentControlPage()),
            ),
            const SizedBox(height: 10),
            FamilySafetySectionTile(
              icon: Icons.insights_outlined,
              iconColor: const Color(0xFFEF6C00),
              title: strings.activitySummaryTitle,
              subtitle: strings.activitySummarySubtitle,
              statusOn: _activitySummaryOn,
              onTap: () => _openInfoPage(context, const ActivitySummaryPage()),
            ),
          ],
          const SizedBox(height: 10),
          FamilySafetySectionTile(
            icon: Icons.travel_explore_outlined,
            iconColor: const Color(0xFF00796B),
            title: strings.safeSearchSetupTitle,
            subtitle: strings.safeSearchSetupSubtitle,
            statusOn: false,
            showStatus: false,
            onTap: () => _openInfoPage(context, const OtherSafetyGuidePage()),
          ),
          const SizedBox(height: 10),
          FamilySafetySectionTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: const Color(0xFF455A64),
            title: strings.privacyExplanationTitle,
            subtitle: strings.privacyExplanationSubtitle,
            statusOn: false,
            showStatus: false,
            onTap: () => _openInfoPage(context, const PrivacyExplanationPage()),
          ),
        ],
      ),
    );
  }
}
