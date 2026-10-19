/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: women_cycle_screen.dart
/// وحدة الإناث المستقلة: دورة من تواريخها، حمل بعد زرها، رسائل خاصة.
/// =============================================================
library lifex_ai.screens.women_cycle_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/women_health/private_female_notice.dart';
import '../features/women_health/women_ashram_engine.dart';
import '../widgets/honesty_banner.dart';

class WomenCycleScreen extends StatefulWidget {
  const WomenCycleScreen({super.key});

  @override
  State<WomenCycleScreen> createState() => _WomenCycleScreenState();
}

class _WomenCycleScreenState extends State<WomenCycleScreen> {
  static const _enabledKey = 'cycleTrackingEnabled';
  static const _startsKey = 'cycleStarts';
  static const _pregnantKey = 'womenPregnancyConfirmed';
  static const _lmpKey = 'lastMenstrualPeriod';
  static const _openedKey = 'womenOpenedPrivateNotices';

  final _opened = <String>{};

  void _loadOpened(ProfileBoxStore store) {
    _opened
      ..clear()
      ..addAll(
        store
            .list(_openedKey)
            .map((item) => item['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty),
      );
  }

  void _openNotice(ProfileBoxStore store, String id) {
    _opened.add(id);
    store.setList(
      _openedKey,
      _opened.map((item) => {'id': item}).toList(),
    );
    context.read<ActiveProfileController>().saveActiveProfileChanges();
    setState(() {});
  }

  String _fmt(DateTime d) => '${d.year}/${d.month}/${d.day}';

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final profile = controller.activeProfile;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('رعاية الإناث')),
            body: const Center(child: Text('لا يوجد ملف صحي نشط.')),
          );
        }
        final store = ProfileBoxStore(profile);
        _loadOpened(store);
        final enabled = store.stringField(_enabledKey) == 'true';
        final pregnant = store.stringField(_pregnantKey) == 'true';
        final starts = store
            .list(_startsKey)
            .map((item) => DateTime.tryParse(item['date']?.toString() ?? ''))
            .whereType<DateTime>()
            .toList();
        final lmpRaw = store.stringField(_lmpKey);
        final lmp = lmpRaw == null ? null : DateTime.tryParse(lmpRaw);
        final snap = const WomenAshramEngine().evaluate(
          now: DateTime.now(),
          starts: starts,
          trackingEnabled: enabled,
          pregnancyConfirmed: pregnant,
          lmp: lmp,
          profile: profile,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('رعاية الإناث')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const HonestyBanner(
                messageAr:
                    'وحدة مستقلة على هذا الملف فقط: من الطفولة حتى نهاية العمر. '
                    'التقدير من تواريخكِ. الإشعار الظاهر «لديك رسالة خاصة» حتى لا يحدث إحراج. '
                    'ليس منع حمل ولا سوناراً.',
              ),
              SwitchListTile(
                title: const Text('تفعيل الرعاية على هذا الملف'),
                value: enabled,
                onChanged: (value) {
                  store.setString(_enabledKey, value ? 'true' : 'false');
                  controller.saveActiveProfileChanges();
                },
              ),
              if (enabled) ...[
                const SizedBox(height: 8),
                Text('الرسائل الخاصة',
                    style: Theme.of(context).textTheme.titleMedium),
                if (snap.notices.isEmpty)
                  const Text('لا رسالة خاصة الآن.'),
                for (final notice in snap.notices)
                  Card(
                    child: ListTile(
                      title: const Text(PrivateFemaleNotice.publicTitleAr),
                      subtitle: Text(
                        _opened.contains(notice.id)
                            ? notice.bodyAr
                            : 'اضغطي لفتح الرسالة. المحتوى لا يظهر في الإشعار.',
                      ),
                      onTap: () => _openNotice(store, notice.id),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 4000)),
                      lastDate: DateTime.now(),
                    );
                    if (picked == null || !context.mounted) return;
                    store.add(_startsKey, {'date': picked.toIso8601String()});
                    controller.saveActiveProfileChanges();
                  },
                  child: const Text('تسجيل بداية كما حدّدتها'),
                ),
                const SizedBox(height: 8),
                Text('بدايات مسجّلة: ${starts.length}'),
                if (snap.meanCycleDays != null)
                  Text(
                    'متوسط ما بين بداياتكِ: ${snap.meanCycleDays!.toStringAsFixed(1)} يوماً.',
                  ),
                if (snap.nextStart != null)
                  Text('تقدير الموعد التالي (لكِ فقط داخل الوحدة): ${_fmt(snap.nextStart!)}'),
                SwitchListTile(
                  title: const Text('تأكيد الحمل'),
                  subtitle: const Text(
                    'تفعّليه أنتِ بعد الفحص. يحسب العمر من دوراتكِ ويراجع ملفكِ نحو الطبيبة.',
                  ),
                  value: pregnant,
                  onChanged: (value) {
                    store.setString(_pregnantKey, value ? 'true' : 'false');
                    if (value && starts.isNotEmpty) {
                      final last = ([...starts]..sort()).last;
                      store.setString(_lmpKey, last.toIso8601String());
                    }
                    controller.saveActiveProfileChanges();
                  },
                ),
                if (pregnant) ...[
                  if (snap.gestationalWeek != null)
                    Text(
                      'عمر الحمل التقريبي: الأسبوع ${snap.gestationalWeek} من 40. '
                      'عمر الجنين التقريبي: ${snap.fetalAgeDays} يوماً من تقدير الإباضة حسب دوراتكِ. '
                      'أدق من افتراض 28 يوماً، والسونار عند الطبيبة هو المرجع.',
                    ),
                  if (snap.dueDate != null)
                    Text('تقدير نهاية الأربعين أسبوعاً: ${_fmt(snap.dueDate!)}'),
                  if (snap.weeklyCareAr != null) ...[
                    const SizedBox(height: 8),
                    Text(snap.weeklyCareAr!),
                  ],
                  if (snap.dailyCareAr != null) Text(snap.dailyCareAr!),
                  for (final flag in snap.cvFlags) Text(flag),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
