// =============================================================
// Lifex-AI — اختبارات الوحدة
// الملف: network_box_test.dart
// المسار: test/features/network_box_test.dart
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/dental/dental_chart.dart';
import 'package:lifex_ai/features/device_guardian/lost_phone_policy.dart';
import 'package:lifex_ai/features/doctors/doctor_directory.dart';
import 'package:lifex_ai/features/family/genetics_signal_engine.dart';
import 'package:lifex_ai/features/network_box/box_unit_catalog.dart';
import 'package:lifex_ai/features/network_box/profile_box_store.dart';
import 'package:lifex_ai/features/network_box/sector_analytics.dart';
import 'package:lifex_ai/features/network_box/unified_booking_service.dart';
import 'package:lifex_ai/features/network_box/unit_branch_catalog.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';
import 'package:lifex_ai/features/reports/stamped_report.dart';
import 'package:lifex_ai/services/cloud/cloud_backend_client.dart';

void main() {
  HealthProfile profile() => HealthProfile(
        profileId: 'p-box',
        fullName: 'اختبار',
        dateOfBirth: DateTime(1990, 1, 1),
      );

  group('ProfileBoxStore', () {
    test('يضيف ويحذف سجلاً داخل الملف', () {
      final store = ProfileBoxStore(profile());
      store.add(BoxKeys.doctors, {'title': 'قلب', 'detail': 'دمشق'});
      expect(store.list(BoxKeys.doctors), hasLength(1));
      store.removeAt(BoxKeys.doctors, 0);
      expect(store.list(BoxKeys.doctors), isEmpty);
    });

    test('يحفظ الهوية المستعارة وملاحظات التكوين', () {
      final store = ProfileBoxStore(profile());
      store.setString(BoxKeys.aliasName, 'مريض الأمل');
      store.setString(BoxKeys.lifeOriginNotes, 'حمل 2024');
      expect(store.stringField(BoxKeys.aliasName), 'مريض الأمل');
      expect(store.stringField(BoxKeys.lifeOriginNotes), 'حمل 2024');
    });
  });

  group('UnifiedBookingService', () {
    test('ينشئ حجزاً برمز محلي بانتظار الخادم', () {
      final service = UnifiedBookingService(ProfileBoxStore(profile()));
      final booking = service.add(
        unitId: 'hospital',
        title: 'مخبر',
        place: 'دمشق',
        scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      );
      expect(booking.accessCode, startsWith('LX'));
      expect(booking.status, 'awaitingServer');
      expect(service.all(), hasLength(1));
      expect(service.publicQueue().first['code'], booking.accessCode);
    });
  });

  group('SectorAnalytics', () {
    test('يعد السجلات بلا أسماء', () {
      final person = profile();
      ProfileBoxStore(person).add(BoxKeys.labs, {
        'title': 'سكر',
        'detail': 'قيمة من الطبيب',
      });
      final counts = SectorAnalytics.unitCounts(person);
      expect(counts['labs'], 1);
      expect(counts.keys, isNot(contains('اختبار')));
    });
  });

  group('BoxUnitCatalog', () {
    test('يغطي المقاعد المؤسسية', () {
      final ids = BoxUnitCatalog.recordUnits.map((unit) => unit.id).toSet();
      expect(
        ids,
        containsAll([
          'doctors',
          'patients',
          'labs',
          'radiology',
          'pharmacy',
          'hospital',
          'dental',
          'women',
          'donations',
          'education',
        ]),
      );
    });
  });

  group('UnitBranchCatalog', () {
    test('كل وحدة مؤسسية لها فروع أعمق من سجل واحد', () {
      for (final unit in BoxUnitCatalog.recordUnits) {
        final branches = UnitBranchCatalog.forUnit(unit.id);
        expect(branches, isNotEmpty, reason: unit.id);
        expect(branches.length, greaterThanOrEqualTo(2), reason: unit.id);
      }
    });

    test('الأطباء يفصلون مهتم عن طبيبي', () {
      final ids = UnitBranchCatalog.forUnit('doctors').map((b) => b.id);
      expect(ids, containsAll(['interested', 'myDoctor', 'publicCv', 'directory']));
    });

    test('المرأة تغطي الحمل والنفاس والدورة', () {
      final ids = UnitBranchCatalog.forUnit('women').map((b) => b.id);
      expect(ids, containsAll(['edu', 'preg', 'birth', 'post', 'cycle']));
    });

    test('الملف الصحي يفرع الهوية والأدوية والتاريخ', () {
      final ids = UnitBranchCatalog.healthCv.map((b) => b.id);
      expect(
        ids,
        containsAll(['cvIdentity', 'cvMeds', 'cvHistory', 'cvVaccines', 'cvFamily']),
      );
    });
  });

  group('CloudBackendClient', () {
    test('يرفض رابط المثال كخادم عامل', () {
      final client = CloudBackendClient(
        baseUrl: 'https://backend.lifex-ai.example.com',
      );
      expect(client.isEndpointConfigured, isFalse);
    });
  });

  group('من الأرشيف المكتبي', () {
    test('سياسة الفقدان لا تصوّر الماسك ولا تستخدم Device Admin', () {
      const policy = LostPhonePolicy();
      expect(policy.nearbyActionAr(), contains('بلا تصوير'));
      expect(policy.simChangeWithoutPinAr(), contains('Device Admin'));
      expect(policy.pinMatches('1234', '1234'), isTrue);
      expect(policy.pinMatches('1234', '0000'), isFalse);
    });

    test('مخطط الأسنان يحفظ ملاحظة على سن FDI', () {
      final chart = DentalChart();
      chart.setNote(11, 'حشو');
      expect(chart.noteFor(11), 'حشو');
      final restored = DentalChart.fromJson(chart.toJson());
      expect(restored.noteFor(11), 'حشو');
    });

    test('التقرير المختوم يحمل الملكية وإخلاء طبي', () {
      final text = StampedReport(
        profile: profile(),
        bodyAr: 'ملخص',
      ).toPlainText();
      expect(text, contains('غازي'));
      expect(text, contains(StampedReport.medicalDisclaimerAr));
    });

    test('إشارة العائلة لا تدمج الملفات', () {
      final a = HealthProfile(
        profileId: 'a',
        fullName: 'أ',
        dateOfBirth: DateTime(1990, 1, 1),
        bloodType: BloodType.oPositive,
      );
      final b = HealthProfile(
        profileId: 'b',
        fullName: 'ب',
        dateOfBirth: DateTime(1992, 1, 1),
        bloodType: BloodType.oPositive,
      );
      final signals = GeneticsSignalEngine().estimate([a, b]);
      expect(signals.first.messageAr, contains('ليس تشخيصاً'));
      expect(signals.first.profileIds, ['a', 'b']);
    });

    test('دليل الأطباء يرتب حسب المسافة المدخلة', () {
      final sorted = DoctorDirectory().nearestFirst([
        {'title': 'بعيد', 'km': '12', 'detail': 'قلب'},
        {'title': 'قريب', 'km': '1', 'detail': 'قلب'},
      ], specialty: 'قلب');
      expect(sorted.first['title'], 'قريب');
    });
  });
}
