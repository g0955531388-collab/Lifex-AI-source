/// الدليل المهني المحلي: قائمة، ثيم التخصص، ومنبه يفتح البحث.
library lifex_ai.screens.professional_directory_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../core/studio_theme.dart';
import '../features/directory/directory_alarm.dart';
import '../features/directory/professional_directory.dart';
import '../features/location/device_location_reader.dart';
import '../features/profile/active_profile_controller.dart';
import '../widgets/lifex_record_edit.dart';

class ProfessionalDirectoryScreen extends StatefulWidget {
  const ProfessionalDirectoryScreen({
    super.key,
    this.initialQuery = '',
    this.highlightReason = '',
  });

  final String initialQuery;
  final String highlightReason;

  @override
  State<ProfessionalDirectoryScreen> createState() =>
      _ProfessionalDirectoryScreenState();
}

class _ProfessionalDirectoryScreenState extends State<ProfessionalDirectoryScreen> {
  final _book = const ProfessionalDirectoryBook();
  final _alarms = const DirectoryAlarmBook();
  final _query = TextEditingController();
  List<ProfessionalProfile> _profiles = const [];
  List<DirectoryAlarm> _savedAlarms = const [];

  @override
  void initState() {
    super.initState();
    _query.text = widget.initialQuery;
    _reload();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final profiles = await _book.load();
    final alarms = await _alarms.load();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _savedAlarms = alarms;
    });
  }

  String get _userId {
    final id = context.read<ActiveProfileController>().activeProfileId;
    if (id == null || id.trim().isEmpty) return 'local';
    return id;
  }

  Future<void> _editProfile([ProfessionalProfile? current]) async {
    final result = await showDialog<ProfessionalProfile>(
      context: context,
      builder: (_) => _ProfileDialog(current: current),
    );
    if (result == null) return;
    final next = [
      for (final profile in _profiles)
        if (profile.id != result.id) profile,
      result,
    ];
    await _book.save(next);
    if (!mounted) return;
    setState(() => _profiles = next);
  }

  Future<void> _removeProfile(ProfessionalProfile profile) async {
    final next = _profiles.where((item) => item.id != profile.id).toList();
    await _book.save(next);
    if (!mounted) return;
    setState(() => _profiles = next);
  }

  Future<void> _addAlarm() async {
    final draft = await showDialog<_AlarmDraft>(
      context: context,
      builder: (_) => _AlarmDialog(profiles: _profiles),
    );
    if (draft == null || !mounted) return;
    final alarm = newDirectoryAlarm(
      id: 'dir-${DateTime.now().millisecondsSinceEpoch}',
      userId: _userId,
      targetNameOrKeyword: draft.target,
      targetProfessionalId: draft.profileId,
      scheduled: draft.when,
      reason: draft.reason,
      now: DateTime.now(),
    );
    if (alarm == null) return;
    final next = [..._savedAlarms, alarm];
    await _alarms.save(next);
    if (!mounted) return;
    setState(() => _savedAlarms = next);
  }

  @override
  Widget build(BuildContext context) {
    final shown = searchProfessionals(_profiles, _query.text);
    final arabic = AppConfig.instance.defaultLanguage != AppLanguage.english;
    return Scaffold(
      appBar: AppBar(
        title: Text(lifexUi('الدليل المهني', 'Professional directory')),
      ),
      body: ListenableBuilder(
        listenable: StudioThemeController.instance,
        builder: (context, _) {
          final appearance = AppConfig.instance.appearance;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(lifexUi(
                'دليل محلي على هذا الجهاز. ليس حجزاً مؤكداً ولا تشخيصاً. التجربة المجانية 48 ساعة، والدفع لا يُرسل من غير تأكيد مرخّص.',
                'A local directory on this device. It is not a confirmed booking or a diagnosis. The free trial is 48 hours, and payment is not sent without licensed confirmation.',
              )),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: StudioThemeController.instance.cycleAppearance,
                icon: const Icon(Icons.contrast),
                label: Text(_appearanceLabel(appearance, arabic)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: lifexUi('بحث بالاسم أو التخصص أو المدينة', 'Search by name, specialty, or city'),
                ),
              ),
              if (widget.highlightReason.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(lifexUi(
                  'سبب التنبيه: ${widget.highlightReason}',
                  'Alarm reason: ${widget.highlightReason}',
                )),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: () => _editProfile(),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: Text(lifexUi('إضافة مهني', 'Add a professional')),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _addAlarm,
                    icon: const Icon(Icons.alarm),
                    label: Text(lifexUi('منبه الدليل', 'Directory alarm')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (shown.isEmpty)
                Text(lifexUi('لا نتائج محفوظة.', 'No saved results.'))
              else
                for (final profile in shown) _profileCard(profile),
              const SizedBox(height: 16),
              Text(
                lifexUi('منبهات الدليل', 'Directory alarms'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(lifexUi(
                'التذكير قبل ساعتين وقبل ساعة، ثم البحث عند الوقت، ما دام التطبيق مفتوحاً. إغلاق التطبيق لا يفتحه وحده.',
                'A reminder two hours before, one hour before, then search at the time, while the app is open. Closing the app does not open it by itself.',
              )),
              if (_savedAlarms.isEmpty)
                Text(lifexUi('لا منبهات للدليل.', 'No directory alarms.'))
              else
                for (final alarm in _savedAlarms) _alarmTile(alarm),
            ],
          );
        },
      ),
    );
  }

  Widget _profileCard(ProfessionalProfile profile) {
    final theme = directoryThemeById(profile.themeId);
    final arabic = AppConfig.instance.defaultLanguage != AppLanguage.english;
    final now = DateTime.now();
    final active = profile.listingActive(now);
    final tint = _themeColor(profile.themeId);
    return Card(
      color: tint.withOpacity(0.16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: tint,
          child: Icon(_themeIcon(profile.themeId), color: Colors.black),
        ),
        title: Text(profile.fullName),
        subtitle: Text(
          '${arabic ? theme.nameAr : theme.nameEn} · ${profile.specialty}\n'
          '${profile.city.isEmpty ? profile.country : profile.city}'
          '${profile.point == null ? '' : ' · ${lifexUi('إحداثيات محفوظة', 'coordinates saved')}'}\n'
          '${active ? lifexUi('التجربة أو الإدراج سارٍ حتى', 'Trial or listing runs until') : lifexUi('الإدراج منتهٍ', 'Listing ended')} '
          '${_stamp(profile.expiry)}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LifexRecordEditButton(onPressed: () => _editProfile(profile)),
            IconButton(
              tooltip: lifexUi('حذف', 'Delete'),
              onPressed: () => _removeProfile(profile),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alarmTile(DirectoryAlarm alarm) {
    String two(int value) => value.toString().padLeft(2, '0');
    final when = alarm.scheduled.toLocal();
    return Card(
      child: ListTile(
        title: Text(alarm.reason),
        subtitle: Text(
          '${alarm.targetNameOrKeyword}\n'
          '${when.year}-${two(when.month)}-${two(when.day)} '
          '${two(when.hour)}:${two(when.minute)} · ${alarm.status.name}',
        ),
        isThreeLine: true,
      ),
    );
  }

  String _stamp(DateTime value) {
    final local = value.toLocal();
    String two(int item) => item.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}

String _appearanceLabel(StudioAppearance appearance, bool arabic) {
  switch (appearance) {
    case StudioAppearance.light:
      return arabic ? 'المظهر: نهاري' : 'Appearance: light';
    case StudioAppearance.dark:
      return arabic ? 'المظهر: ليلي' : 'Appearance: dark';
    case StudioAppearance.contrast:
      return arabic ? 'المظهر: تباين عالٍ' : 'Appearance: high contrast';
  }
}

Color _themeColor(String id) {
  switch (id) {
    case 'medical':
      return const Color(0xFF7DCEC4);
    case 'legal':
      return const Color(0xFF9BB1D4);
    case 'engineering':
      return const Color(0xFFB0B7C3);
    case 'education':
      return const Color(0xFFE6C36A);
    case 'consulting':
      return const Color(0xFFC4B0E0);
    case 'crafts':
      return const Color(0xFFC4A484);
    case 'grooming':
      return const Color(0xFFE7B4C4);
    case 'care':
      return const Color(0xFF9FCBB0);
    case 'trade':
      return const Color(0xFFE0B089);
    default:
      return const Color(0xFFC5C8CE);
  }
}

IconData _themeIcon(String id) {
  switch (id) {
    case 'medical':
      return Icons.monitor_heart_outlined;
    case 'legal':
      return Icons.balance_outlined;
    case 'engineering':
      return Icons.architecture_outlined;
    case 'education':
      return Icons.school_outlined;
    case 'consulting':
      return Icons.forum_outlined;
    case 'crafts':
      return Icons.handyman_outlined;
    case 'grooming':
      return Icons.content_cut;
    case 'care':
      return Icons.favorite_outline;
    case 'trade':
      return Icons.storefront_outlined;
    default:
      return Icons.badge_outlined;
  }
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({this.current});

  final ProfessionalProfile? current;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _name;
  late final TextEditingController _specialty;
  late final TextEditingController _country;
  late final TextEditingController _city;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _whatsapp;
  late final TextEditingController _email;
  late String _category;
  late String _themeId;
  DirectoryPoint? _point;
  String _placeNote = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _name = TextEditingController(text: current?.fullName ?? '');
    _specialty = TextEditingController(text: current?.specialty ?? '');
    _country = TextEditingController(text: current?.country ?? '');
    _city = TextEditingController(text: current?.city ?? '');
    _address = TextEditingController(text: current?.address ?? '');
    _phone = TextEditingController(text: current?.phone ?? '');
    _whatsapp = TextEditingController(text: current?.whatsapp ?? '');
    _email = TextEditingController(text: current?.email ?? '');
    _category = current?.category ?? ProfessionCategory.general;
    _themeId = current?.themeId ?? 'general';
    _point = current?.point;
  }

  @override
  void dispose() {
    _name.dispose();
    _specialty.dispose();
    _country.dispose();
    _city.dispose();
    _address.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    setState(() => _busy = true);
    final read = await const DeviceLocationReader().read();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _point = read.fix == null
          ? null
          : DirectoryPoint(
              latitude: read.fix!.latitude,
              longitude: read.fix!.longitude,
            );
      _placeNote = read.hasFix
          ? lifexUi(
              'حُفظت إحداثيات الجهاز. العنوان المكتوب لا يتحول إلى نقطة.',
              'Device coordinates were saved. Typed address is not turned into a point.',
            )
          : read.messageAr;
    });
  }

  void _save() {
    final current = widget.current;
    if (current != null) {
      final name = _name.text.trim();
      final specialty = _specialty.text.trim();
      final phone = _phone.text.trim();
      if (name.isEmpty || specialty.isEmpty || phone.isEmpty) return;
      Navigator.pop(
        context,
        current.copyWith(
          fullName: name,
          category: _category,
          specialty: specialty,
          country: _country.text.trim(),
          city: _city.text.trim(),
          address: _address.text.trim(),
          point: _point,
          clearPoint: _point == null,
          phone: phone,
          whatsapp: _whatsapp.text.trim(),
          email: _email.text.trim(),
          themeId: _themeId,
        ),
      );
      return;
    }
    final created = newProfessionalProfile(
      id: 'pro-${DateTime.now().millisecondsSinceEpoch}',
      fullName: _name.text,
      category: _category,
      specialty: _specialty.text,
      phone: _phone.text,
      now: DateTime.now(),
      country: _country.text,
      city: _city.text,
      address: _address.text,
      point: _point,
      whatsapp: _whatsapp.text,
      email: _email.text,
      themeId: _themeId,
    );
    if (created == null) return;
    Navigator.pop(context, created);
  }

  @override
  Widget build(BuildContext context) {
    final arabic = AppConfig.instance.defaultLanguage != AppLanguage.english;
    return AlertDialog(
      title: Text(lifexUi(
        widget.current == null ? 'إضافة مهني' : 'تعديل المهني',
        widget.current == null ? 'Add a professional' : 'Edit the professional',
      )),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: lifexUi('الاسم', 'Name')),
            ),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(labelText: lifexUi('الفئة', 'Category')),
              items: [
                for (final id in ProfessionCategory.all)
                  DropdownMenuItem(
                    value: id,
                    child: Text(arabic ? directoryThemeById(id).nameAr : directoryThemeById(id).nameEn),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _category = value);
              },
            ),
            TextField(
              controller: _specialty,
              decoration: InputDecoration(labelText: lifexUi('التخصص', 'Specialty')),
            ),
            TextField(
              controller: _country,
              decoration: InputDecoration(labelText: lifexUi('الدولة', 'Country')),
            ),
            TextField(
              controller: _city,
              decoration: InputDecoration(labelText: lifexUi('المدينة', 'City')),
            ),
            TextField(
              controller: _address,
              decoration: InputDecoration(labelText: lifexUi('العنوان كما يُكتب', 'Address as written')),
            ),
            TextField(
              controller: _phone,
              decoration: InputDecoration(labelText: lifexUi('الهاتف', 'Phone')),
            ),
            TextField(
              controller: _whatsapp,
              decoration: InputDecoration(
                labelText: lifexUi('واتساب محفوظ، بلا إرسال', 'Saved WhatsApp number, no send'),
              ),
            ),
            TextField(
              controller: _email,
              decoration: InputDecoration(labelText: lifexUi('البريد', 'Email')),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(lifexUi('هوية بصرية من عشرة', 'One of ten visual identities')),
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final theme in directoryThemes)
                  ChoiceChip(
                    label: Text(arabic ? theme.nameAr : theme.nameEn),
                    selected: _themeId == theme.id,
                    onSelected: (_) => setState(() => _themeId = theme.id),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _capture,
              icon: const Icon(Icons.my_location),
              label: Text(lifexUi('احفظ إحداثيات الجهاز', 'Save device coordinates')),
            ),
            if (_placeNote.isNotEmpty) Text(_placeNote),
            if (widget.current != null) ...[
              const SizedBox(height: 8),
              Text(lifexUi(
                widget.current!.isPaid
                    ? 'الحالة مدفوعة محفوظة كما هي.'
                    : 'التجربة بدأت مع الإنشاء ولا تُعاد عند التعديل.',
                widget.current!.isPaid
                    ? 'The saved paid status stays as it is.'
                    : 'The trial started at creation and is not restarted by an edit.',
              )),
              FilledButton.tonal(
                onPressed: () {
                  final attempt = refuseDirectoryPayment('shamcash');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(lifexUi(attempt.messageAr, attempt.messageEn))),
                  );
                },
                child: Text(lifexUi('شام كاش', 'Sham Cash')),
              ),
              FilledButton.tonal(
                onPressed: () {
                  final attempt = refuseDirectoryPayment('global_wallet');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(lifexUi(attempt.messageAr, attempt.messageEn))),
                  );
                },
                child: Text(lifexUi('محفظة عالمية', 'Global wallet')),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(lifexUi('إلغاء', 'Cancel')),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(lifexUi('حفظ', 'Save')),
        ),
      ],
    );
  }
}

