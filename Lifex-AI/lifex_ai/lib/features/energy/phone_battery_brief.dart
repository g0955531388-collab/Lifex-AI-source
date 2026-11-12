/// تنبيهات البطارية المحلية. النسبة تُنطق فقط إذا وصل قياس.
library lifex_ai.features.energy.phone_battery_brief;

import 'battery_monitor.dart';

class PhoneBatterySpeech {
  const PhoneBatterySpeech({
    required this.measured,
    required this.arabic,
    required this.english,
  });

  final bool measured;
  final String arabic;
  final String english;

  static PhoneBatterySpeech unread() {
    return const PhoneBatterySpeech(
      measured: false,
      arabic: 'لم تُقرأ بطارية الهاتف من الجهاز. لن أخترع نسبة.',
      english:
          'The phone battery was not read from the device. I will not invent a percentage.',
    );
  }

  static PhoneBatterySpeech fromMonitor(BatteryMonitor monitor) {
    if (!monitor.hasDeviceReading) return unread();
    final status = monitor.lastKnownStatus;
    return fromReading(level: status.level, charging: status.isCharging);
  }

  static PhoneBatterySpeech fromReading({
    required int level,
    required bool charging,
  }) {
    final stateAr = charging ? 'الجهاز يُشحن' : 'الجهاز غير موصول بالشاحن';
    final stateEn = charging ? 'The phone is charging' : 'The phone is not charging';
    return PhoneBatterySpeech(
      measured: true,
      arabic: 'شحن الجوال $level بالمئة. $stateAr.',
      english: 'Phone battery is $level percent. $stateEn.',
    );
  }
}

class BatteryAlertGate {
  static const thresholds = <int>[20, 10, 5];

  final Set<int> _latched = <int>{};
  bool? _charging;

  List<String> onReading({
    required int level,
    required bool charging,
    required bool english,
  }) {
    final lines = <String>[];
    final previous = _charging;
    if (previous != null && previous != charging) {
      lines.add(
        charging
            ? (english ? 'Charging started.' : 'بدأ الشحن.')
            : (english ? 'The charger was disconnected.' : 'انفصل الشاحن.'),
      );
    }
    _charging = charging;

    int? spoken;
    for (final threshold in thresholds) {
      final crossed = level <= threshold && !charging;
      if (crossed) {
        if (!_latched.contains(threshold)) spoken = threshold;
        _latched.add(threshold);
      } else if (level > threshold) {
        _latched.remove(threshold);
      }
    }
    if (spoken != null) {
      lines.add(
        english
            ? 'Battery is at or below $spoken percent. The reading is $level percent.'
            : 'البطارية $spoken بالمئة أو أقل. القراءة $level بالمئة.',
      );
    }
    return lines;
  }
}
