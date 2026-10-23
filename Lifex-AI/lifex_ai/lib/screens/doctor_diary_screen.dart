/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: doctor_diary_screen.dart
/// لوحة داخلية ليوميات الطبيب. حصص فارغة حتى يحجزها الطبيب. بلا مرضى وهميين.
/// =============================================================
library lifex_ai.screens.doctor_diary_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/doctors/clinic_day_board.dart';
import '../features/doctors/daily_clinic_clock.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_profile.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/honesty_banner.dart';
import 'health_profile_screen.dart';

class DoctorDiaryScreen extends StatefulWidget {
  const DoctorDiaryScreen({super.key});

  @override
  State<DoctorDiaryScreen> createState() => _DoctorDiaryScreenState();
}

class _DoctorDiaryScreenState extends State<DoctorDiaryScreen> {
  DateTime _day = DateTime.now();
  int _maxPatients = 12;
  int _examMinutes = 15;
  int _startHour = 9;
  bool _speak = true;
  bool _pharmacyReview = false;
  final _pharmacyNames = TextEditingController();
  List<Map<String, dynamic>> _slots = [];
  String? _hydratedDay;
  bool _welcomed = false;

  String get _dayKey =>
      '${_day.year}-${_day.month.toString().padLeft(2, '0')}-${_day.day.toString().padLeft(2, '0')}';

