/// برمجة المنبهات الناطقة المرتبطة بمكان الجهاز.
library lifex_ai.screens.speaking_alarm_screen;

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../features/clock/speaking_alarm_book.dart';
import '../features/location/device_location_reader.dart';
import '../widgets/lifex_record_edit.dart';

class SpeakingAlarmScreen extends StatefulWidget {
  const SpeakingAlarmScreen({super.key});

  @override
  State<SpeakingAlarmScreen> createState() => _SpeakingAlarmScreenState();
}

class _SpeakingAlarmScreenState extends State<SpeakingAlarmScreen> {
  final _book = const SpeakingAlarmBook();
  final _name = TextEditingController();
  List<SpeakingAlarm> _alarms = const [];
  int _hour = TimeOfDay.now().hour;
  int _minute = TimeOfDay.now().minute;
  double _radius = 200;
  double? _latitude;
  double? _longitude;
  String? _editingId;
  String _placeNote = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final alarms = await _book.load();
    if (!mounted) return;
    setState(() => _alarms = alarms);
  }

  Future<void> _capturePlace() async {
    setState(() => _busy = true);
    final read = await const DeviceLocationReader().read();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _latitude = read.fix?.latitude;
      _longitude = read.fix?.longitude;
      _placeNote = read.hasFix
          ? lifexUi(
              'حُفظت إحداثيات الجهاز. بلا اسم شارع.',
              'The device coordinates were saved. No street name.',
            )
          : read.messageAr;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final latitude = _latitude;
    final longitude = _longitude;
    if (name.isEmpty || latitude == null || longitude == null) {
      setState(() {
        _placeNote = lifexUi(
          'اكتب اسماً واحفظ المكان الحالي قبل التسجيل.',
          'Write a name and save the current place before storing the alarm.',
        );
      });
      return;
    }
    final alarm = SpeakingAlarm(
      id: _editingId ?? 'alm-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      hour: _hour,
      minute: _minute,
      enabled: true,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: _radius,
    );
    final next = [..._alarms.where((item) => item.id != alarm.id), alarm];
    await _book.save(next);
    if (!mounted) return;
    setState(() {
      _alarms = next;
      _editingId = null;
      _name.clear();
      _latitude = null;
      _longitude = null;
      _placeNote = lifexUi('حُفظ المنبه.', 'The alarm is saved.');
    });
  }

  void _edit(SpeakingAlarm alarm) {
    setState(() {
      _editingId = alarm.id;
      _name.text = alarm.name;
      _hour = alarm.hour;
      _minute = alarm.minute;
      _radius = alarm.radiusMeters;
      _latitude = alarm.latitude;
      _longitude = alarm.longitude;
      _placeNote = lifexUi(
        'المكان المحفوظ جاهز. يمكنك تحديثه من موقعك الآن.',
        'The saved place is ready. You can refresh it from where you are now.',
      );
    });
  }

  Future<void> _toggle(SpeakingAlarm alarm, bool enabled) async {
    final next = [
      for (final item in _alarms)
        if (item.id == alarm.id) item.copyWith(enabled: enabled) else item,
    ];
    await _book.save(next);
    if (!mounted) return;
    setState(() => _alarms = next);
  }

  Future<void> _remove(SpeakingAlarm alarm) async {
    final next = _alarms.where((item) => item.id != alarm.id).toList();
    await _book.save(next);
    if (!mounted) return;
    setState(() => _alarms = next);
  }

  @override
  Widget build(BuildContext context) {
    String two(int value) => value.toString().padLeft(2, '0');
    return Scaffold(
      appBar: AppBar(
        title: Text(lifexUi('منبهات الساعة', 'Clock alarms')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(lifexUi(
            'المنبه ينطق واسمُه يظهر ما دام التطبيق مفتوحاً. المكان إحداثيات الجهاز ضمن النطاق، بلا عنوان شارع وبلا جرعة.',
            'The alarm speaks its name while the app is open. The place is the device coordinates inside the range, with no street address and no dose.',
          )),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              labelText: lifexUi('اسم المنبه', 'Alarm name'),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _hour,
                  decoration: InputDecoration(
                    labelText: lifexUi('الساعة', 'Hour'),
                  ),
                  items: [
                    for (var hour = 0; hour < 24; hour++)
                      DropdownMenuItem(value: hour, child: Text(two(hour))),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _hour = value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _minute,
                  decoration: InputDecoration(
                    labelText: lifexUi('الدقيقة', 'Minute'),
                  ),
                  items: [
                    for (var minute = 0; minute < 60; minute++)
                      DropdownMenuItem(value: minute, child: Text(two(minute))),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _minute = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(lifexUi(
            'النطاق ${_radius.round()} متر',
            'Range ${_radius.round()} meters',
          )),
          Slider(
            value: _radius,
            min: 50,
            max: 2000,
            divisions: 39,
            label: '${_radius.round()}',
            onChanged: (value) => setState(() => _radius = value),
          ),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _capturePlace,
            icon: const Icon(Icons.my_location),
            label: Text(lifexUi('احفظ مكاني الحالي', 'Save where I am now')),
          ),
          if (_placeNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_placeNote),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _save,
            child: Text(_editingId == null
                ? lifexUi('إضافة المنبه', 'Add alarm')
                : lifexUi('حفظ التعديل', 'Save edit')),
          ),
          const SizedBox(height: 16),
          if (_alarms.isEmpty)
            Text(lifexUi('لا منبهات محفوظة.', 'No saved alarms.'))
          else
            for (final alarm in _alarms)
              Card(
                child: ListTile(
                  title: Text(alarm.name),
                  subtitle: Text(
                    '${two(alarm.hour)}:${two(alarm.minute)} · '
                    '${alarm.radiusMeters.round()} m',
                  ),
                  leading: Switch(
                    value: alarm.enabled,
                    onChanged: (value) => _toggle(alarm, value),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LifexRecordEditButton(onPressed: () => _edit(alarm)),
                      IconButton(
                        tooltip: lifexUi('حذف', 'Delete'),
                        onPressed: () => _remove(alarm),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
