/// مظهر الساعة ونطقها الطبيعي: الوضع، 12/24، نمط الأرقام، والإعلان الدوري.
library lifex_ai.features.clock.clock_display;

import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_config.dart';

enum ClockFaceMode { gray, lowVision, blind }

enum ClockDigitStyle { followLanguage, western, eastern }

enum ClockAutoAnnounce { off, hourly, quarterly }

T _pick<T extends Enum>(List<T> values, Object? raw, T fallback) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

extension ClockFaceModeLabel on ClockFaceMode {
  String get label {
    switch (this) {
      case ClockFaceMode.gray:
        return lifexUi('رمادي موفّر للطاقة', 'Power-saving gray');
      case ClockFaceMode.lowVision:
        return lifexUi('ضعيف البصر: أرقام كبيرة وتباين أقصى',
            'Low vision: large digits, maximum contrast');
      case ClockFaceMode.blind:
        return lifexUi('مكفوف: شاشة شبه سوداء، اللمس ينطق',
            'Blind: near-black screen, touch speaks');
    }
  }
}

extension ClockAutoAnnounceLabel on ClockAutoAnnounce {
  String get label {
    switch (this) {
      case ClockAutoAnnounce.off:
        return lifexUi('بلا إعلان تلقائي', 'No automatic announcement');
      case ClockAutoAnnounce.hourly:
        return lifexUi('عند كل ساعة كاملة', 'Every full hour');
      case ClockAutoAnnounce.quarterly:
        return lifexUi('عند كل ربع ساعة', 'Every quarter hour');
    }
  }

  bool dueAt(DateTime local) {
    switch (this) {
      case ClockAutoAnnounce.off:
        return false;
      case ClockAutoAnnounce.hourly:
        return local.minute == 0;
      case ClockAutoAnnounce.quarterly:
        return local.minute % 15 == 0;
    }
  }
}

/// ألوان كل وضع. الرمادي مثل ساعات كاسيو: خلفية رمادية وأرقام سوداء بلا توهج.
class ClockPalette {
  const ClockPalette({
    required this.face,
    required this.digit,
    required this.border,
  });

  final Color face;
  final Color digit;
  final Color border;

  static ClockPalette of(ClockFaceMode mode) {
    switch (mode) {
      case ClockFaceMode.gray:
        return const ClockPalette(
          face: Color(0xFFB9BFB4),
          digit: Color(0xFF111111),
          border: Color(0xFF6E746B),
        );
      case ClockFaceMode.lowVision:
        return const ClockPalette(
          face: Color(0xFF000000),
          digit: Color(0xFFFFE600),
          border: Color(0xFFFFE600),
        );
      case ClockFaceMode.blind:
        return const ClockPalette(
          face: Color(0xFF000000),
          digit: Color(0xFF3A3A3A),
          border: Color(0xFF1A1A1A),
        );
    }
  }
}

/// نسبة تباين WCAG بين لونين.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

class ClockDisplaySettings {
  const ClockDisplaySettings({
    this.mode = ClockFaceMode.gray,
    this.use24h = true,
    this.digits = ClockDigitStyle.followLanguage,
    this.lowVisionSeconds = false,
    this.autoAnnounce = ClockAutoAnnounce.off,
  });

  static const storageKey = 'lifex_clock_display_v1';

  final ClockFaceMode mode;
  final bool use24h;
  final ClockDigitStyle digits;
  final bool lowVisionSeconds;
  final ClockAutoAnnounce autoAnnounce;

  /// الثواني المتحركة وميض ومضيعة طاقة؛ تظهر فقط إن طلبها ضعيف البصر.
  bool get showSeconds => mode == ClockFaceMode.lowVision && lowVisionSeconds;

  bool easternDigits({required bool arabicUi}) {
    switch (digits) {
      case ClockDigitStyle.followLanguage:
        return arabicUi;
      case ClockDigitStyle.western:
        return false;
      case ClockDigitStyle.eastern:
        return true;
    }
  }

  ClockDisplaySettings copyWith({
    ClockFaceMode? mode,
    bool? use24h,
    ClockDigitStyle? digits,
    bool? lowVisionSeconds,
    ClockAutoAnnounce? autoAnnounce,
  }) {
    return ClockDisplaySettings(
      mode: mode ?? this.mode,
      use24h: use24h ?? this.use24h,
      digits: digits ?? this.digits,
      lowVisionSeconds: lowVisionSeconds ?? this.lowVisionSeconds,
      autoAnnounce: autoAnnounce ?? this.autoAnnounce,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'use24h': use24h,
        'digits': digits.name,
        'lowVisionSeconds': lowVisionSeconds,
        'autoAnnounce': autoAnnounce.name,
      };

  static ClockDisplaySettings fromJson(Map<String, dynamic> json) {
    return ClockDisplaySettings(
      mode: _pick(ClockFaceMode.values, json['mode'], ClockFaceMode.gray),
      use24h: json['use24h'] != false,
      digits: _pick(
          ClockDigitStyle.values, json['digits'], ClockDigitStyle.followLanguage),
      lowVisionSeconds: json['lowVisionSeconds'] == true,
      autoAnnounce: _pick(
          ClockAutoAnnounce.values, json['autoAnnounce'], ClockAutoAnnounce.off),
    );
  }

  static Future<ClockDisplaySettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const ClockDisplaySettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const ClockDisplaySettings();
      return fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const ClockDisplaySettings();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(toJson()));
  }
}