class _AlarmDraft {
  const _AlarmDraft({
    required this.target,
    required this.reason,
    required this.when,
    required this.profileId,
  });

  final String target;
  final String reason;
  final DateTime when;
  final String profileId;
}

class _AlarmDialog extends StatefulWidget {
  const _AlarmDialog({required this.profiles});

  final List<ProfessionalProfile> profiles;

  @override
  State<_AlarmDialog> createState() => _AlarmDialogState();
}

class _AlarmDialogState extends State<_AlarmDialog> {
  final _target = TextEditingController();
  final _reason = TextEditingController();
  DateTime _day = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String _profileId = '';

  @override
  void dispose() {
    _target.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() => _day = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
  }

  void _save() {
    final target = _target.text.trim();
    final reason = _reason.text.trim();
    if (target.isEmpty || reason.isEmpty) return;
    final when = DateTime(_day.year, _day.month, _day.day, _time.hour, _time.minute);
    Navigator.pop(
      context,
      _AlarmDraft(
        target: target,
        reason: reason,
        when: when,
        profileId: _profileId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(lifexUi('منبه الدليل', 'Directory alarm')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _target,
              decoration: InputDecoration(
                labelText: lifexUi('الاسم أو التخصص المطلوب', 'Name or specialty to find'),
              ),
            ),
            TextField(
              controller: _reason,
              decoration: InputDecoration(
                labelText: lifexUi('سبب التنبيه', 'Alarm reason'),
              ),
            ),
            if (widget.profiles.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _profileId,
                decoration: InputDecoration(
                  labelText: lifexUi('ربط بمهني محفوظ، اختياري', 'Link a saved professional, optional'),
                ),
                items: [
                  DropdownMenuItem(
                    value: '',
                    child: Text(lifexUi('بلا ربط', 'No link')),
                  ),
                  for (final profile in widget.profiles)
                    DropdownMenuItem(
                      value: profile.id,
                      child: Text(profile.fullName),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _profileId = value;
                    if (value.isNotEmpty && _target.text.trim().isEmpty) {
                      final match = widget.profiles.where((item) => item.id == value);
                      if (match.isNotEmpty) _target.text = match.first.fullName;
                    }
                  });
                },
              ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _pickDay,
              child: Text(lifexUi('اختر التاريخ', 'Choose the date')),
            ),
            FilledButton.tonal(
              onPressed: _pickTime,
              child: Text(lifexUi('اختر الوقت', 'Choose the time')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(lifexUi('إلغاء', 'Cancel')),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(lifexUi('حفظ', 'Save')),
        ),
      ],
    );
  }
}
