import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/medications/medication_alarm_engine.dart';
import 'package:lifex_ai/features/medications/medication_alarm_ledger.dart';
import 'package:lifex_ai/features/network_box/profile_box_store.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';

HealthProfile _p(String id, String name) => HealthProfile(
      profileId: id,
      fullName: name,
      dateOfBirth: DateTime(1990, 1, 1),
    );

void main() {
  const engine = MedicationAlarmEngine();

  test('المنبّه يذكر الاسم الحقيقي والدواء والساعة ثم يسكت بعد التناول', () {
    final alarm = MedicationAlarm(
      id: '1',
      profileId: 'a',
      personName: 'سامي',
      medicine: 'أومنتين',
      hour: 8,
      minute: 0,
    );
    final atEight = DateTime(2026, 9, 17, 8, 1);
    expect(engine.isDue(alarm, atEight), isTrue);
    final cue = engine.cue(alarm);
    expect(cue.spokenAr, startsWith('المريض سامي'));
    expect(cue.spokenAr, contains('أومنتين'));
    expect(cue.spokenAr, contains('08:00'));
    expect(cue.writtenAr, contains('وصفة'));
    final taken = engine.acknowledge(alarm, atEight);
    expect(engine.isDue(taken, atEight), isFalse);
    expect(engine.isDue(taken, DateTime(2026, 9, 18, 8, 1)), isTrue);
    final nameless = engine.cue(
      const MedicationAlarm(
        id: 'x',
        profileId: 'a',
        personName: '  ',
        medicine: 'أومنتين',
        hour: 8,
        minute: 0,
      ),
    );
    expect(nameless.spokenAr, contains('اسم المريض فارغ'));
    expect(nameless.spokenAr, isNot(contains('أومنتين')));
  });

  test('تم وتناولت يسكتان حتى الجرعة التالية لشخص آخر في الحساب', () {
    expect(MedicationAlarmEngine.isTakenSpeech('لقد تناولت الدواء'), isTrue);
    expect(MedicationAlarmEngine.isTakenSpeech('تم'), isTrue);
    final morning = MedicationAlarm(
      id: 'm',
      profileId: 'a',
      personName: 'سامي',
      medicine: 'أومنتين',
      hour: 8,
      minute: 0,
      lastTakenAt: DateTime(2026, 9, 17, 8, 5),
    );
    final evening = MedicationAlarm(
      id: 'e',
      profileId: 'b',
      personName: 'ليلى',
      medicine: 'فيتامين',
      hour: 20,
      minute: 0,
    );
    final next = engine.nextAfterTake(
      [morning, evening],
      morning,
      DateTime(2026, 9, 17, 8, 5),
    );
    expect(next?.personName, 'ليلى');
  });

  test('عدة أشخاص في الحساب الواحد لكل منهم منبّهه', () {
    final a = _p('a', 'سامي');
    final b = _p('b', 'ليلى');
    final ledger = MedicationAlarmLedger();
    ledger.add(profile: a, medicine: 'أومنتين', hour: 8, minute: 0);
    ledger.add(profile: b, medicine: 'فيتامين', hour: 21, minute: 0);
    expect(ledger.household([a, b]), hasLength(2));
    expect(
      ProfileBoxStore(a).list(BoxKeys.medicationAlarms),
      isNotEmpty,
    );
  });

  test('الصوت يؤكد التناول دون فتح السجل فقط', () {
    final parsed = CommandParser().parse('لقد تناولت الدواء');
    expect(parsed.intent, VoiceCommandIntent.confirmMedicationTaken);
  });
}
