/// برمجة المنبهات الناطقة المرتبطة بمكان الجهاز.
library lifex_ai.screens.speaking_alarm_screen;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../features/clock/clock_chime.dart';
import '../features/clock/speaking_alarm_book.dart';
import '../features/location/device_location_reader.dart';
import '../features/voice/user_ringtone_desk.dart';
import '../widgets/lifex_record_edit.dart';
import '../widgets/lifex_text.dart';

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
  ChimeOrder _order = ChimeOrder.speechOnly;
  String _toneUri = BuiltInTone.classicBell.ref;
  String _toneTitle = '';
  ClockChimeSettings _chime = const ClockChimeSettings();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _name.dispose();
    unawaited(ClockTonePlayer.instance.stop());
    super.dispose();
  }

  Future<void> _reload() async {
    final alarms = await _book.load();
    final chime = await ClockChimeSettings.load();
    if (!mounted) return;
    setState(() {
      _alarms = alarms;
      _chime = chime;
    });
  }

  Future<void> _saveChime(ClockChimeSettings next) async {
    setState(() => _chime = next);
    await next.save();
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
      speechCue: _order.usesSpeech || _toneUri.trim().isEmpty,
      toneUri: _order.usesTone ? _toneUri : '',
      toneTitle: _order.usesTone ? _toneTitle : '',
      cueOrder: _order,
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
      _order = alarm.order;
      if (alarm.toneUri.trim().isNotEmpty) {
        _toneUri = alarm.toneUri;
        _toneTitle = alarm.toneTitle;
      }
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
        title: LifexText(lifexUi('منبهات الساعة', 'Clock alarms')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          LifexText(lifexUi(
            'المنبه ينطق أو يرن بنغمة واسمُه يظهر ما دام التطبيق مفتوحاً. المكان إحداثيات الجهاز ضمن النطاق، بلا عنوان شارع وبلا جرعة.',
            'The alarm speaks or rings a tone and shows its name while the app is open. The place is the device coordinates inside the range, with no street address and no dose.',
          )),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LifexText(
                    lifexUi('إعلان الوقت عند لمس الساعة',
                        'Time announcement when the clock is tapped'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _OrderField(
                    value: _chime.order,
                    orders: ChimeOrder.values,
                    onChanged: (order) =>
                        _saveChime(_chime.copyWith(order: order)),
                  ),
                  if (_chime.order.usesTone) ...[
                    const SizedBox(height: 8),
                    _ToneChooser(
                      toneRef: _chime.toneRef,
                      toneTitle: _chime.toneTitle,
                      volume: _chime.volume,
                      onChanged: (ref, title) => _saveChime(
                          _chime.copyWith(toneRef: ref, toneTitle: title)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  LifexText(lifexUi(
                    'مستوى صوت النغمة ${(_chime.volume * 100).round()}٪ — منفصل عن صوت النطق، ويستعمله المنبه أيضاً.',
                    'Tone volume ${(_chime.volume * 100).round()}% — separate from the speech volume, also used by alarms.',
                  )),
                  Slider(
                    value: _chime.volume,
                    min: 0.1,
                    max: 1,
                    divisions: 9,
                    label: '${(_chime.volume * 100).round()}',
                    onChanged: (value) =>
                        setState(() => _chime = _chime.copyWith(volume: value)),
                    onChangeEnd: (value) =>
                        _saveChime(_chime.copyWith(volume: value)),
                  ),
                ],
              ),
            ),
          ),
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
                      DropdownMenuItem(value: hour, child: LifexText(two(hour))),
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
                      DropdownMenuItem(value: minute, child: LifexText(two(minute))),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _minute = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LifexText(lifexUi(
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
          LifexText(
            lifexUi('طريقة التنبيه', 'How the alarm sounds'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          _OrderField(
            value: _order,
            orders: alarmOrders,
            onChanged: (order) => setState(() => _order = order),
          ),
          if (_order.usesTone) ...[
            const SizedBox(height: 8),
            _ToneChooser(
              toneRef: _toneUri,
              toneTitle: _toneTitle,
              volume: _chime.volume,
              onChanged: (ref, title) => setState(() {
                _toneUri = ref;
                _toneTitle = title;
              }),
            ),
          ],
          LifexText(lifexUi(
            'إيقاف النطق لا يوقف المنبه. إن تعذّر تشغيل النغمة يُنطق المنبه بدلاً منها.',
            'Turning speech off does not turn the alarm off. If the tone cannot play, the alarm is spoken instead.',
          )),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _capturePlace,
            icon: const Icon(Icons.my_location),
            label: LifexText(lifexUi('احفظ مكاني الحالي', 'Save where I am now')),
          ),
          if (_placeNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            LifexText(_placeNote),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _save,
            child: LifexText(_editingId == null
                ? lifexUi('إضافة المنبه', 'Add alarm')
                : lifexUi('حفظ التعديل', 'Save edit')),
          ),
          const SizedBox(height: 16),
          if (_alarms.isEmpty)
            LifexText(lifexUi('لا منبهات محفوظة.', 'No saved alarms.'))
          else
            for (final alarm in _alarms)
              Card(
                child: ListTile(
                  title: LifexText(alarm.name),
                  subtitle: LifexText(
                    '${two(alarm.hour)}:${two(alarm.minute)} · '
                    '${alarm.radiusMeters.round()} m · ${alarm.order.label}',
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

/// المنبه لا يُعرض عليه «إيقاف الاثنين»؛ إيقافه من مفتاحه.
const alarmOrders = [
  ChimeOrder.speechOnly,
  ChimeOrder.toneOnly,
  ChimeOrder.toneThenSpeech,
  ChimeOrder.speechThenTone,
];

class _OrderField extends StatelessWidget {
  const _OrderField({
    required this.value,
    required this.orders,
    required this.onChanged,
  });

  final ChimeOrder value;
  final List<ChimeOrder> orders;
  final ValueChanged<ChimeOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final order in orders)
          RadioListTile<ChimeOrder>(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: order,
            groupValue: orders.contains(value) ? value : orders.first,
            title: LifexText(order.label),
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
      ],
    );
  }
}

class _ToneChooser extends StatefulWidget {
  const _ToneChooser({
    required this.toneRef,
    required this.toneTitle,
    required this.volume,
    required this.onChanged,
  });

  final String toneRef;
  final String toneTitle;
  final double volume;
  final void Function(String ref, String title) onChanged;

  @override
  State<_ToneChooser> createState() => _ToneChooserState();
}

class _ToneChooserState extends State<_ToneChooser> {
  static const _deviceKey = 'device';
  var _previewing = false;

  String get _selected {
    final builtIn = BuiltInToneParts.fromRef(widget.toneRef);
    return builtIn?.ref ?? _deviceKey;
  }

  @override
  void dispose() {
    if (_previewing) unawaited(ClockTonePlayer.instance.stop());
    super.dispose();
  }

  Future<void> _choose(String? key) async {
    if (key == null) return;
    if (key != _deviceKey) {
      widget.onChanged(key, '');
      return;
    }
    final picked = await const UserRingtoneDesk().pick();
    if (picked == null || !mounted) return;
    widget.onChanged(picked.uri, picked.title);
  }

  Future<void> _preview() async {
    if (_previewing) {
      await ClockTonePlayer.instance.stop();
      if (mounted) setState(() => _previewing = false);
      return;
    }
    if (widget.toneRef.trim().isEmpty) return;
    setState(() => _previewing = true);
    final played = await ClockTonePlayer.instance
        .play(widget.toneRef, volume: widget.volume);
    if (!mounted) return;
    setState(() => _previewing = false);
    if (!played) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LifexText(lifexUi(
            'تعذّر تشغيل النغمة على هذا الجهاز.',
            'The tone could not play on this device.',
          )),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceLabel = widget.toneTitle.trim().isNotEmpty &&
            BuiltInToneParts.fromRef(widget.toneRef) == null
        ? widget.toneTitle
        : lifexUi('نغمة من نغمات الجهاز…', 'A device ringtone…');
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selected,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: lifexUi('النغمة', 'Tone'),
            ),
            items: [
              for (final tone in BuiltInTone.values)
                DropdownMenuItem(value: tone.ref, child: LifexText(tone.label)),
              DropdownMenuItem(
                value: _deviceKey,
                child: LifexText(
                  deviceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            onChanged: (key) => unawaited(_choose(key)),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: _previewing
              ? lifexUi('إيقاف التجربة', 'Stop preview')
              : lifexUi('جرّب النغمة', 'Preview tone'),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () => unawaited(_preview()),
          icon: Icon(_previewing ? Icons.stop : Icons.play_arrow),
        ),
      ],
    );
  }
}
