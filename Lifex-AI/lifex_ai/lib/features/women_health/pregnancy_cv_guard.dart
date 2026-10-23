/// =============================================================
/// Lifex-AI — رعاية الإناث
/// الملف: pregnancy_cv_guard.dart
/// بعد تأكيد الحمل: ينظر في أدوية الملف والحالات المزمنة محلياً.
/// يوجّه للطبيبة إن وُجد تعارض محتمل. ليس تشخيصاً ولا إيقاف دواء آلياً.
/// =============================================================
library lifex_ai.features.women_health.pregnancy_cv_guard;

import '../medications/pharmacopoeia_reference.dart';
import '../profile/health_profile.dart';

class PregnancyCvGuard {
  const PregnancyCvGuard();

  static const _cautionMeds = [
    'وارفارين',
    'warfarin',
    'ميثوتريكسات',
    'methotrexate',
    'آيزوتريتينوين',
    'isotretinoin',
    'ريتين',
    'فالبوروات',
    'valproate',
    'إيبوبروفين',
    'ibuprofen',
    'أسبرين',
    'aspirin',
  ];

  static const _cautionConditions = [
    'سكر',
    'diabetes',
    'ضغط',
    'hypertension',
    'صرع',
    'epilepsy',
    'درقي',
    'thyroid',
    'كلوي',
    'قلب',
  ];

  List<String> flagsFor(
    HealthProfile profile, {
    PharmacopoeiaReference? pharmacopoeia,
    int? gestationalWeek,
  }) {
    final flags = <String>[];
    for (final med in profile.currentMedicationNames) {
      final folded = med.toLowerCase();
      if (_cautionMeds.any((item) => folded.contains(item.toLowerCase()))) {
        flags.add(
          'دواء مسجَّل ($med) قد يحتاج مراجعة عاجلة بسبب الحمل. '
          'تواصلي مع الطبيبة أو الصيدلي اليوم. لا توقفي دواءً موصوفاً '
          'ولا تغيّري جرعته من تلقاء نفسك.',
        );
      }
    }
    for (final cond in profile.chronicConditions.where((c) => c.isActive)) {
      final folded = cond.conditionName.toLowerCase();
      if (_cautionConditions
          .any((item) => folded.contains(item.toLowerCase()))) {
        flags.add(
          'حالة في الملف (${cond.conditionName}) تستدعي متابعة حمل مع الطبيبة.',
        );
      }
    }
    if (pharmacopoeia != null) {
      flags.addAll(
        pharmacopoeia.pregnancyCautions(
          profile,
          gestationalWeek: gestationalWeek,
        ),
      );
    }
    if (flags.isEmpty) {
      flags.add(
        'لا بند محلي صريح للتعارض. أبقي المتابعة مع الطبيبة وأبلِغيها بكل دواء.',
      );
    }
    return flags;
  }
}
