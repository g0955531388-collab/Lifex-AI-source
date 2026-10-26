/// ساعة الجهاز المحلية. الوقت من DateTime.now، بلا نشاط أندرويد.
library lifex_ai.widgets.device_wall_clock;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/i18n/lifex_i18n.dart';
import '../features/voice/voice_engine.dart';
import '../screens/speaking_alarm_screen.dart';

class DeviceWallClock {
  const DeviceWallClock();

  static const weekdaysAr = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  static const monthsAr = [
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

  String timeLabel(DateTime now) {
    final local = now.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String spokenLabel(DateTime now) {
    final local = now.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final time = '${two(local.hour)}:${two(local.minute)}';
    if (AppConfig.instance.defaultLanguage == AppLanguage.english) {
      return 'The time is $time.';
    }
    return 'الساعة $time. ${dateLabel(now)}';
  }

  String dateLabel(DateTime now) {
    final local = now.toLocal();
    final day = weekdaysAr[local.weekday - 1];
    final month = monthsAr[local.month - 1];
    final date = local.day.toString().padLeft(2, '0');
    return '$day، $date $month ${local.year}';
  }
}

class DeviceWallClockView extends StatefulWidget {
  const DeviceWallClockView({super.key, this.showAlarms = true});

  final bool showAlarms;

  @override
  State<DeviceWallClockView> createState() => _DeviceWallClockViewState();
}

class _DeviceWallClockViewState extends State<DeviceWallClockView> {
  static const _clock = DeviceWallClock();
  Timer? _tick;
  DateTime _now = DateTime.now();

  void _sync(bool visible) {
    if (!visible) {
      _tick?.cancel();
      _tick = null;
      return;
    }
    if (_tick != null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _speak() {
    unawaited(VoiceEngine.instance.speak(_clock.spokenLabel(_now)));
  }

  void _openAlarms() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SpeakingAlarmScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    _sync(visible);
    final face = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF8A8A8A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF5A5A5A), width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ColoredBox(
          color: const Color(0xFFD5D5D5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              _clock.timeLabel(_now),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontFamily: 'monospace',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                height: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: _clock.spokenLabel(_now),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _speak,
                child: face,
              ),
            ),
          ),
        ),
        if (widget.showAlarms) ...[
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: context.nav('nav.clockAlarms'),
            child: IconButton(
              tooltip: context.nav('nav.clockAlarms'),
              onPressed: _openAlarms,
              icon: const Icon(Icons.alarm, color: Colors.black),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFBDBDBD),
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