  ProfileBoxStore? _store() {
    final profile = context.read<ActiveProfileController>().activeProfile;
    if (profile == null) return null;
    return ProfileBoxStore(profile);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_welcomed || !mounted) return;
      _welcomed = true;
      _say('مرحباً في اللوحة الداخلية ليوميات الطبيب. ولّد الجدول فارغاً ثم احجز أنت.');
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDay();
  }

  @override
  void dispose() {
    _pharmacyNames.dispose();
    super.dispose();
  }

  void _loadDay({bool force = false}) {
    if (!force && _hydratedDay == _dayKey) return;
    final store = _store();
    _hydratedDay = _dayKey;
    if (store == null) {
      _slots = [];
      _pharmacyReview = false;
      _pharmacyNames.text = '';
      return;
    }
    final days = store.list(BoxKeys.doctorDiaryDays);
    final match = days.where((item) => item['day'] == _dayKey);
    if (match.isEmpty) {
      _slots = [];
      _pharmacyReview = false;
      _pharmacyNames.text = '';
      return;
    }
    final row = match.first;
    _pharmacyReview = row['pharmacyReview'] == true;
    _pharmacyNames.text = row['pharmacyNames'] as String? ?? '';
    final raw = row['slots'];
    if (raw is List) {
      _slots = raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } else {
      _slots = [];
    }
  }

  Future<void> _say(String ar) async {
    if (!_speak) return;
    await VoiceEngine.instance.speak(ar);
  }

  void _persist() {
    final controller = context.read<ActiveProfileController>();
    final store = _store();
    if (store == null) return;
    final next = store.list(BoxKeys.doctorDiaryDays)
      ..removeWhere((item) => item['day'] == _dayKey);
    next.add({
      'day': _dayKey,
      'pharmacyReview': _pharmacyReview,
      'pharmacyNames': _pharmacyNames.text.trim(),
      'slots': _slots,
    });
    store.setList(BoxKeys.doctorDiaryDays, next);
    controller.saveActiveProfileChanges();
  }

  Future<void> _generate() async {
    final drafts = const DailyClinicClock().buildDay(
      day: _day,
      maxPatients: _maxPatients,
      examMinutes: _examMinutes,
      startHour: _startHour,
      startMinute: 0,
    );
    setState(() {
      _slots = [
        for (final draft in drafts)
          const ClinicEmptyBoard().emptySlot(
            index: draft.index,
            time: draft.clockLabel(),
          ),
      ];
    });
    _persist();
    await _say(
      'وُلّد جدول $_dayKey بعدد ${_slots.length} حصص فارغة. لن أختلق مرضى.',
    );
  }

  ClinicDayStats get _stats => ClinicDayStats.fromSlots(_slots);

  Future<void> _book(int index) async {
    final profiles = context.read<ActiveProfileController>();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final field = TextEditingController(
          text: _slots[index]['alias']?.toString() ?? '',
        );
        String? linked = _slots[index]['linkedProfileId'] as String?;
        if (linked != null && linked.isEmpty) linked = null;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('حجز الحصة'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: field,
                    decoration: const InputDecoration(
                      labelText: 'اسم مستعار أو ملاحظة',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: linked ?? '',
                    decoration: const InputDecoration(
                      labelText: 'ربط بملف عائلي إن وُجد',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('بلا ربط'),
                      ),
                      for (final member in profiles.allProfiles)
                        DropdownMenuItem(
                          value: member.profileId,
                          child: Text(member.fullName),
                        ),
                    ],
                    onChanged: (value) => setLocal(() => linked = value),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    ctx,
                    '${field.text.trim()}|||${linked ?? ''}',
                  ),
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
    if (name == null) return;
    final parts = name.split('|||');
    final alias = parts.isEmpty ? '' : parts.first;
    final linkedId = parts.length > 1 ? parts[1] : '';
    setState(() {
      _slots[index]['booked'] = alias.isNotEmpty || linkedId.isNotEmpty;
      _slots[index]['alias'] = alias;
      _slots[index]['linkedProfileId'] = linkedId;
    });
    _persist();
    await _say('حُفظت الحصة ${_slots[index]['time']}.');
  }

  Future<void> _note(int index, {required bool exam}) async {
    final key = exam ? 'examNote' : 'doctorNote';
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final field = TextEditingController(
          text: _slots[index][key]?.toString() ?? '',
        );
        return AlertDialog(
          title: Text(exam ? 'ملاحظة الفحص' : 'رسالة تقدير خاصة'),
          content: TextField(
            controller: field,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: exam
                  ? 'ما كتبه الطبيب لهذه الحصة. ليست نتيجة مختبر.'
                  : 'أولوية ظاهرة لذوي الهمم. ليست خصماً مالياً.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, field.text.trim()),
              child: const Text('حفظ'),
            ),
          ],
        );
      },
    );
    if (value == null) return;
    setState(() => _slots[index][key] = value);
    _persist();
    await _say(exam ? 'حُفظت ملاحظة الفحص.' : 'حُفظ تقدير الحالة الخاصة.');
  }

  Future<void> _cancel(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الموعد'),
        content: Text(
          'إلغاء حصة ${_slots[index]['time']}؟ تُفرَّغ الحصة على هذا الجهاز فقط.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('لا'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _slots[index] = const ClinicEmptyBoard().emptySlot(
        index: _slots[index]['index'] as int? ?? index + 1,
        time: _slots[index]['time'] as String? ?? '',
      );
    });
    _persist();
    await _say('أُلغيت الحصة.');
  }

  Future<void> _startExam(int index) async {
    final linkedId = _slots[index]['linkedProfileId'] as String? ?? '';
    final profiles = context.read<ActiveProfileController>();
    HealthProfile? linked;
    if (linkedId.isNotEmpty) {
      linked = profiles.profileById(linkedId);
    }
    await _say(
      linked == null
          ? 'بدء فحص على هذه الحصة. الملف الصحي يُفتح إن رُبط ملف عائلي.'
          : 'بدء فحص. سأعرض ملف ${linked.fullName} دون تبديل ملف الطبيب النشط.',
    );
    if (!mounted) return;
    if (linked != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HealthProfileScreen(
            profile: linked,
            preferThisProfile: true,
          ),
        ),
      );
    }
    if (!mounted) return;
    await _note(index, exam: true);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ActiveProfileController>();
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(
        title: const Text('يومياتي — لوحة الطبيب'),
        actions: [
          IconButton(
            tooltip: _speak ? 'إيقاف النطق' : 'تشغيل النطق',
            onPressed: () {
              setState(() => _speak = !_speak);
              _say(_speak ? 'النطق مفعّل.' : 'النطق متوقف.');
            },
            icon: Icon(_speak ? Icons.volume_up : Icons.volume_off),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const HonestyBanner(
            messageAr:
                'شاشة داخلية للطبيب وحده: الإحاطات، أسماء المرضى المعتمدين، الأمراض في السي في، والحجز لمن يشاء. '
                'الصفحة العامة لا تعرض هذه القوائم.',
          ),
          ...[
            for (final notice in _store()?.list(BoxKeys.doctorNotices) ?? const [])
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(notice['title']?.toString() ?? 'إشعار'),
                  subtitle: Text(notice['detail']?.toString() ?? ''),
                ),
              ),
            for (final inbox
                in _store()?.list(BoxKeys.accreditedPatientInbox) ?? const [])
              Card(
                child: ExpansionTile(
                  title: Text(inbox['title']?.toString() ?? 'مريض'),
                  subtitle: Text(
                    'أمراض مصرّح بها: ${inbox['detail'] ?? '—'}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(inbox['cv']?.toString() ?? ''),
                    ),
                  ],
                ),
              ),
          ],
          ListTile(
            title: const Text('التاريخ'),
            subtitle: Text(_dayKey),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _day,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 800)),
              );
              if (picked == null) return;
              setState(() {
                _day = picked;
                _hydratedDay = null;
                _loadDay(force: true);
              });
            },
          ),
          ListTile(
            title: Text('ساعات العمل: $_maxPatients حصة × $_examMinutes د'),
            subtitle: const Text(
              'مثال: 12 ساعة وكل حصة 30 دقيقة = 24 حصة. اضبط العدد ومدة الفحص ثم ولّد.',
            ),
            onTap: () => _say('التحكم في العدد الأقصى للمرضى هذا اليوم.'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => setState(
                    () => _maxPatients = (_maxPatients - 1).clamp(1, 40),
                  ),
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  onPressed: () => setState(() => _maxPatients++),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          ListTile(
            title: Text('مدة الفحص: $_examMinutes دقيقة'),
            subtitle: const Text('اضغط للشرح الصوتي'),
            onTap: () => _say('مدة الفحص لكل حصة بالدقائق.'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => setState(
                    () => _examMinutes = (_examMinutes - 5).clamp(5, 60),
                  ),
                  icon: const Icon(Icons.remove),
                ),
                IconButton(
                  onPressed: () => setState(() => _examMinutes += 5),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          DropdownButtonFormField<int>(
            value: _startHour,
            decoration: const InputDecoration(labelText: 'وقت بدء العمل'),
            items: const [
              DropdownMenuItem(value: 9, child: Text('09:00 صباحاً')),
              DropdownMenuItem(value: 17, child: Text('17:00 مساءً')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _startHour = value);
            },
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _generate,
            child: const Text('توليد الجدول الفارغ'),
          ),
          SwitchListTile(
            title: const Text('موافقة مراجعة الصيدلية'),
            subtitle: const Text(
              'إذن محلي ليراجع صيدلي سجلاً لاحقاً. ليست شبكة صيدليات حية.',
            ),
            value: _pharmacyReview,
            onChanged: (value) {
              setState(() => _pharmacyReview = value);
              _persist();
              _say(
                PharmacyReviewGate(
                  enabled: value,
                  namedPharmaciesAr: _pharmacyNames.text,
                ).spokenAr(),
              );
            },
          ),
          TextField(
            controller: _pharmacyNames,
            enabled: _pharmacyReview,
            decoration: const InputDecoration(
              labelText: 'صيدليات مسمّاة للتقييد المحلي',
              hintText: 'أسماء تفصلها فاصلة. ليست دليلاً حياً.',
            ),
            onChanged: (_) => _persist(),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'إحصاء اليوم $_dayKey',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('محجوز: ${stats.booked}'),
                  Text('متاح: ${stats.free}'),
                  Text('حالات خاصة: ${stats.special}'),
                  TextButton(
                    onPressed: () => _say(stats.spokenAr()),
                    child: const Text('نطق الإحصاء'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'جدول حجوزات: $_dayKey',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_slots.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'حدّد التاريخ ثم توليد الجدول. القائمة تبقى فارغة حتى تحجز أنت.',
              ),
            )
          else
            for (var i = 0; i < _slots.length; i++)
              _slotCard(i),
        ],
      ),
    );
  }

  Widget _slotCard(int i) {
    final slot = _slots[i];
    final booked = slot['booked'] == true;
    final special = slot['specialNeeds'] == true;
    final mark = ClinicSlotMark(booked: booked, specialNeeds: special);
    final alias = slot['alias'] as String? ?? '';
    return Card(
      color: special ? Colors.orange.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            ListTile(
              title: Text('${slot['time']} — ${mark.badgeAr()}'),
              subtitle: Text(
                booked
                    ? (alias.isEmpty ? 'محجوز' : alias)
                    : 'حصة ${slot['index']}',
              ),
              trailing: Chip(
                label: Text(mark.badgeAr()),
                backgroundColor: special
                    ? Theme.of(context).colorScheme.error.withOpacity(0.25)
                    : booked
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                        : Theme.of(context).colorScheme.secondary.withOpacity(0.2),
              ),
              onTap: () => _say(
                mark.spokenAr(
                  time: slot['time'] as String? ?? '',
                  alias: alias,
                ),
              ),
            ),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => _book(i),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('حجز'),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _slots[i]['specialNeeds'] = !special;
                    });
                    _persist();
                    _say(
                      !special
                          ? 'وُسمت حالة خاصة. التقدير يظهر للطبيب فقط.'
                          : 'أُزيل وسم الحالة الخاصة.',
                    );
                  },
                  icon: Icon(
                    Icons.accessible,
                    color: special ? Colors.orange : null,
                  ),
                  label: const Text('حالة خاصة'),
                ),
                if (special)
                  TextButton.icon(
                    onPressed: () => _note(i, exam: false),
                    icon: const Icon(Icons.favorite_outline),
                    label: const Text('تقدير خاص'),
                  ),
                TextButton.icon(
                  onPressed: booked ? () => _startExam(i) : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('بدء فحص'),
                ),
                TextButton.icon(
                  onPressed: booked ? () => _cancel(i) : null,
                  icon: const Icon(Icons.close),
                  label: const Text('إلغاء'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
