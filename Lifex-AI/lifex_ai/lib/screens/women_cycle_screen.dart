/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: women_cycle_screen.dart
/// وحدة الإناث المستقلة: دورة من تواريخها، حمل بعد زرها، رسائل خاصة.
/// =============================================================
library lifex_ai.screens.women_cycle_screen;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../features/medications/pharmacopoeia_reference.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/women_health/private_female_notice.dart';
import '../features/women_health/women_ashram_engine.dart';
import '../features/women_health/women_care_desk.dart';
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
  static const _basisKey = 'womenPregnancyBasis';
  static const _babyKey = 'linkedBabyProfileId';
  static const _lmpKey = 'lastMenstrualPeriod';
  static const _openedKey = 'womenOpenedPrivateNotices';

  final _opened = <String>{};
  PharmacopoeiaReference? _pharmacopoeia;

  @override
  void initState() {
    super.initState();
    _loadPharmacopoeia();
  }

  Future<void> _loadPharmacopoeia() async {
    try {
      final raw = await rootBundle.loadString(PharmacopoeiaReference.assetPath);
      final book = PharmacopoeiaReference.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (mounted) setState(() => _pharmacopoeia = book);
    } catch (_) {
      if (mounted) setState(() => _pharmacopoeia = null);
    }
  }

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

  Future<void> _askPregnancyBasis(
    ProfileBoxStore store,
    ActiveProfileController controller,
    List<DateTime> starts,
  ) async {
    final basis = await showDialog<PregnancyBasis>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('ما أساس التأكيد؟'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, PregnancyBasis.homeTest),
            child: const Text('اختبار حمل منزلي إيجابي'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, PregnancyBasis.laboratory),
            child: const Text('فحص مخبري'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, PregnancyBasis.clinician),
            child: const Text('تأكيد من مقدم الرعاية'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, PregnancyBasis.unsure),
            child: const Text('أحتاج إلى إرشاد لأنني غير متأكدة'),
          ),
        ],
      ),
    );
    if (basis == null || !mounted) return;
    final result = const WomenCareDesk().openFromBasis(basis);
    store.setString(_basisKey, basis.name);
    store.setString(_pregnantKey, result.confirmed ? 'true' : 'false');
    if (result.confirmed && starts.isNotEmpty) {
      final last = ([...starts]..sort()).last;
      store.setString(_lmpKey, last.toIso8601String());
    }
    controller.saveActiveProfileChanges();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.messageAr)),
    );
  }

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
          pharmacopoeia: _pharmacopoeia,
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
                if (snap.notices.isEmpty) const Text('لا رسالة خاصة الآن.'),
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
                  onPressed: () {
                    store.add(_startsKey, {
                      'date': DateTime.now().toIso8601String(),
                    });
                    controller.saveActiveProfileChanges();
                  },
                  child: const Text('نعم، بدأت'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
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
                  child: const Text('تسجيل بداية في يوم سابق'),
                ),
                const SizedBox(height: 8),
                Text('بدايات مسجّلة: ${starts.length}'),
                if (snap.meanCycleDays == null)
                  const Text(
                    'لا تقدير شخصي من دورة واحدة. الموعد يبقى غير محسوب حتى تتوفر بدايتان على الأقل.',
                  ),
                if (snap.meanCycleDays != null)
                  Text(
                    'متوسط ما بين بداياتكِ: ${snap.meanCycleDays!.toStringAsFixed(1)} يوماً. هذا تقدير وقد يتغير.',
                  ),
                if (snap.nextStart != null)
                  Text(
                      'تقدير الموعد التالي (لكِ فقط داخل الوحدة): ${_fmt(snap.nextStart!)}'),
                FilledButton(
                  onPressed: () =>
                      _askPregnancyBasis(store, controller, starts),
                  child: const Text('أنا حامل'),
                ),
                const SizedBox(height: 8),
                Text(const WomenCareDesk().dailyCheckInAr()),
                if (store.stringField(_basisKey) == 'unsure')
                  const Text(
                    'متابعة محتملة فقط. لم يُسجَّل حمل مؤكد.',
                  ),
                if (pregnant) ...[
                  if (lmp != null)
                    Text(
                      const WomenCareDesk()
                          .age(lmp: lmp, now: DateTime.now())
                          .labelAr,
                    ),
                  if (snap.gestationalWeek != null)
                    Text(
                      'عمر الحمل التقريبي: الأسبوع ${snap.gestationalWeek}. '
                      'الطبيبة قد تعدّل التاريخ بعد التقييم. غياب الأعراض لا يعني أن الحمل سليم.',
                    ),
                  OutlinedButton(
                    onPressed: () {
                      final path = const WomenCareDesk().urgentPath('نزيف');
                      if (path == null) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(path)),
                      );
                    },
                    child: const Text('لدي نزيف أو ألم شديد'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      final id = const WomenCareDesk().babyProfileId(
                        motherProfileId: profile.profileId,
                        bornAt: DateTime.now(),
                      );
                      store.setString(_babyKey, id);
                      controller.saveActiveProfileChanges();
                    },
                    child: const Text('تسجيل ولادة وملف طفل مستقل'),
                  ),
                  if (store.stringField(_babyKey) != null)
                    Text('ملف الطفل: ${store.stringField(_babyKey)}'),
                  if (snap.dueDate != null)
                    Text(
                        'تقدير نهاية الأربعين أسبوعاً: ${_fmt(snap.dueDate!)}'),
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
