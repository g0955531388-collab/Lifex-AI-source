/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: dental_chart_screen.dart
/// مخطط أسنان على مستوى السن.
/// =============================================================
library lifex_ai.screens.dental_chart_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/dental/dental_chart.dart';
import '../features/dental/dental_dashboard.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../widgets/honesty_banner.dart';

class DentalChartScreen extends StatelessWidget {
  const DentalChartScreen({super.key});

  static const _key = 'dentalChart';

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final profile = controller.activeProfile;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('مخطط الأسنان')),
            body: const Center(child: Text('لا يوجد ملف صحي نشط.')),
          );
        }
        final store = ProfileBoxStore(profile);
        final chart = DentalChart.fromJson(store.map(_key));
        return Scaffold(
          appBar: AppBar(title: const Text('مخطط الأسنان')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const HonestyBanner(
                messageAr:
                    'ملاحظات على مستوى السن يكتبها المستخدم أو طبيبه. ليست تشخيص أشعة. '
                    'جلسة العيادة سجل على هذا الجهاز: السعر بالوحدة الصغرى، وليست فاتورة مرسلة.',
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _recordSession(context, controller, store),
                icon: const Icon(Icons.timer_outlined),
                label: const Text('تسجيل جلسة عيادة'),
              ),
              const SizedBox(height: 8),
              for (final session in store.list(BoxKeys.dentalSessions))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(session['workTypeAr'] as String? ?? 'جلسة'),
                  subtitle: Text(
                    '${session['durationMinutes'] ?? '—'} د • '
                    '${session['priceMinorUnits'] ?? '—'} وحدة صغرى • '
                    '${session['dentalProviderId'] ?? ''}',
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tooth in DentalChart.fdiAdult)
                    ActionChip(
                      label: Text('$tooth'),
                      avatar: chart.noteFor(tooth).isEmpty
                          ? null
                          : const Icon(Icons.notes, size: 16),
                      onPressed: () async {
                        final field =
                            TextEditingController(text: chart.noteFor(tooth));
                        final saved = await showDialog<String>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('السن $tooth'),
                            content: TextField(
                              controller: field,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'ملاحظة أو خطة',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('إلغاء'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(context, field.text),
                                child: const Text('حفظ'),
                              ),
                            ],
                          ),
                        );
                        field.dispose();
                        if (saved == null) return;
                        chart.setNote(tooth, saved);
                        store.setMap(_key, chart.toJson());
                        controller.saveActiveProfileChanges();
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _recordSession(
    BuildContext context,
    ActiveProfileController controller,
    ProfileBoxStore store,
  ) async {
    final profile = controller.activeProfile;
    if (profile == null) return;
    final workType = TextEditingController();
    final minutes = TextEditingController();
    final materials = TextEditingController();
    final price = TextEditingController();
    final provider = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('جلسة عيادة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: workType,
                decoration: const InputDecoration(labelText: 'نوع العمل'),
              ),
              TextField(
                controller: minutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'المدة بالدقائق'),
              ),
              TextField(
                controller: materials,
                decoration: const InputDecoration(
                  labelText: 'المواد، مفصولة بفاصلة',
                ),
              ),
              TextField(
                controller: price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'السعر بالوحدة الصغرى',
                ),
              ),
              TextField(
                controller: provider,
                decoration: const InputDecoration(
                  labelText: 'معرف الطبيب أو العيادة',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    final work = workType.text;
    final minuteText = minutes.text;
    final materialText = materials.text;
    final priceText = price.text;
    final providerText = provider.text;
    workType.dispose();
    minutes.dispose();
    materials.dispose();
    price.dispose();
    provider.dispose();
    if (saved != true || !context.mounted) return;
    final durationMinutes = int.tryParse(minuteText.trim());
    final priceMinor = int.tryParse(priceText.trim());
    if (durationMinutes == null || priceMinor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('المدة والسعر رقمان صحيحان.')),
      );
      return;
    }
    final consumed = materialText
        .split(RegExp(r'[,،]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final session = DentalDashboard().recordSession(
      patientProfileId: profile.profileId,
      dentalProviderId: providerText,
      workTypeAr: work,
      duration: Duration(minutes: durationMinutes),
      materialsConsumed: consumed,
      priceMinorUnits: priceMinor,
    );
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم تُحفظ الجلسة. نوع العمل والطبيب والمدة والسعر لازمة.'),
        ),
      );
      return;
    }
    store.add(BoxKeys.dentalSessions, {
      'sessionId': session.sessionId,
      'patientProfileId': session.patientProfileId,
      'dentalProviderId': session.dentalProviderId,
      'workTypeAr': session.workTypeAr,
      'durationMinutes': session.duration.inMinutes,
      'materialsConsumed': session.materialsConsumed,
      'priceMinorUnits': session.priceMinorUnits,
      'recordedAt': session.recordedAt.toIso8601String(),
    });
    controller.saveActiveProfileChanges();
  }
}
