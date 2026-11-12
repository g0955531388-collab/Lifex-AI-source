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
import '../widgets/lifex_text.dart';

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
        title: const LifexText('ما أساس التأكيد؟'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, PregnancyBasis.homeTest),
            child: const LifexText('اختبار حمل منزلي إيجابي'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, PregnancyBasis.laboratory),
            child: const LifexText('فحص مخبري'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, PregnancyBasis.clinician),
            child: const LifexText('تأكيد من مقدم الرعاية'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, PregnancyBasis.unsure),
            child: const LifexText('أحتاج إلى إرشاد لأنني غير متأكدة'),
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
      SnackBar(content: LifexText(result.messageAr)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ActiveProfileController>(
      builder: (context, controller, _) {
        final profile = controller.activeProfile;
        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const LifexText('رعاية الإناث')),
            body: const Center(child: LifexText('لا يوجد ملف صحي نشط.')),
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
          appBar: AppBar(title: const LifexText('رعاية الإناث')),
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
                title: const LifexText('تفعيل الرعاية على هذا الملف'),
                value: enabled,
                onChanged: (value) {
                  store.setString(_enabledKey, value ? 'true' : 'false');
                  controller.saveActiveProfileChanges();
                },
              ),
              if (enabled) ...[
                const SizedBox(height: 8),
                LifexText('الرسائل الخاصة',
                    style: Theme.of(context).textTheme.titleMedium),
                if (snap.notices.isEmpty) const LifexText('لا رسالة خاصة الآن.'),
                for (final notice in snap.notices)
                  Card(
                    child: ListTile(
                      title: const LifexText(PrivateFemaleNotice.publicTitleAr),
                      subtitle: LifexText(
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
                  child: const LifexText('نعم، بدأت'),
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
                  child: const LifexText('تسجيل بداية في يوم سابق'),
                ),
                const SizedBox(height: 8),
                LifexText('بدايات مسجّلة: ${starts.length}'),
                if (snap.meanCycleDays == null)
                  const LifexText(
                    'لا تقدير شخصي من دورة واحدة. الموعد يبقى غير محسوب حتى تتوفر بدايتان على الأقل.',
                  ),
                if (snap.meanCycleDays != null)
                  LifexText(
                    'متوسط ما بين بداياتكِ: ${snap.meanCycleDays!.toStringAsFixed(1)} يوماً. هذا تقدير وقد يتغير.',
                  ),
                if (snap.nextStart != null)
                  LifexText(
                      'تقدير الموعد التالي (لكِ فقط داخل الوحدة): ${_fmt(snap.nextStart!)}'),
                FilledButton(
                  onPressed: () =>
                      _askPregnancyBasis(store, controller, starts),
                  child: const LifexText('أنا حامل'),
                ),
                const SizedBox(height: 8),
                LifexText(const WomenCareDesk().dailyCheckInAr()),
                if (store.stringField(_basisKey) == 'unsure')
                  const LifexText(
                    'متابعة محتملة فقط. لم يُسجَّل حمل مؤكد.',
                  ),
                if (pregnant) ...[
                  if (lmp != null)
                    LifexText(
                      const WomenCareDesk()
                          .age(lmp: lmp, now: DateTime.now())
                          .labelAr,
                    ),
                  if (snap.gestationalWeek != null)
                    LifexText(
                      'عمر الحمل التقريبي: الأسبوع ${snap.gestationalWeek}. '
                      'الطبيبة قد تعدّل التاريخ بعد التقييم. غياب الأعراض لا يعني أن الحمل سليم.',
                    ),
                  OutlinedButton(
                    onPressed: () {
                      final path = const WomenCareDesk().urgentPath('نزيف');
                      if (path == null) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: LifexText(path)),
                      );
                    },
                    child: const LifexText('لدي نزيف أو ألم شديد'),
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
                    child: const LifexText('تسجيل ولادة وملف طفل مستقل'),
                  ),
                  if (store.stringField(_babyKey) != null)
                    LifexText('ملف الطفل: ${store.stringField(_babyKey)}'),
                  if (snap.dueDate != null)
                    LifexText(
                        'تقدير نهاية الأربعين أسبوعاً: ${_fmt(snap.dueDate!)}'),
                  if (snap.weeklyCareAr != null) ...[
                    const SizedBox(height: 8),
                    LifexText(snap.weeklyCareAr!),
                  ],
                  if (snap.dailyCareAr != null) LifexText(snap.dailyCareAr!),
                  for (final flag in snap.cvFlags) LifexText(flag),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}
