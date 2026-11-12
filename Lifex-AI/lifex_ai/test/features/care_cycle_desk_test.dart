import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/app_constants.dart';
import 'package:lifex_ai/features/care_cycle/care_cycle_desk.dart';
import 'package:lifex_ai/features/location/nearby_care_finder.dart';
import 'package:lifex_ai/features/network_box/profile_box_store.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';
import 'package:lifex_ai/features/providers/pharmacy_stock_ledger.dart';

HealthProfile _person(String id, String name) => HealthProfile(
      profileId: id,
      fullName: name,
      dateOfBirth: DateTime(1988, 4, 2),
      allergies: [
        AllergyRecord(
          substance: 'بنسلين',
          severity: AppConstants.riskLevelLow,
        ),
      ],
      chronicConditions: [
        ChronicConditionRecord(
          conditionName: 'ربو',
          diagnosedAt: DateTime(2019, 1, 1),
        ),
      ],
    );

void main() {
  const desk = CareCycleDesk();

  test('ألم الصدر تقرير أولي عاجل وليس تشخيصاً', () {
    final report = desk.report(
      complaint: 'ألم صدر منذ ساعة',
      duration: 'ساعة',
      severity: 'شديدة',
      patient: _person('p', 'ليان'),
    );
    expect(report.urgent, isTrue);
    expect(report.specialtyAr, 'طوارئ');
    expect(report.summaryAr, contains('طوارئ'));
    expect(report.hypothesesAr.join(' '), contains('ليست تشخيصاً'));
    expect(report.hypothesesAr.join(' '), contains('ربو'));
    expect(report.hypothesesAr.join(' '), contains('بنسلين'));
  });

  test('شكوى جلدية تبقى احتمالاً بلا طوارئ', () {
    final report = desk.report(
      complaint: 'حكة في الجلد',
      duration: 'يومين',
      severity: 'خفيفة',
      patient: HealthProfile(
        profileId: 'p2',
        fullName: 'نادر',
        dateOfBirth: DateTime(2000, 1, 1),
      ),
    );
    expect(report.urgent, isFalse);
    expect(report.specialtyAr, 'جلدية');
  });

  test('اعتماد الطبيب بلا موافقة لا ينسخ الرقم الوطني ولا السيرة', () {
    final patient = _person('p', 'ليان');
    final doctor = _person('d', 'د. هدى');
    ProfileBoxStore(patient).setString(BoxKeys.ownerNationalId, '9988');
    final result = desk.accredit(
      patient: patient,
      doctor: doctor,
      doctorName: 'د. هدى',
      complaint: 'حكة',
      shareFullRecord: false,
      fullRecordText: 'سيرة لا يجوز إرسالها',
    );
    final inbox =
        ProfileBoxStore(doctor).list(BoxKeys.accreditedPatientInbox).single;
    expect(result.deliveredToDoctor, isTrue);
    expect(inbox['nationalId'], '');
    expect(inbox['detail'], '');
    expect(inbox['cv'], isNot(contains('سيرة لا يجوز')));
    expect(inbox['cv'], contains('الحد الأدنى'));
    expect(
      ProfileBoxStore(doctor).list(BoxKeys.doctorNotices),
      isNotEmpty,
    );
  });

  test('الحصة نفسها لا تُحجز مرتين', () {
    final doctor = _person('d', 'د. هدى');
    final day = DateTime(2026, 10, 13);
    expect(
      desk.holdDoctorSlot(
        doctor: doctor,
        patient: _person('p', 'ليان'),
        day: day,
        time: '09:00',
        workHours: 12,
        examMinutes: 30,
        startHour: 9,
      ),
      isNull,
    );
    expect(
      desk.holdDoctorSlot(
        doctor: doctor,
        patient: _person('p2', 'آخر'),
        day: day,
        time: '09:00',
        workHours: 12,
        examMinutes: 30,
        startHour: 9,
      ),
      isNotNull,
    );
  });

  test('وقت الوحدة نفسه يُرفض في الحجز الثاني', () {
    final lab = _person('lab', 'مختبر النور');
    final at = DateTime(2026, 10, 13, 11, 30);
    expect(
      desk.holdUnitSlot(
        provider: lab,
        patient: _person('p', 'ليان'),
        unitKind: 'مختبر',
        at: at,
      ),
      isNull,
    );
    expect(
      desk.holdUnitSlot(
        provider: lab,
        patient: _person('p2', 'آخر'),
        unitKind: 'مختبر',
        at: at,
      ),
      isNotNull,
    );
  });

  test('قبول الصيدلي ينقص المخزون والقبول الثاني يُرفض', () {
    final pharmacy = _person('ph', 'صيدلية الورد');
    final patient = _person('p', 'ليان');
    final stock = <Map<String, dynamic>>[];
    const PharmacyStockLedger().apply(
      stock: stock,
      code: 'RX1',
      name: 'صنف مكوّد',
      materialKind: 'دواء',
      flow: PharmacyFlow.purchase,
      units: 5,
    );
    ProfileBoxStore(pharmacy).setList(BoxKeys.pharmacyStock, stock);
    final first = desk.requestCodedStock(
      patient: patient,
      pharmacy: pharmacy,
      code: 'RX1',
      units: 5,
    );
    expect(first, contains('قيد المراجعة'));
    expect(
      ProfileBoxStore(pharmacy).list(BoxKeys.pharmacyStock).single['quantity'],
      5,
    );
    final accepted = desk.acceptCodedStock(
      pharmacy: pharmacy,
      code: 'RX1',
      units: 5,
    );
    expect(accepted, contains('الإحصاء'));
    expect(
      ProfileBoxStore(pharmacy).list(BoxKeys.pharmacyStock).single['quantity'],
      0,
    );
    final secondRequest = desk.requestCodedStock(
      patient: patient,
      pharmacy: pharmacy,
      code: 'RX1',
      units: 1,
    );
    expect(secondRequest, contains('لا تسجّل كمية كافية'));
    final again = desk.acceptCodedStock(
      pharmacy: pharmacy,
      code: 'RX1',
      units: 5,
    );
    expect(again, contains('لم يُنقص'));
  });

  test('العرض 5٪ ويبقى قيد الانتظار والإعفاء يلغي العمولة', () {
    final quote = desk.quote(payer: _person('p', 'ليان'), grossMinor: 10000);
    expect(quote.commissionMinor, 500);
    expect(quote.providerMinor, 9500);
    expect(quote.status, 'pending');
    expect(quote.messageAr, contains('ليست ناجحة'));
    final refund = desk.requestRefund(quote);
    expect(refund.status, 'refundRequested');
    expect(refund.messageAr, contains('فلم يُرجَع مبلغ'));

    final exempt = desk.quote(
      payer: HealthProfile(
        profileId: 'ex',
        fullName: 'معفى',
        dateOfBirth: DateTime(1990, 1, 1),
        isPersonOfDetermination: true,
        accountCountry: 'سوريا',
        determinationCardKind: 'disabilityCard',
        determinationCardCountry: 'سوريا',
        determinationCardRef: 'ID-99',
      ),
      grossMinor: 10000,
    );
    expect(exempt.exempt, isTrue);
    expect(exempt.commissionMinor, 0);
    expect(exempt.providerMinor, 10000);
    expect(exempt.status, 'pending');
  });

  test('الاقتراح يجمع الاختصاص والمسافة', () {
    final report = desk.suggest(
      latitude: 33.5,
      longitude: 36.3,
      specialty: 'قلب',
      boxes: [
        CareBox(
          kindAr: 'طبيب',
          specialtyApplies: true,
          rows: [
            {
              'title': 'بعيد',
              'detail': 'قلب',
              'latitude': 34.5,
              'longitude': 36.3,
            },
            {
              'title': 'قريب',
              'detail': 'قلب',
              'latitude': 33.51,
              'longitude': 36.3,
            },
            {
              'title': 'جلد',
              'detail': 'جلدية',
              'latitude': 33.5001,
              'longitude': 36.3,
            },
          ],
        ),
      ],
    );
    expect(report.doctors.first.title, 'قريب');
    expect(report.doctors.any((item) => item.title == 'جلد'), isFalse);
  });
}
