import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/location/unit_exchange_desk.dart';
import 'package:lifex_ai/features/location/unit_place_stamp.dart';
import 'package:lifex_ai/features/network_box/profile_box_store.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';

void main() {
  HealthProfile person(String id, String seat, {String address = ''}) {
    final profile = HealthProfile(
      profileId: id,
      fullName: id,
      billingSeat: seat,
    );
    if (address.isNotEmpty) {
      ProfileBoxStore(profile).setString(BoxKeys.residencePlace, address);
    }
    return profile;
  }

  test('موقع الوحدة يُكتب من إحداثيات صادقة والعنوان لا يُخترع', () {
    const stamp = UnitPlaceStamp();
    final personFile = person('p', 'individual');
    final refused = stamp.writeDeviceFix(
      unit: personFile,
      latitude: 33.5,
      longitude: 36.3,
    );
    expect(refused.wrote, isFalse);
    expect(ProfileBoxStore(personFile).map(BoxKeys.unitOwnPlace), isEmpty);

    final hospital = person('h', 'hospital', address: 'شارع بغداد');
    expect(
      stamp.writeDeviceFix(unit: hospital, latitude: 0, longitude: 0).wrote,
      isFalse,
    );
    final wrote = stamp.writeDeviceFix(
      unit: hospital,
      latitude: 33.51,
      longitude: 36.29,
      knownAddress: 'شارع بغداد',
    );
    expect(wrote.wrote, isTrue);
    final place = ProfileBoxStore(hospital).map(BoxKeys.unitOwnPlace);
    expect(place['addressKnown'], isTrue);
    expect(place['addressText'], 'شارع بغداد');
    expect(place['source'], 'device');

    final bare = person('b', 'healthUnit');
    stamp.writeDeviceFix(unit: bare, latitude: 33.52, longitude: 36.30);
    final barePlace = ProfileBoxStore(bare).map(BoxKeys.unitOwnPlace);
    expect(barePlace['addressKnown'], isFalse);
    expect(barePlace['addressText'], '');
  });

  test('التبادل نص فقط بعد الموافقة والأقرب هو الوحدة ذات الموقع', () {
    const desk = UnitExchangeDesk();
    final doctor = person('doc', 'hospital');
    final near = person('near', 'healthUnit');
    final far = person('far', 'healthUnit');
    final citizen = person('citizen', 'individual');
    const stamp = UnitPlaceStamp();
    stamp.writeDeviceFix(unit: doctor, latitude: 33.50, longitude: 36.29);
    stamp.writeDeviceFix(unit: near, latitude: 33.51, longitude: 36.30);
    stamp.writeDeviceFix(unit: far, latitude: 34.80, longitude: 38.00);

    expect(
      desk.nearestUnit(from: doctor, profiles: [doctor, near, far, citizen])
          ?.profileId,
      'near',
    );

    final blocked = desk.send(
      from: doctor,
      to: near,
      purpose: 'lab',
      text: 'تحليل سكر',
      patientAllowsShare: false,
    );
    expect(blocked.ok, isFalse);
    expect(ProfileBoxStore(near).list(BoxKeys.unitExchange), isEmpty);

    final sent = desk.send(
      from: doctor,
      to: near,
      purpose: 'doctorRequest',
      text: 'طلب معاينة',
      patientAllowsShare: true,
      patientProfileId: 'patient-1',
    );
    expect(sent.ok, isTrue);
    final packet = ProfileBoxStore(near).list(BoxKeys.unitExchange).single;
    expect(packet['text'], 'طلب معاينة');
    expect(packet['serverDeliveryConfirmed'], isFalse);
    expect(packet.containsKey('allergies'), isFalse);
    expect(packet['distanceKm'], isNotNull);
    expect(ProfileBoxStore(doctor).list(BoxKeys.unitExchange).single['id'], sent.packetId);

    final outsider = desk.answer(
      unit: far,
      profiles: [doctor, near, far],
      packetId: sent.packetId!,
      note: 'رد',
    );
    expect(outsider.ok, isFalse);

    final answered = desk.answer(
      unit: near,
      profiles: [doctor, near],
      packetId: sent.packetId!,
      note: 'الموعد غداً',
    );
    expect(answered.ok, isTrue);
    expect(
      ProfileBoxStore(doctor).list(BoxKeys.unitExchange).single['status'],
      'answered',
    );
    expect(
      ProfileBoxStore(doctor).list(BoxKeys.unitExchange).single['resultNote'],
      'الموعد غداً',
    );
  });

  test('طلب المخبر يقترح أقرب مختبر والاسم والمعرّف يجدان الوحدة', () {
    const desk = UnitExchangeDesk();
    const stamp = UnitPlaceStamp();
    final doctor = person('doc', 'hospital');
    final hospital = person('hosp', 'hospital');
    hospital.fullName = 'مستشفى قريب';
    final lab = person('lab-1', 'lab');
    lab.fullName = 'مخبر الشام';
    stamp.writeDeviceFix(unit: doctor, latitude: 33.50, longitude: 36.29);
    stamp.writeDeviceFix(unit: hospital, latitude: 33.501, longitude: 36.291);
    stamp.writeDeviceFix(unit: lab, latitude: 33.55, longitude: 36.35);

    expect(
      desk.nearestSpecialist(
        from: doctor,
        profiles: [doctor, hospital, lab],
        purpose: 'lab',
      )?.profile.profileId,
      'lab-1',
    );
    expect(
      desk.findRecipients(
        from: doctor,
        profiles: [doctor, hospital, lab],
        purpose: 'lab',
        query: 'الشام',
      ).single.profile.profileId,
      'lab-1',
    );
    expect(
      desk.findRecipients(
        from: doctor,
        profiles: [doctor, hospital, lab],
        purpose: 'imaging',
        query: 'hosp',
      ).single.profile.profileId,
      'hosp',
    );
  });
}
