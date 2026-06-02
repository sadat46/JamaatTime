import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme_tokens.dart';
import '../../core/locale_text.dart';
import '../../models/jamaat_location.dart';
import '../../widgets/forbidden_times_widget.dart';
import '../../widgets/sahri_iftar_widget.dart';
import '../../widgets/shared_ui_widgets.dart';
import 'home_controller.dart';
import 'widgets/home_header.dart';
import 'widgets/prayer_table_section.dart';

class HomeScreen extends StatefulWidget {
  final bool isActive;
  final HomeController? controller;
  final Widget? noticeAction;

  const HomeScreen({
    super.key,
    this.isActive = true,
    this.controller,
    this.noticeAction,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final HomeController _controller;
  late final bool _ownsController;

  // Ensures the "pick a mosque" prompt is shown at most once per session.
  bool _mosquePromptShown = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        HomeController(
          isActive: widget.isActive,
          lifecycleState: WidgetsBinding.instance.lifecycleState,
        );
    WidgetsBinding.instance.addObserver(this);
    if (_ownsController) {
      unawaited(_controller.hydrateFromCache());
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _controller.initialize();
        if (!mounted) return;
        // Startup state is now applied, so jamaatLocation.source is settled.
        _maybePromptSelectMosque();
      });
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _controller.setHomeActive(widget.isActive);
      // If the user has just switched to the Home tab and still has no mosque,
      // surface the prompt now rather than silently.
      if (widget.isActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybePromptSelectMosque();
        });
      }
    }
  }

  void _maybePromptSelectMosque() {
    if (_mosquePromptShown || !mounted || !widget.isActive) return;
    if (_controller.jamaatLocation.source != JamaatSource.none) return;
    _mosquePromptShown = true;
    unawaited(_showSelectMosqueDialog());
  }

  Future<void> _showSelectMosqueDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.primaryGreen,
                        AppColors.primaryDark,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.mosque,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  context.tr(
                    bn: 'আপনার মসজিদ বেছে নিন',
                    en: 'Choose your mosque',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr(
                    bn: 'আপনি এখনো কোনো মসজিদ নির্বাচন করেননি। মসজিদ ছাড়া অ্যাপ '
                        'কোনো জামাতের সময় দেখাবে না এবং জামাতের কোনো রিমাইন্ডারও '
                        'পাঠাবে না। শুরু করতে উপরের ড্রপডাউন থেকে একটি মসজিদ '
                        'নির্বাচন করুন।',
                    en: "You haven't selected a mosque yet. Without one, the "
                        "app won't show any Jamaat times or send any "
                        'Jamaat-related notifications. Pick a mosque from the '
                        'dropdown at the top to get started.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(
                      context.tr(bn: 'বুঝেছি', en: 'Got it'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxContentWidth = constraints.maxWidth < 600
            ? constraints.maxWidth
            : 600.0;
        final horizontalPadding = constraints.maxWidth < 400 ? 8.0 : 16.0;
        return Scaffold(
          backgroundColor: isDarkMode
              ? Theme.of(context).scaffoldBackgroundColor
              : AppColors.pageBackground,
          body: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
            child: RefreshIndicator(
              onRefresh: _controller.refreshJamaatTimes,
              color: Theme.of(context).colorScheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeHeader(
                      controller: _controller,
                      pageConstraints: constraints,
                      noticeAction: widget.noticeAction,
                    ),
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxContentWidth),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            10,
                            horizontalPadding,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PrayerTableSection(controller: _controller),
                              const SizedBox(height: 14),
                              _AuxiliaryPrayerSections(controller: _controller),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AuxiliaryPrayerSections extends StatelessWidget {
  const _AuxiliaryPrayerSections({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final sahriBandColor = isDarkMode
        ? const Color(0xFF17261F)
        : AppColors.cardBackground;
    final sahriBandBorder = isDarkMode
        ? const Color(0xFF2E4A3B)
        : AppColors.borderLight;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: sahriBandColor,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: sahriBandBorder),
                boxShadow: isDarkMode ? const [] : AppShadows.softCard,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: context.tr(
                      bn: 'সাহরি ও ইফতার সময়',
                      en: 'Sahri & Iftar Times',
                    ),
                  ),
                  SahriIftarWidget(
                    fajrTime: controller.times['Fajr'],
                    maghribTime: controller.times['Maghrib'],
                    showTitle: false,
                    isActive: controller.shouldRunHomeTimer,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ForbiddenTimesWidget(
              prayerTimes: controller.prayerTimes,
              isActive: controller.shouldRunHomeTimer,
            ),
          ],
        );
      },
    );
  }
}
