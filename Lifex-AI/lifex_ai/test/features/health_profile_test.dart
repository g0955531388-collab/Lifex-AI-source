// =============================================================
// Lifex-AI — اختبارات الوحدة
// الملف: health_profile_test.dart
// المسار: test/features/health_profile_test.dart
// الوصف: اختبار الحسابات الأساسية في الملف الصحي (العمر، مؤشر كتلة
// الجسم، فحص الحساسية) — منطق بسيط لكنه يُستخدم في عدة قرارات مهمة
// عبر النظام (توجيه AI، تنبيهات الصيدلية)، فأي خطأ حسابي هنا ينتشر
// أثره لوحدات أخرى.
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';

void main() {
  group('HealthProfile — حساب العمر', () {
    test('يحسب العمر بشكل صحيح لعيد ميلاد مرّ بالفعل هذا العام', () {
      final now = DateTime.now();
      final birthDate = DateTime(now.year - 30, 1, 1);
      final profile = HealthProfile(
        profileId: 'p1',
        fullName: 'اختبار',
        dateOfBirth: birthDate,
      );

      expect(profile.ageInYears, 30);
    });

    test('العمر المكتوب يُعتمد بلا تاريخ ميلاد', () {
      final profile = HealthProfile(
        profileId: 'p-age',
        fullName: 'اختبار',
        statedAgeYears: 34,
      );

      expect(profile.dateOfBirth, isNull);
      expect(profile.ageInYears, 34);
      final restored = HealthProfile.fromJson(profile.toJson());
      expect(restored.dateOfBirth, isNull);
      expect(restored.statedAgeYears, 34);
      expect(restored.ageInYears, 34);
    });

    test('لا يحسب العام الحالي إذا لم يأتِ عيد الميلاد بعد', () {
      final now = DateTime.now();
      // تاريخ ميلاد في المستقبل القريب ضمن نفس السنة القادمة (لم يأتِ
      // بعد)، لضمان أن الحساب لا يحتسب سناً إضافية قبل أوانها.
      final futureBirthdayThisYear = DateTime(now.year - 30, 12, 31);
      final profile = HealthProfile(
        profileId: 'p2',
        fullName: 'اختبار',
        dateOfBirth: futureBirthdayThisYear,
      );

      // إذا كان اليوم قبل 31 ديسمبر، العمر الحقيقي لا يزال 29 لا 30.
      final expectedAge = (now.month == 12 && now.day == 31) ? 30 : 29;
      expect(profile.ageInYears, expectedAge);
    });
  });

  group('HealthProfile — مؤشر كتلة الجسم', () {
    test('يُحسب بشكل صحيح عند توفر الطول والوزن', () {
      final profile = HealthProfile(
        profileId: 'p3',
        fullName: 'اختبار',
        dateOfBirth: DateTime(1990, 1, 1),
        heightCm: 170,
        weightKg: 70,
      );

      // BMI = 70 / (1.70 * 1.70) ≈ 24.22
      expect(profile.bodyMassIndex, closeTo(24.22, 0.01));
    });

    test('يُرجع null عند غياب الطول أو الوزن', () {
      final profile = HealthProfile(
        profileId: 'p4',
        fullName: 'اختبار',
        dateOfBirth: DateTime(1990, 1, 1),
      );

      expect(profile.bodyMassIndex, isNull);
    });
  });

  group('HealthProfile — الحساسية', () {
    test('hasAllergyTo يعمل بغض النظر عن حالة الأحرف', () {
      final profile = HealthProfile(
        profileId: 'p5',
        fullName: 'اختبار',
        dateOfBirth: DateTime(1990, 1, 1),
      );
      profile
          .addAllergy(AllergyRecord(substance: 'Penicillin', severity: 'high'));

      expect(profile.hasAllergyTo('penicillin'), isTrue);
      expect(profile.hasAllergyTo('PENICILLIN'), isTrue);
      expect(profile.hasAllergyTo('Aspirin'), isFalse);
    });
  });

  group('HealthProfile — الاستبيان', () {
    test('يحفظ questionnaireData في round-trip JSON', () {
      final profile = HealthProfile(
        profileId: 'p6',
        fullName: 'اختبار',
        dateOfBirth: DateTime(1990, 1, 1),
        questionnaireData: {
          'smoking': true,
          'appointments': [
            {'title': 'طبيب قلب', 'place': 'دمشق', 'date': '2026/9/20'},
          ],
        },
      );

      final restored = HealthProfile.fromJson(profile.toJson());
      expect(restored.questionnaireData['smoking'], isTrue);
      expect(
        (restored.questionnaireData['appointments'] as List).first['title'],
        'طبيب قلب',
      );
    });
  });
}
