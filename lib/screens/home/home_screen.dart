import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme_tokens.dart';
import '../../core/locale_text.dart';
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
      _controller.initialize();
    }
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _controller.setHomeActive(widget.isActive);
    }
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
