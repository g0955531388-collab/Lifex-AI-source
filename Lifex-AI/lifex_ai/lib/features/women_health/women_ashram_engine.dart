/// =============================================================
/// Lifex-AI — رعاية الإناث (وحدة مستقلة)
/// الملف: women_ashram_engine.dart
/// من الطفولة حتى نهاية العمر. الدورة من تواريخها هي. الحمل يُحسب من
/// متوسط دوراتها لا من افتراض 28 يوماً. الإشعار العلني: لديك رسالة خاصة.
/// =============================================================
library lifex_ai.features.women_health.women_ashram_engine;

import '../medications/pharmacopoeia_reference.dart';
import '../profile/health_profile.dart';
import 'female_cycle_tracker.dart';
import 'pregnancy_cv_guard.dart';
import 'private_female_notice.dart';
import 'women_ashram_care_copy.dart';

class WomenAshramSnapshot {
  const WomenAshramSnapshot({
    required this.notices,
    required this.meanCycleDays,
    this.nextStart,
    this.daysUntilNext,
    this.lateByDays,
    this.pregnancyActive = false,
    this.gestationalWeek,
    this.fetalAgeDays,
    this.dueDate,
    this.weeklyCareAr,
    this.dailyCareAr,
    this.cvFlags = const [],
  });

  final List<PrivateFemaleNotice> notices;
  final double? meanCycleDays;
  final DateTime? nextStart;
  final int? daysUntilNext;
  final int? lateByDays;
  final bool pregnancyActive;
  final int? gestationalWeek;
  final int? fetalAgeDays;
  final DateTime? dueDate;
  final String? weeklyCareAr;
  final String? dailyCareAr;
  final List<String> cvFlags;
}

class WomenAshramEngine {
  const WomenAshramEngine();

  /// خط أساس ثلاثة أشهر. إن لم يكفِ سجل داخل النافذة يُستخدم السجل كله.

  /// طول الدورة = من بداية إلى بداية، كما سجّلتها هي.
  double? meanStartToStartDays(List<DateTime> starts, {DateTime? asOf}) {
    if (starts.length < 2) return null;
    final ordered = [...starts]..sort();
    final anchor = asOf ?? ordered.last;
    final windowStart = DateTime(anchor.year, anchor.month, anchor.day)
        .subtract(const Duration(days: FemaleCycleTracker.baselineDays));
    final recent = ordered
        .where(
          (d) => !DateTime(d.year, d.month, d.day).isBefore(windowStart),
        )
        .toList();
    final sample = recent.length >= 2 ? recent : ordered;
    var sum = 0;
    for (var i = 1; i < sample.length; i++) {
      sum += sample[i].difference(sample[i - 1]).inDays;
    }
    return sum / (sample.length - 1);
  }

  DateTime? nextStartFrom(List<DateTime> starts, {DateTime? asOf}) {
    final mean = meanStartToStartDays(starts, asOf: asOf);
    if (mean == null) return null;
    final ordered = [...starts]..sort();
    return ordered.last.add(Duration(days: mean.round()));
  }

  /// موعد الولادة: 280 يوماً من آخر دورة، مع تعديل بطول دورتها المتوسط.
  DateTime dueFromCycles({
    required DateTime lmp,
    required List<DateTime> starts,
  }) {
    final mean = meanStartToStartDays(starts) ?? 28;
    final shift = mean.round() - 28;
    return FemaleCycleTracker.estimatedDueFromLmp(lmp)
        .add(Duration(days: shift));
  }

  /// عمر الحمل بالأسابيع من آخر دورة. عمر الجنين من تقدير الإباضة
  /// (متوسط الدورة ناقص 14 يوماً). أدق من افتراض 28 يوماً لأنها من سجلها.
  /// السونار عند الطبيبة يبقى المرجع الطبي.
  ({int gestationalWeek, int fetalAgeDays}) ages({
    required DateTime lmp,
    required DateTime now,
    required List<DateTime> starts,
  }) {
    final mean = meanStartToStartDays(starts) ?? 28;
    final ovulation = lmp.add(Duration(days: (mean - 14).round().clamp(8, 21)));
    final gDays = now.difference(lmp).inDays;
    final fDays = now.difference(ovulation).inDays;
    return (
      gestationalWeek: gDays < 0 ? 0 : (gDays / 7).floor().clamp(0, 42),
      fetalAgeDays: fDays < 0 ? 0 : fDays,
    );
  }

  WomenAshramSnapshot evaluate({
    required DateTime now,
    required List<DateTime> starts,
    required bool trackingEnabled,
    required bool pregnancyConfirmed,
    DateTime? lmp,
    HealthProfile? profile,
    PharmacopoeiaReference? pharmacopoeia,
  }) {
    if (!trackingEnabled) {
      return const WomenAshramSnapshot(
        notices: [],
        meanCycleDays: null,
      );
    }

    final cycleAnchor = pregnancyConfirmed ? null : now;
    final mean = meanStartToStartDays(starts, asOf: cycleAnchor);
    final next = nextStartFrom(starts, asOf: cycleAnchor);
    final notices = <PrivateFemaleNotice>[];
    int? until;
    int? late;

    if (!pregnancyConfirmed && next != null) {
      until = DateTime(next.year, next.month, next.day)
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;
      if (until == 1 || until == 0) {
        notices.add(
          PrivateFemaleNotice.cycleSoon(daysUntil: until),
        );
      } else if (until <= -7) {
        late = -until;
        notices.add(PrivateFemaleNotice.lateCycle(daysLate: late));
      }
    }

    DateTime? due;
    int? week;
    int? fetal;
    String? weekly;
    String? daily;
    var flags = <String>[];

    if (pregnancyConfirmed) {
      final usedLmp =
          lmp ?? (starts.isEmpty ? null : ([...starts]..sort()).last);
      if (usedLmp != null) {
        due = dueFromCycles(lmp: usedLmp, starts: starts);
        final age = ages(lmp: usedLmp, now: now, starts: starts);
        week = age.gestationalWeek;
        fetal = age.fetalAgeDays;
        weekly = WomenAshramCareCopy.weekly(week);
        daily = WomenAshramCareCopy.daily(now.weekday);
        notices.add(PrivateFemaleNotice.weeklyCare(week: week));
        notices.add(PrivateFemaleNotice.dailyCare());
      }
      if (profile != null) {
        flags = const PregnancyCvGuard().flagsFor(
          profile,
          pharmacopoeia: pharmacopoeia,
          gestationalWeek: week,
        );
        if (flags.isNotEmpty) {
          notices.add(PrivateFemaleNotice.cvReview(flags: flags));
        }
      }
    }

    return WomenAshramSnapshot(
      notices: notices,
      meanCycleDays: mean,
      nextStart: next,
      daysUntilNext: until,
      lateByDays: late,
      pregnancyActive: pregnancyConfirmed,
      gestationalWeek: week,
      fetalAgeDays: fetal,
      dueDate: due,
      weeklyCareAr: weekly,
      dailyCareAr: daily,
      cvFlags: flags,
    );
  }
}
