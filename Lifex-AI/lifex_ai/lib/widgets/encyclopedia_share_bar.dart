/// =============================================================
/// Lifex-AI — المكوّنات المشتركة
/// الملف: encyclopedia_share_bar.dart
/// المشاركة العامة تمر عبر LioSensitiveActionEntry → LIO.
/// =============================================================
library lifex_ai.widgets.encyclopedia_share_bar;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/admin/admin_manager.dart';
import '../core/app_config.dart';
import '../core/i18n/lifex_i18n.dart';
import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';
import '../core/trial_manager.dart';
import '../features/finance/billing_exemption_policy.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_identity_manager.dart';
import '../features/voice/voice_engine.dart';
import '../screens/professional_directory_screen.dart';
import 'device_wall_clock.dart';

class EncyclopediaShareBar extends StatelessWidget {
  const EncyclopediaShareBar({super.key});

  Future<void> _share(BuildContext context) async {
    final entry = Provider.of<LioSensitiveActionEntry>(context, listen: false);
    final outcome = await entry.sharePublicEncyclopedia(
      gatewayRequest: LioGatewayRequest(
        requestId: 'share_ency_${DateTime.now().millisecondsSinceEpoch}',
        correlationId: 'share_public',
        identityAccountId: 'public_share',
        purpose: 'education',
        requestedAction: 'share_public_encyclopedia',
        dataScope: 'public',
        sensitivity: LioDataSensitivity.public,
        consent: const LioConsentContext(
          consentGranted: true,
          purposeAligned: true,
        ),
        riskLevel: LioActionRisk.low,
        timestamp: DateTime.now().toUtc(),
        authenticated: true,
        authorized: true,
        minimumNecessarySatisfied: true,
      ),
    );
    if (!context.mounted) return;
    final msg = outcome.executed
        ? (outcome.value?.messageAr ?? 'تمت المشاركة.')
        : 'توقفت المشاركة عند LIO (${outcome.decision.wireDecision}).';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openDirectory(BuildContext context) {
    final trial = context.read<TrialManager>();
    final profile = context.read<ActiveProfileController>().activeProfile;
    final exempt = profile != null &&
        const BillingExemptionPolicy().evaluate(profile).isExempt;
    final identity = profile == null
        ? null
        : HealthIdentityManager.instance.getByProfileId(profile.profileId);
    final adminAccess = identity != null &&
        GlobalAdminManager.instance.hasFullSystemAccess(identity.lifexId);
    final allowed = const SessionAccessPolicy().canOpenUnit(
      'directory',
      phase: trial.phase(feeExempt: exempt, adminAccess: adminAccess),
      feeExempt: exempt,
      adminAccess: adminAccess,
    );
    if (!allowed) {
      final phase = trial.phase();
      final reason = phase == TrialPhase.giftFrozen
          ? 'REQUIRES_EXTERNAL_SETUP — نسخة الإهداء غير مخصّصة بعد. '
              'افتح الإعدادات لإكمال التخصيص.'
          : trial.statusLineAr();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reason)),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfessionalDirectoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: context.nav('nav.share'),
                  hint: context.nav('nav.shareHint'),
                  child: ExcludeSemantics(
                    child: FilledButton.icon(
                      onPressed: () => _share(context),
                      icon: const Icon(Icons.share),
                      label: Text(context.nav('nav.share')),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  button: true,
                  label: context.nav('nav.fullDirectory'),
                  hint: lifexUi(
                    'يفتح الدليل المهني المحلي',
                    'Opens the local professional directory',
                  ),
                  child: ExcludeSemantics(
                    child: FilledButton.icon(
                      onPressed: () => _openDirectory(context),
                      icon: const Icon(Icons.badge_outlined),
                      label: Text(context.nav('nav.fullDirectory')),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SpeakingWallClock extends StatefulWidget {
  const SpeakingWallClock({super.key});

  @override
  State<SpeakingWallClock> createState() => _SpeakingWallClockState();
}

class _SpeakingWallClockState extends State<SpeakingWallClock> {
  static const _clock = DeviceWallClock();
  Timer? _tick;
  DateTime _now = DateTime.now();

  void _sync(bool visible) {
    if (!visible) {
      _tick?.cancel();
      _tick = null;
      return;
    }
    if (_tick != null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  Future<void> _speak() async {
    final phrase = _clock.spokenLabel(DateTime.now());
    if (mounted) setState(() => _now = DateTime.now());
    await VoiceEngine.instance.speak(phrase);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    _sync(visible);
    final spoken = _clock.spokenLabel(_now);
    return Semantics(
      button: true,
      label: spoken,
      hint: 'ينطق الساعة والتاريخ',
      onTap: () => unawaited(_speak()),
      child: ExcludeSemantics(
        child: Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => unawaited(_speak()),
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _clock.timeLabel(_now),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _clock.dateLabel(_now),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
