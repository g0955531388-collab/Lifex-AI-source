/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: health_profile_screen.dart
/// المسار: lib/screens/health_profile_screen.dart
/// الوصف: عرض بيانات الملف الصحي الأساسية (health_profile.dart) بشكل
/// مبسّط للقراءة، مع تنويه واضح دائم الظهور حول طبيعة البيانات، ودعم
/// كامل لقارئ الشاشة (TalkBack/VoiceOver) لكل قسم.
/// =============================================================
library lifex_ai.screens.health_profile_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/blood_network/blood_donation_prefs_card.dart';
import '../features/network_box/unit_branch_catalog.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/determination_credential_policy.dart';
import '../features/profile/health_identity_manager.dart';
import '../features/profile/health_profile.dart';
import '../l10n/generated/app_localizations.dart';
import 'unit_branch_navigator.dart';
import '../widgets/lifex_text.dart';
import '../core/i18n/lifex_runtime_translator.dart';

class HealthProfileScreen extends StatelessWidget {
  const HealthProfileScreen({
    super.key,
    this.profile,
    this.preferThisProfile = false,
  });

  /// إن [preferThisProfile] يُعرض هذا الملف دون تبديل الملف النشط للحساب.
  final HealthProfile? profile;
  final bool preferThisProfile;

  String _userId(HealthProfile live) {
    return HealthIdentityManager.instance
            .getByProfileId(live.profileId)
            ?.lifexId ??
        live.profileId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final live = preferThisProfile
            ? (profile ?? controller.activeProfile)
            : (controller.activeProfile ?? profile);
        return Scaffold(
          appBar: AppBar(
            title: LifexText(
              preferThisProfile
                  ? 'ملف مرتبط بالحصة'
                  : (l10n?.homeMyHealthProfile ?? 'ملفي الصحي'),
            ),
          ),
          body: live == null
              ? Center(
                  child: LifexText(
                      l10n?.noHealthProfileLoaded ?? 'لا يوجد ملف صحي محمّل.'),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (preferThisProfile)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LifexText(
                            'عرض ملف مرتبط بهذه الحصة. الملف النشط لحساب الطبيب لم يُبدَّل.',
                          ),
                        ),
                      Semantics(
                        header: true,
                        label: tr('${live.fullName}. المعرف ${_userId(live)}'),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            LifexText(
                              live.fullName,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            SelectableText(
                              'ID ${_userId(live)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      LifexText('العمر: ${live.ageInYears} سنة'),
                      if (live.dateOfBirth != null)
                        LifexText(
                          'تاريخ الميلاد: ${live.dateOfBirth!.year}/${live.dateOfBirth!.month}/${live.dateOfBirth!.day}',
                        ),
                      const SizedBox(height: 16),
                      _InfoSection(
                        titleAr: 'معلومات أساسية',
                        children: [
                          _InfoRow(
                              labelAr: 'فصيلة الدم',
                              valueAr: live.bloodType.name),
                          _InfoRow(
                            labelAr: 'ذوو الهمم',
                            valueAr: const DeterminationCredentialPolicy()
                                .evaluate(live)
                                .messageAr,
                          ),
                          if (live.heightCm != null)
                            _InfoRow(
                                labelAr: 'الطول',
                                valueAr: '${live.heightCm} سم'),
                          if (live.weightKg != null)
                            _InfoRow(
                                labelAr: 'الوزن',
                                valueAr: '${live.weightKg} كغم'),
                          if (live.bodyMassIndex != null)
                            _InfoRow(
                              labelAr: 'مؤشر كتلة الجسم',
                              valueAr: live.bodyMassIndex!.toStringAsFixed(1),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _InfoSection(
                        titleAr: 'الحساسية',
                        children: live.allergies.isEmpty
                            ? [const LifexText('لا توجد حساسية مسجَّلة.')]
                            : live.allergies
                                .map((a) => _InfoRow(
                                      labelAr: a.substance,
                                      valueAr: a.severity,
                                    ))
                                .toList(),
                      ),
                      const SizedBox(height: 16),
                      _InfoSection(
                        titleAr: 'الحالات المزمنة',
                        children: live.chronicConditions.isEmpty
                            ? [const LifexText('لا توجد حالات مزمنة مسجَّلة.')]
                            : live.chronicConditions
                                .map((c) => LifexText(c.conditionName))
                                .toList(),
                      ),
                      const SizedBox(height: 16),
                      BloodDonationPrefsCard(
                        profile: live,
                        onChanged: controller.notifyProfileChanged,
                      ),
                      const SizedBox(height: 16),
                      LifexText('أقسام الملف الصحي',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      for (final branch in UnitBranchCatalog.healthCv)
                        Card(
                          child: ListTile(
                            leading: CircleAvatar(child: Icon(branch.icon)),
                            title: LifexText(branch.titleAr),
                            subtitle: LifexText(branch.subtitleAr),
                            trailing:
                                const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => UnitBranchNavigator.open(
                              context,
                              branch,
                              profileId: live.profileId,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Semantics(
                        label: tr('تنويه: هذه البيانات للاطلاع الشخصي فقط وليست '
                            'بديلاً عن الفحص الطبي المباشر. يُرجى إبقاء هذه '
                            'المعلومات محدَّثة لتكون مفيدة في حالات الطوارئ.'),
                        child: ExcludeSemantics(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const LifexText(
                              'هذه البيانات للاطلاع الشخصي فقط وليست بديلاً عن '
                              'الفحص الطبي المباشر. يُرجى إبقاء هذه المعلومات '
                              'محدَّثة لتكون مفيدة في حالات الطوارئ.',
                              style: TextStyle(fontSize: 12),
                            ),
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
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.titleAr, required this.children});

  final String titleAr;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: LifexText(titleAr, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.labelAr, required this.valueAr});

  final String labelAr;
  final String valueAr;

  @override
  Widget build(BuildContext context) {
    // دمج التسمية والقيمة في إعلان واحد متصل لقارئ الشاشة ("فصيلة الدم:
    // O positive") بدلاً من نطق نصّين منفصلين قد يفصل بينهما القارئ.
    return Semantics(
      label: tr('$labelAr: $valueAr'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ExcludeSemantics(
              child: LifexText(labelAr, style: const TextStyle(color: Colors.grey)),
            ),
            ExcludeSemantics(
              child: LifexText(valueAr,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
