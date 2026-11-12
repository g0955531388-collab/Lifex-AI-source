import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/doctors/accredited_doctor_bond.dart';
import 'package:lifex_ai/features/doctors/doctor_remote_slot.dart';
import 'package:lifex_ai/features/doctors/public_slot_policy.dart';
import 'package:lifex_ai/features/network_box/profile_box_store.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';

HealthProfile _p(String id, String name) => HealthProfile(
      profileId: id,
      fullName: name,
      dateOfBirth: DateTime(1980, 1, 1),
    );

void main() {
  test('طبيبي المعتمد يوصل الإشعار والسي في لملف الطبيب على الجهاز', () {
    final patient = _p('p', 'سامي الحقيقي');
    final doctor = _p('d', 'د. هدى');
    final result = const AccreditedDoctorBond().accredit(
      patient: patient,
      doctor: doctor,
      doctorName: 'د. هدى',
      cvPlainText: 'سي في كامل',
      shareFullRecord: true,
    );
    expect(result.deliveredToDoctor, isTrue);
    final inbox = ProfileBoxStore(doctor).list(BoxKeys.accreditedPatientInbox);
    expect(inbox.single['title'], 'سامي الحقيقي');
    expect(inbox.single['cv'], contains('سي في'));
    expect(
      ProfileBoxStore(doctor).list(BoxKeys.doctorNotices),
      isNotEmpty,
    );
  });

  test('بلا اختيار صريح يصل الحد الأدنى فقط: بلا رقم وطني ولا حالات ولا سيرة', () {
    final patient = _p('p', 'سامي الحقيقي');
    ProfileBoxStore(patient).setString(BoxKeys.ownerNationalId, '0123456789');
    final doctor = _p('d', 'د. هدى');
    final minimum = AccreditedDoctorBond.minimumText(
      patient: patient,
      doctorName: 'د. هدى',
    );
    final result = const AccreditedDoctorBond().accredit(
      patient: patient,
      doctor: doctor,
      doctorName: 'د. هدى',
      cvPlainText: minimum,
    );
    expect(result.messageAr, contains('الحد الأدنى'));
    final row = ProfileBoxStore(doctor).list(BoxKeys.accreditedPatientInbox).single;
    expect(row['shareFullRecord'], isFalse);
    expect(row['nationalId'], isEmpty);
    expect(row['detail'], isEmpty);
    expect(row['cv'], minimum);
    expect(row['cv'], isNot(contains('0123456789')));
    final mine = ProfileBoxStore(patient).list(BoxKeys.doctorMyDoctors).single;
    expect(mine['cvSent'], isFalse);
  });

  test('12 ساعة وكل نصف ساعة تعطي 24 حصة عامة', () {
    final clocks = const PublicSlotPolicy().clocksFor(
      workHours: 12,
      stepMinutes: 30,
      startHour: 8,
    );
    expect(clocks, hasLength(24));
  });

  test('المريض يحجز حصة فارغة فقط', () {
    final doctor = _p('d', 'د. هدى');
    final patient = _p('p', 'سامي');
    final first = const DoctorRemoteSlot().book(
      doctor: doctor,
      patient: patient,
      day: DateTime(2026, 9, 17),
      time: '09:00',
      workHours: 12,
      examMinutes: 30,
      startHour: 9,
    );
    expect(first, isNull);
    final again = const DoctorRemoteSlot().book(
      doctor: doctor,
      patient: _p('p2', 'آخر'),
      day: DateTime(2026, 9, 17),
      time: '09:00',
      workHours: 12,
      examMinutes: 30,
      startHour: 9,
    );
    expect(again, isNotNull);
  });
}
