import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/women_health/women_care_desk.dart';

void main() {
  const desk = WomenCareDesk();

  test('عدم التأكد لا يسجل حملاً مؤكداً', () {
    final opened = desk.openFromBasis(PregnancyBasis.unsure);
    expect(opened.confirmed, isFalse);
    expect(opened.provisional, isTrue);
    expect(opened.messageAr.contains('أنت حامل'), isFalse);
  });

  test('الفحص المخبري يفتح المتابعة كتقدير', () {
    final opened = desk.openFromBasis(PregnancyBasis.laboratory);
    expect(opened.confirmed, isTrue);
    expect(opened.messageAr.contains('تقدير'), isTrue);
  });

  test('عمر الحمل أسبوع ويوم من آخر دورة', () {
    final age = desk.age(
      lmp: DateTime(2026, 1, 1),
      now: DateTime(2026, 3, 27),
    );
    expect(age.week, 12);
    expect(age.day, 1);
    expect(age.dueDate, DateTime(2026, 10, 8));
    expect(age.underReview, isFalse);
  });

  test('تاريخ الطبيبة يقدَّم ويُعلَّم قيد المراجعة', () {
    final age = desk.age(
      lmp: DateTime(2026, 1, 1),
      now: DateTime(2026, 3, 26),
      clinicianDueDate: DateTime(2026, 10, 15),
    );
    expect(age.underReview, isTrue);
    expect(age.dueDate, DateTime(2026, 10, 15));
    expect(age.week, 11);
  });

  test('النزيف مسار عاجل ولا ينتظر الذكاء', () {
    final path = desk.urgentPath('نزيف مهبلي');
    expect(path, isNotNull);
    expect(path!, contains('الآن'));
    expect(desk.urgentPath('تعب خفيف'), isNull);
  });

  test('البطاقة اليومية لا تطمئن لغياب الأعراض', () {
    expect(desk.dailyCheckInAr().contains('كل شيء سليم'), isFalse);
    expect(desk.dailyCheckInAr().contains('كيف تشعرين'), isTrue);
  });

  test('مراجعة الدواء لا تأمر بالإيقاف', () {
    final text = desk.medicationReviewAr(
      knownCaution: true,
      sourceEnough: true,
    );
    expect(text.contains('لا توقفي'), isTrue);
    expect(text.contains('أوقفي الدواء'), isFalse);
    final unknown = desk.medicationReviewAr(
      knownCaution: false,
      sourceEnough: false,
    );
    expect(unknown.contains('لا أستطيع تأكيد'), isTrue);
  });

  test('ملف الطفل مستقل وعنوان القفل بلا تفاصيل', () {
    final id = desk.babyProfileId(
      motherProfileId: 'mother-1',
      bornAt: DateTime(2026, 10, 1),
    );
    expect(id == 'mother-1', isFalse);
    expect(id.startsWith('baby-mother-1-'), isTrue);
    expect(WomenCareDesk.lockScreenTitleAr.contains('حمل'), isFalse);
    expect(WomenCareDesk.lockScreenTitleAr.contains('دورة'), isFalse);
  });
}
