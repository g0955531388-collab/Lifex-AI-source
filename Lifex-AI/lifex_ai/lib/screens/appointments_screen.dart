/// =============================================================
/// Lifex-AI — مواعيد محلية مع تقويم شهر/أسبوع/يوم
/// الملف: appointments_screen.dart
/// Calendar-first. Appointment ≠ Encounter.
/// =============================================================
library lifex_ai.screens.appointments_screen;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import '../features/profile/active_profile_controller.dart';
import '../features/scheduling/user_appointment_store.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/accessible_widgets.dart';

enum _CalendarView { month, week, day }

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late UserAppointmentStore _store;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  _CalendarView _view = _CalendarView.month;
  String _lastSpoken = '';

  @override
  void initState() {
    super.initState();
    final raw = context
        .read<ActiveProfileController>()
        .activeProfile
        ?.questionnaireData['appointments'];
    _store = UserAppointmentStore.fromMaps(raw is List ? raw : null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announce(_store.spokenMonthSummaryAr(_visibleMonth));
    });
  }

  void _persist() {
    final controller = context.read<ActiveProfileController>();
    final profile = controller.activeProfile;
    if (profile == null) return;
    profile.questionnaireData['appointments'] = _store.toMaps();
    profile.lastUpdatedAt = DateTime.now();
    controller.saveActiveProfileChanges();
  }

  Future<void> _announce(String message) async {
    setState(() => _lastSpoken = message);
    if (!mounted) return;
    SemanticsService.announce(message, Directionality.of(context));
    announceForScreenReader(context, message);
    await VoiceEngine.instance.speak(message);
  }

  Future<void> _addOrEdit({UserAppointment? existing}) async {
    final profile = context.read<ActiveProfileController>().activeProfile;
    if (profile == null) {
      await _announce(
        'EMPTY — لا يوجد ملف صحي نشط. أنشئ ملفاً ثم أضف موعداً.',
      );
      return;
    }
    final result = await showDialog<UserAppointment>(
      context: context,
      builder: (_) => _AppointmentWizard(
        initial: existing,
        initialDate: _selectedDay,
      ),
    );
    if (result == null) return;
    setState(() {
      if (existing != null) {
        _store.update(existing.id, result);
      } else {
        _store.add(result);
      }
    });
    _persist();
    await _announce(
      existing == null
          ? 'تم إنشاء الموعد. ${result.spokenSummaryAr()}'
          : 'تم تعديل الموعد. ${result.spokenSummaryAr()}',
    );
  }

  Future<void> _remove(UserAppointment a) async {
    final action = _store.removeOrCancel(a.id);
    setState(() {});
    _persist();
    if (action == 'deleted') {
      await _announce('تم حذف الموعد.');
    } else if (action == 'cancelled_request') {
      await _announce(
        'هذا موعد جهة خارجية. سُجّل طلب إلغاء بدل الحذف المباشر.',
      );
    }
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDay = DateTime(now.year, now.month, now.day);
      _visibleMonth = DateTime(now.year, now.month);
    });
    _announce(_store.spokenDayAr(_selectedDay));
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ActiveProfileController>().activeProfile;
    final dayItems = _store.forDay(_selectedDay);
    final dayLabel =
        'مواعيد ${_selectedDay.year}/${_selectedDay.month}/${_selectedDay.day} — '
        '${dayItems.isEmpty ? 'لا مواعيد' : '${dayItems.length} موعد'}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('مواعيدي'),
        actions: [
          IconButton(
            tooltip: 'اقرأ مواعيد اليوم',
            onPressed: () => _announce(_store.spokenDayAr(_selectedDay)),
            icon: const Icon(Icons.record_voice_over_outlined),
          ),
          IconButton(
            tooltip: 'اليوم',
            onPressed: _goToday,
            icon: const Icon(Icons.today_outlined),
          ),
          PopupMenuButton<_CalendarView>(
            tooltip: 'تغيير العرض',
            initialValue: _view,
            onSelected: (v) => setState(() => _view = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _CalendarView.month, child: Text('شهر')),
              PopupMenuItem(value: _CalendarView.week, child: Text('أسبوع')),
              PopupMenuItem(value: _CalendarView.day, child: Text('يوم')),
            ],
            icon: const Icon(Icons.calendar_view_month),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة موعد'),
      ),
      body: profile == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'EMPTY — وحدة المواعيد متاحة.\n'
                  'لا يوجد ملف صحي نشط. أنشئ ملفاً من الشاشة الرئيسية لحفظ المواعيد.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                if (_lastSpoken.isNotEmpty)
                  LiveAnnouncingText(
                    message: _lastSpoken,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (_view == _CalendarView.month) _buildMonthGrid(),
                if (_view == _CalendarView.week) _buildWeekStrip(),
                if (_view == _CalendarView.day)
                  ListTile(
                    title: Text(dayLabel),
                    subtitle: const Text('عرض يومي'),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: dayItems.isEmpty
                      ? Center(
                          child: Semantics(
                            label: dayLabel,
                            child: const Text(
                              'EMPTY — لا مواعيد في هذا اليوم.\n'
                              'اضغط إضافة موعد أو اختر يوماً آخر.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: dayItems.length,
                          itemBuilder: (context, i) {
                            final appointment = dayItems[i];
                            return Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.event),
                                ),
                                title: Text(
                                  '${appointment.timeHm} ${appointment.title}'
                                      .trim(),
                                ),
                                subtitle: Text(
                                  '${appointment.type} — ${appointment.place}\n'
                                  'تذكير: ${appointment.reminderMinutes} د '
                                  '· ${appointment.recurrence.name} '
                                  '· ${appointment.source.name}',
                                ),
                                isThreeLine: true,
                                onTap: appointment.canDirectEdit
                                    ? () => _addOrEdit(existing: appointment)
                                    : () => _announce(
                                          'هذا الموعد غير قابل للتعديل المباشر. يمكن طلب تغيير حسب السياسة.',
                                        ),
                                trailing: IconButton(
                                  tooltip: appointment.canDirectDelete
                                      ? 'حذف الموعد المحلي'
                                      : 'طلب إلغاء',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _remove(appointment),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildMonthGrid() {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final startWeekday = first.weekday % 7;
    final cells = <Widget>[];
    for (var i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_visibleMonth.year, _visibleMonth.month, d);
      final count = _store.countOn(day);
      final selected = day.year == _selectedDay.year &&
          day.month == _selectedDay.month &&
          day.day == _selectedDay.day;
      cells.add(
        Semantics(
          button: true,
          label:
              '${day.day} ${_monthNameAr(day.month)}، ${count == 0 ? 'بلا مواعيد' : 'يحتوي على $count موعد'}',
          child: InkWell(
            onTap: () {
              setState(() => _selectedDay = day);
              _announce(_store.spokenDayAr(day));
            },
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: selected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                borderRadius: BorderRadius.circular(8),
                border: count > 0
                    ? Border.all(color: Theme.of(context).colorScheme.primary)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('$d'),
                  if (count > 0)
                    Text('•$count', style: const TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'الشهر السابق',
              onPressed: () {
                setState(() {
                  _visibleMonth =
                      DateTime(_visibleMonth.year, _visibleMonth.month - 1);
                });
                _announce(_store.spokenMonthSummaryAr(_visibleMonth));
              },
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${_monthNameAr(_visibleMonth.month)} ${_visibleMonth.year}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'الشهر التالي',
              onPressed: () {
                setState(() {
                  _visibleMonth =
                      DateTime(_visibleMonth.year, _visibleMonth.month + 1);
                });
                _announce(_store.spokenMonthSummaryAr(_visibleMonth));
              },
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          children: cells,
        ),
      ],
    );
  }

  Widget _buildWeekStrip() {
    final start =
        _selectedDay.subtract(Duration(days: _selectedDay.weekday % 7));
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, i) {
          final day = DateTime(start.year, start.month, start.day + i);
          final selected = day.year == _selectedDay.year &&
              day.month == _selectedDay.month &&
              day.day == _selectedDay.day;
          final count = _store.countOn(day);
          return Padding(
            padding: const EdgeInsets.all(4),
            child: ChoiceChip(
              selected: selected,
              label: Text('${day.day}${count > 0 ? ' ($count)' : ''}'),
              onSelected: (_) {
                setState(() {
                  _selectedDay = day;
                  _visibleMonth = DateTime(day.year, day.month);
                });
                _announce(_store.spokenDayAr(day));
              },
            ),
          );
        },
      ),
    );
  }

  String _monthNameAr(int m) {
    const names = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return names[m];
  }
}

class _AppointmentWizard extends StatefulWidget {
  const _AppointmentWizard({this.initial, required this.initialDate});

  final UserAppointment? initial;
  final DateTime initialDate;

  @override
  State<_AppointmentWizard> createState() => _AppointmentWizardState();
}

class _AppointmentWizardState extends State<_AppointmentWizard> {
  late final TextEditingController _title;
  late final TextEditingController _place;
  late final TextEditingController _time;
  late final TextEditingController _notes;
  late DateTime _date;
  String _type = 'doctor';
  String _timezone = 'local';
  int _reminder = 30;
  AppointmentRecurrence _recurrence = AppointmentRecurrence.none;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _title = TextEditingController(text: i?.title ?? '');
    _place = TextEditingController(text: i?.place ?? '');
    _time = TextEditingController(text: i?.timeHm ?? '09:00');
    _notes = TextEditingController(text: i?.notes ?? '');
    _type = i?.type ?? 'doctor';
    _timezone = i?.timezone ?? 'local';
    _reminder = i?.reminderMinutes ?? 30;
    _recurrence = i?.recurrence ?? AppointmentRecurrence.none;
    _date = i?.date ?? widget.initialDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _time.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'إضافة موعد' : 'تعديل موعد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'العنوان'),
            ),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'النوع'),
              items: const [
                DropdownMenuItem(value: 'doctor', child: Text('طبيب')),
                DropdownMenuItem(value: 'hospital', child: Text('مستشفى')),
                DropdownMenuItem(value: 'laboratory', child: Text('مختبر')),
                DropdownMenuItem(value: 'imaging', child: Text('تصوير')),
                DropdownMenuItem(value: 'pharmacy', child: Text('صيدلية')),
                DropdownMenuItem(value: 'dentistry', child: Text('أسنان')),
                DropdownMenuItem(value: 'rehabilitation', child: Text('تأهيل')),
                DropdownMenuItem(value: 'blood', child: Text('دم')),
                DropdownMenuItem(value: 'telehealth', child: Text('عن بُعد')),
                DropdownMenuItem(value: 'follow_up', child: Text('متابعة')),
                DropdownMenuItem(value: 'device_service', child: Text('خدمة جهاز')),
                DropdownMenuItem(value: 'other', child: Text('أخرى')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'other'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'التاريخ: ${_date.toIso8601String().split('T').first}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
            ),
            TextField(
              controller: _time,
              decoration: const InputDecoration(
                labelText: 'الوقت (HH:mm)',
                hintText: '09:00',
              ),
            ),
            TextField(
              controller: _place,
              decoration: const InputDecoration(labelText: 'المكان / الجهة'),
            ),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'ملاحظات'),
            ),
            DropdownButtonFormField<int>(
              value: _reminder,
              decoration: const InputDecoration(labelText: 'التذكير قبل'),
              items: const [
                DropdownMenuItem(value: 5, child: Text('5 دقائق')),
                DropdownMenuItem(value: 15, child: Text('15 دقيقة')),
                DropdownMenuItem(value: 30, child: Text('30 دقيقة')),
                DropdownMenuItem(value: 60, child: Text('ساعة')),
                DropdownMenuItem(value: 1440, child: Text('يوم')),
              ],
              onChanged: (v) => setState(() => _reminder = v ?? 30),
            ),
            DropdownButtonFormField<AppointmentRecurrence>(
              value: _recurrence,
              decoration: const InputDecoration(labelText: 'التكرار'),
              items: AppointmentRecurrence.values
                  .map(
                    (r) => DropdownMenuItem(value: r, child: Text(r.name)),
                  )
                  .toList(),
              onChanged: (v) =>
                  setState(() => _recurrence = v ?? AppointmentRecurrence.none),
            ),
            DropdownButtonFormField<String>(
              value: _timezone,
              decoration: const InputDecoration(labelText: 'المنطقة الزمنية'),
              items: const [
                DropdownMenuItem(value: 'local', child: Text('توقيت الجهاز')),
                DropdownMenuItem(value: 'UTC', child: Text('UTC')),
                DropdownMenuItem(
                  value: 'Asia/Damascus',
                  child: Text('Asia/Damascus'),
                ),
              ],
              onChanged: (v) => setState(() => _timezone = v ?? 'local'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty) return;
            final id = widget.initial?.id ??
                'apt_${DateTime.now().millisecondsSinceEpoch}';
            Navigator.pop(
              context,
              UserAppointment(
                id: id,
                title: _title.text.trim(),
                place: _place.text.trim(),
                dateIso: DateTime(_date.year, _date.month, _date.day)
                    .toIso8601String()
                    .split('T')
                    .first,
                timeHm: _time.text.trim(),
                type: _type,
                timezone: _timezone,
                notes: _notes.text.trim(),
                reminderMinutes: _reminder,
                recurrence: _recurrence,
                status: AppointmentLifecycle.confirmed,
                source: widget.initial?.source ??
                    AppointmentSourceOwnership.userCreated,
                providerId: widget.initial?.providerId,
              ),
            );
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
