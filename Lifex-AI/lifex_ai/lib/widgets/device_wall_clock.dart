/// ساعة الجهاز المحلية. الوقت من DateTime.now، بلا نشاط أندرويد.
library lifex_ai.widgets.device_wall_clock;

import 'dart:async';

import 'package:flutter/material.dart';

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
    return 'الساعة ${two(local.hour)}:${two(local.minute)}. ${dateLabel(now)}';
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
  const DeviceWallClockView({super.key});

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

  @override
  Widget build(BuildContext context) {
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    _sync(visible);
    return Semantics(
      label: _clock.spokenLabel(_now),
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              children: [
                Text(
                  _clock.timeLabel(_now),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(_clock.dateLabel(_now)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