String toEasternDigits(String text) {
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  final out = StringBuffer();
  for (final unit in text.codeUnits) {
    if (unit >= 0x30 && unit <= 0x39) {
      out.write(eastern[unit - 0x30]);
    } else {
      out.writeCharCode(unit);
    }
  }
  return out.toString();
}

/// الأرقام المعروضة ولاحقة ص/م أو AM/PM في نظام 12 ساعة.
({String digits, String suffix}) clockFaceLabel(
  DateTime now, {
  required bool use24h,
  required bool seconds,
  required bool eastern,
  required bool arabicUi,
}) {
  final local = now.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  final hour = use24h ? local.hour : (local.hour % 12 == 0 ? 12 : local.hour % 12);
  var digits = '${two(hour)}:${two(local.minute)}';
  if (seconds) digits = '$digits:${two(local.second)}';
  var suffix = '';
  if (!use24h) {
    final pm = local.hour >= 12;
    suffix = arabicUi ? (pm ? 'م' : 'ص') : (pm ? 'PM' : 'AM');
  }
  if (eastern) digits = toEasternDigits(digits);
  return (digits: digits, suffix: suffix);
}

const _arHours = [
  'الثانية عشرة',
  'الواحدة',
  'الثانية',
  'الثالثة',
  'الرابعة',
  'الخامسة',
  'السادسة',
  'السابعة',
  'الثامنة',
  'التاسعة',
  'العاشرة',
  'الحادية عشرة',
];

const _enHours = [
  'twelve',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
  'eleven',
];

String _arPeriod(int hour24) {
  if (hour24 <= 4) return 'ليلاً';
  if (hour24 <= 11) return 'صباحاً';
  if (hour24 == 12) return 'ظهراً';
  return 'مساءً';
}

String _enPeriod(int hour24) {
  if (hour24 >= 5 && hour24 <= 11) return 'in the morning';
  if (hour24 >= 12 && hour24 <= 17) return 'in the afternoon';
  if (hour24 >= 18 && hour24 <= 20) return 'in the evening';
  return 'at night';
}

String _arMinutes(int m) {
  if (m == 1) return 'ودقيقة واحدة';
  if (m == 2) return 'ودقيقتان';
  if (m <= 10) return 'و $m دقائق';
  return 'و $m دقيقة';
}

/// «الساعة الواحدة والربع مساءً» بلا أرقام رقم-رقم. [prefix] يضيف كلمة «الساعة».
String naturalTimeArabic(DateTime now, {bool prefix = true}) {
  final local = now.toLocal();
  final m = local.minute;
  var hour24 = local.hour;
  String tail;
  if (m == 0) {
    tail = 'تماماً';
  } else if (m == 15) {
    tail = 'والربع';
  } else if (m == 20) {
    tail = 'والثلث';
  } else if (m == 30) {
    tail = 'والنصف';
  } else if (m == 40) {
    hour24 = (hour24 + 1) % 24;
    tail = 'إلا ثلثاً';
  } else if (m == 45) {
    hour24 = (hour24 + 1) % 24;
    tail = 'إلا ربعاً';
  } else {
    tail = _arMinutes(m);
  }
  final core = '${_arHours[hour24 % 12]} $tail ${_arPeriod(hour24)}';
  return prefix ? 'الساعة $core' : core;
}

/// "quarter past one in the afternoon"، بلا "It's" في أوله.
String naturalTimeEnglish(DateTime now) {
  final local = now.toLocal();
  final m = local.minute;
  final h = local.hour;
  if (m == 0 && h == 12) return 'noon';
  if (m == 0 && h == 0) return 'midnight';
  if (m == 0) return "${_enHours[h % 12]} o'clock ${_enPeriod(h)}";
  if (m <= 30) {
    final lead = m == 15
        ? 'quarter past'
        : m == 30
            ? 'half past'
            : '$m ${m == 1 ? 'minute' : 'minutes'} past';
    return '$lead ${_enHours[h % 12]} ${_enPeriod(h)}';
  }
  final next = (h + 1) % 24;
  final left = 60 - m;
  final lead = left == 15
      ? 'quarter to'
      : '$left ${left == 1 ? 'minute' : 'minutes'} to';
  if (next == 12) return '$lead noon';
  if (next == 0) return '$lead midnight';
  return '$lead ${_enHours[next % 12]} ${_enPeriod(next)}';
}
