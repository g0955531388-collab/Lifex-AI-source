/// توافق كريات الدم الحمراء للدعوة الأولية فقط.
/// بنك الدم يؤكد الزمرة قبل أي تبرع. بلازما الدم تتبع قاعدة معكوسة
/// ولا تُستخدم هنا.
library lifex_ai.features.blood_network.blood_type_match;

import '../hospital/hospital_blood_bank.dart';

class BloodTypeMatch {
  const BloodTypeMatch._();

  static String label(BloodTypeSimple type) {
    switch (type) {
      case BloodTypeSimple.oNegative:
        return 'O−';
      case BloodTypeSimple.oPositive:
        return 'O+';
      case BloodTypeSimple.aNegative:
        return 'A−';
      case BloodTypeSimple.aPositive:
        return 'A+';
      case BloodTypeSimple.bNegative:
        return 'B−';
      case BloodTypeSimple.bPositive:
        return 'B+';
      case BloodTypeSimple.abNegative:
        return 'AB−';
      case BloodTypeSimple.abPositive:
        return 'AB+';
    }
  }

  /// هل يستطيع حامل [donor] إعطاء كريات حمراء لصاحب [needed].
  static bool canDonateRedCells(
    BloodTypeSimple donor,
    BloodTypeSimple needed,
  ) {
    const table = <BloodTypeSimple, Set<BloodTypeSimple>>{
      BloodTypeSimple.oNegative: {
        BloodTypeSimple.oNegative,
        BloodTypeSimple.oPositive,
        BloodTypeSimple.aNegative,
        BloodTypeSimple.aPositive,
        BloodTypeSimple.bNegative,
        BloodTypeSimple.bPositive,
        BloodTypeSimple.abNegative,
        BloodTypeSimple.abPositive,
      },
      BloodTypeSimple.oPositive: {
        BloodTypeSimple.oPositive,
        BloodTypeSimple.aPositive,
        BloodTypeSimple.bPositive,
        BloodTypeSimple.abPositive,
      },
      BloodTypeSimple.aNegative: {
        BloodTypeSimple.aNegative,
        BloodTypeSimple.aPositive,
        BloodTypeSimple.abNegative,
        BloodTypeSimple.abPositive,
      },
      BloodTypeSimple.aPositive: {
        BloodTypeSimple.aPositive,
        BloodTypeSimple.abPositive,
      },
      BloodTypeSimple.bNegative: {
        BloodTypeSimple.bNegative,
        BloodTypeSimple.bPositive,
        BloodTypeSimple.abNegative,
        BloodTypeSimple.abPositive,
      },
      BloodTypeSimple.bPositive: {
        BloodTypeSimple.bPositive,
        BloodTypeSimple.abPositive,
      },
      BloodTypeSimple.abNegative: {
        BloodTypeSimple.abNegative,
        BloodTypeSimple.abPositive,
      },
      BloodTypeSimple.abPositive: {
        BloodTypeSimple.abPositive,
      },
    };
    return table[donor]?.contains(needed) ?? false;
  }
}
