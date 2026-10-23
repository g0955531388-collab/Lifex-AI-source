/// =============================================================
/// Lifex-AI — الأدوية
/// الملف: medication_alarm_engine.dart
/// منبّه بأسماء حقيقية لكل فرد في الحساب. يسكت بعد التناول حتى الجرعة التالية.
/// =============================================================
library lifex_ai.features.medications.medication_alarm_engine;

class MedicationAlarm {
  const MedicationAlarm({
    required this.id,
    required this.profileId,
    required this.personName,
    required this.medicine,
    required this.hour,
    required this.minute,
    this.lastTakenAt,
  });

  final String id;
  final String profileId;
  final String personName;
  final String medicine;
  final int hour;
  final int minute;
  final DateTime? lastTakenAt;

  String get clock {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  DateTime slotOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'personName': personName,
        'medicine': medicine,
        'hour': hour,
        'minute': minute,
        if (lastTakenAt != null) 'lastTakenAt': lastTakenAt!.toIso8601String(),
      };

  factory MedicationAlarm.fromJson(Map<String, dynamic> json) =>
      MedicationAlarm(
        id: json['id'] as String? ?? '',
        profileId: json['profileId'] as String? ?? '',
        personName: json['personName'] as String? ?? '',
        medicine: json['medicine'] as String? ?? '',
        hour: json['hour'] as int? ?? 0,
        minute: json['minute'] as int? ?? 0,
        lastTakenAt: DateTime.tryParse(json['lastTakenAt'] as String? ?? ''),
      );
}

class MedicationCue {
  const MedicationCue({
    required this.alarm,
    required this.writtenAr,
    required this.spokenAr,
  });

  final MedicationAlarm alarm;
  final String writtenAr;
  final String spokenAr;
}

class MedicationAlarmEngine {
  const MedicationAlarmEngine();

  static bool isTakenSpeech(String raw) {
    final t = raw.trim().toLowerCase();
    if (t.isEmpty) return false;
    const phrases = [
      'لقد تناولت الدواء',
      'تناولت الدواء',
      'أخذت الدواء',
      'أخذت الجرعة',
      'تم الدواء',
      'تم',
      'i took',
      'dose taken',
      'taken',
    ];
    for (final phrase in phrases) {
      if (t == phrase || t.contains(phrase)) return true;
    }
    return false;
  }

  bool isDue(MedicationAlarm alarm, DateTime now) {
    final slot = alarm.slotOn(now);
    if (now.isBefore(slot)) return false;
    final taken = alarm.lastTakenAt;
    if (taken == null) return true;
    return taken.isBefore(slot);
  }

  List<MedicationAlarm> dueAlarms(
    Iterable<MedicationAlarm> alarms,
    DateTime now,
  ) =>
      alarms.where((item) => isDue(item, now)).toList()
        ..sort((a, b) => a.slotOn(now).compareTo(b.slotOn(now)));

  MedicationCue cue(MedicationAlarm alarm) {
    final name = alarm.personName.trim();
    if (name.isEmpty) {
      return MedicationCue(
        alarm: alarm,
        writtenAr:
            'اسم المريض فارغ. لن يُنطق تذكير الدواء حتى يُكتب الاسم، منعاً للخلط.',
        spokenAr: 'اسم المريض فارغ. لن أذكّر بالدواء حتى يُكتب الاسم.',
      );
    }
    final spoken =
        'المريض $name. لديك دواء ${alarm.medicine} في الساعة ${alarm.clock}.';
    final written = '$spoken اتبع وصفة الطبيب. Lifex لا يصف الجرعة.';
    return MedicationCue(alarm: alarm, writtenAr: written, spokenAr: spoken);
  }

  MedicationAlarm acknowledge(MedicationAlarm alarm, DateTime now) =>
      MedicationAlarm(
        id: alarm.id,
        profileId: alarm.profileId,
        personName: alarm.personName,
        medicine: alarm.medicine,
        hour: alarm.hour,
        minute: alarm.minute,
        lastTakenAt: now,
      );

  MedicationAlarm? nextAfterTake(
    Iterable<MedicationAlarm> household,
    MedicationAlarm taken,
    DateTime now,
  ) {
    final rest = household.where((item) => item.id != taken.id);
    final upcoming = [
      for (final item in rest)
        if (!isDue(item, now) || item.slotOn(now).isAfter(taken.slotOn(now)))
          item,
    ]..sort((a, b) {
        final sa = a.slotOn(now);
        final sb = b.slotOn(now);
        final fa = sa.isBefore(now) ? sa.add(const Duration(days: 1)) : sa;
        final fb = sb.isBefore(now) ? sb.add(const Duration(days: 1)) : sb;
        return fa.compareTo(fb);
      });
    return upcoming.isEmpty ? null : upcoming.first;
  }
}
