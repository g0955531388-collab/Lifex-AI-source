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

import '../features/network_box/unit_branch_catalog.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/determination_credential_policy.dart';
import '../features/profile/health_profile.dart';
import '../widgets/record_management_actions.dart';
import '../l10n/generated/app_localizations.dart';
import 'unit_branch_navigator.dart';

class HealthProfileScreen extends StatelessWidget {
  const HealthProfileScreen({
    super.key,
    this.profile,
    this.preferThisProfile = false,
  });

  /// إن [preferThisProfile] يُعرض هذا الملف دون تبديل الملف النشط للحساب.
  final HealthProfile? profile;
  final bool preferThisProfile;

  Future<void> _editProfile(
    BuildContext context,
    ActiveProfileController controller,
    HealthProfile profile,
  ) async {
    final name = TextEditingController(text: profile.fullName);
    final height = TextEditingController(text: profile.heightCm?.toString() ?? '');
    final weight = TextEditingController(text: profile.weightKg?.toString() ?? '');
    var birthDate = profile.dateOfBirth;
    var bloodType = profile.bloodType;
    var sex = profile.biologicalSex;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('تعديل بيانات الملف الصحي'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                  ),
                  InkWell(
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: birthDate,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      );
                      if (selected != null) {
                        setDialogState(() => birthDate = selected);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'تاريخ الميلاد',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(birthDate.toIso8601String().split('T').first),
                    ),
                  ),
                  DropdownButtonFormField<BloodType>(
                    value: bloodType,
                    decoration: const InputDecoration(labelText: 'فصيلة الدم'),
                    items: BloodType.values
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => bloodType = value);
                    },
                  ),
                  DropdownButtonFormField<BiologicalSex>(
                    value: sex,
                    decoration: const InputDecoration(labelText: 'الجنس البيولوجي'),
                    items: BiologicalSex.values
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => sex = value);
                    },
                  ),
                  TextField(
                    controller: height,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'الطول (سم)'),
                  ),
                  TextField(
                    controller: weight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'الوزن (كغ)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('حفظ التعديلات'),
              ),
            ],
          ),
        ),
      );
      if (saved != true) return;

      final parsedHeight = height.text.trim().isEmpty
          ? null
          : double.tryParse(height.text.trim().replaceAll(',', '.'));
      final parsedWeight = weight.text.trim().isEmpty
          ? null
          : double.tryParse(weight.text.trim().replaceAll(',', '.'));
      if ((height.text.trim().isNotEmpty && parsedHeight == null) ||
          (weight.text.trim().isNotEmpty && parsedWeight == null) ||
          (parsedHeight != null && parsedHeight <= 0) ||
          (parsedWeight != null && parsedWeight <= 0) ||
          name.text.trim().isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تحقق من الاسم والطول والوزن قبل الحفظ.')),
          );
        }
        return;
      }

      profile.fullName = name.text.trim();
      profile.dateOfBirth = birthDate;
      profile.bloodType = bloodType;
      profile.biologicalSex = sex;
      profile.heightCm = parsedHeight;
      profile.weightKg = parsedWeight;
      profile.lastUpdatedAt = DateTime.now();
      controller.saveActiveProfileChanges();
    } finally {
      name.dispose();
      height.dispose();
      weight.dispose();
    }
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
            title: Text(
              preferThisProfile
                  ? 'ملف مرتبط بالحصة'
                  : (l10n?.homeMyHealthProfile ?? 'ملفي الصحي'),
            ),
            actions: [
              if (!preferThisProfile &&
                  live != null &&
                  live.profileId == controller.activeProfileId)
                RecordManagementActions(
                  onEdit: () => _editProfile(context, controller, live),
                  onDelete: null,
                  editLabel: 'تعديل الملف',
                ),
            ],
          ),
          body: live == null
              ? Center(
                  child: Text(
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
                      child: Text(
                        'عرض ملف مرتبط بهذه الحصة. الملف النشط لحساب الطبيب لم يُبدَّل.',
                      ),
                    ),
                  Semantics(
                    header: true,
                    child: Text(
                      live.fullName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('العمر: ${live.ageInYears} سنة'),
                  const SizedBox(height: 16),
                  _InfoSection(
                    titleAr: 'معلومات أساسية',
                    children: [
                      _InfoRow(labelAr: 'فصيلة الدم', valueAr: live.bloodType.name),
                      _InfoRow(
                        labelAr: 'ذوو الهمم',
                        valueAr: const DeterminationCredentialPolicy()
                            .evaluate(live)
                            .messageAr,
                      ),
                      if (live.heightCm != null)
                        _InfoRow(labelAr: 'الطول', valueAr: '${live.heightCm} سم'),
                      if (live.weightKg != null)
                        _InfoRow(labelAr: 'الوزن', valueAr: '${live.weightKg} كغم'),
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
                        ? [const Text('لا توجد حساسية مسجَّلة.')]
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
                        ? [const Text('لا توجد حالات مزمنة مسجَّلة.')]
                        : live.chronicConditions
                            .map((c) => Text(c.conditionName))
                            .toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('أقسام الملف الصحي',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  for (final branch in UnitBranchCatalog.healthCv)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Icon(branch.icon)),
                        title: Text(branch.titleAr),
                        subtitle: Text(branch.subtitleAr),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () => UnitBranchNavigator.open(
                          context,
                          branch,
                          profileId: live.profileId,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  Semantics(
                    label: 'تنويه: هذه البيانات للاطلاع الشخصي فقط وليست '
                        'بديلاً عن الفحص الطبي المباشر. يُرجى إبقاء هذه '
                        'المعلومات محدَّثة لتكون مفيدة في حالات الطوارئ.',
                    child: ExcludeSemantics(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
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
          child: Text(titleAr, style: Theme.of(context).textTheme.titleMedium),
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
      label: '$labelAr: $valueAr',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ExcludeSemantics(
              child: Text(labelAr, style: const TextStyle(color: Colors.grey)),
            ),
            ExcludeSemantics(
              child: Text(valueAr, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
