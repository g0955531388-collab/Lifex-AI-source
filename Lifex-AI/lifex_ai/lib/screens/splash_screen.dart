/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: splash_screen.dart
/// المسار: lib/screens/splash_screen.dart
/// الوصف: الشاشة الافتتاحية (Splash) — أول ما يراه المستخدم عند فتح
/// التطبيق. تعرض شعار/اسم التطبيق ونص الإسناد والملكية الرسمي الكامل
/// قبل الانتقال للشاشة الرئيسية.
///
/// ⚠️ هذا النص (AppConstants.ownershipStatement) إلزامي الظهور هنا ولا
/// يجوز حذفه أو اختصاره أو تغييره.
/// =============================================================
library lifex_ai.screens.splash_screen;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../core/i18n/lifex_i18n.dart';
import '../features/profile/active_profile_controller.dart';
import '../widgets/accessible_widgets.dart';
import '../widgets/lifex_app_title.dart';
import '../widgets/lifex_brand_mark.dart';
import '../features/voice/hardware_cue_host.dart';
import 'home_screen.dart';
import 'profile_setup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen(
      {super.key, this.displayDuration = const Duration(seconds: 3)});

  /// مدة عرض الشاشة الافتتاحية قبل الانتقال تلقائياً للشاشة التالية.
  final Duration displayDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _auto;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _left) return;
      if (lifexScreenReaderOn(context)) return;
      _auto = Timer(widget.displayDuration, _enter);
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  void _enter() {
    if (_left || !mounted) return;
    _left = true;
    _auto?.cancel();
    final controller = Provider.of<ActiveProfileController>(
      context,
      listen: false,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => controller.hasAnyProfile
            ? const HomeScreen()
            : const ProfileSetupScreen(),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(HardwareCueHost.consumeLauncherShortcut());
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ScreenArrival(
      message: BlindNavigationCopy.splashArrivalText,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: media.padding.top),
              LifexBrandMark(size: media.size.width),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + media.padding.bottom),
                child: Column(
                  children: [
                    LifexAppTitle(
                      centered: true,
                      markSize: 28,
                      lineSize: 15,
                      markColor: Theme.of(context).textTheme.headlineMedium?.color,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppConstants.studioBannerCredit,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    Semantics(
                      button: true,
                      label: context.nav('nav.enter'),
                      hint: context.nav('nav.enterHint'),
                      onTap: _enter,
                      child: ExcludeSemantics(
                        child: FilledButton(
                          onPressed: _enter,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 28,
                            ),
                            child: Text(context.nav('nav.enter')),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Semantics(
                      label:
                          '${AppConstants.ownershipStatement} ${AppConstants.humanitarianExemptionStatementAr}',
                      child: ExcludeSemantics(
                        child: Column(
                          children: [
                            Text(
                              AppConstants.ownershipStatement,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppConstants.humanitarianExemptionStatementAr,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${AppConstants.academyNameAr} — ${AppConstants.ownerEmail} — ${AppConstants.ownerPhoneNumber}',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
