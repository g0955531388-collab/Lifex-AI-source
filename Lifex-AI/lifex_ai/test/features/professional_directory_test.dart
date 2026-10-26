import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/directory/directory_alarm.dart';
import 'package:lifex_ai/features/directory/professional_directory.dart';

void main() {
  test('التسجيل يفتح تجربة 48 ساعة بلا دفع', () {
    final start = DateTime(2026, 10, 26, 8);
    final profile = newProfessionalProfile(
      id: 'p1',
      fullName: 'عيادة النور',
      category: ProfessionCategory.medical,
      specialty: 'جلدية',
      phone: '011',
      now: start,
    );
    expect(profile, isNotNull);
    expect(profile!.isPaid, isFalse);
    expect(profile.paymentProvider, isNull);
    expect(profile.expiry.difference(profile.trialStart), directoryTrialLength);
    expect(profile.trialActive(start.add(const Duration(hours: 47))), isTrue);
    expect(profile.trialActive(start.add(const Duration(hours: 48))), isFalse);
    expect(profile.listingActive(start.add(const Duration(hours: 49))), isFalse);
  });

  test('ملف بلا اسم أو تخصص أو هاتف لا يُقبل', () {
    expect(
      newProfessionalProfile(
        id: 'p',
        fullName: ' ',
        category: ProfessionCategory.legal,
        specialty: 'مدني',
        phone: '1',
        now: DateTime(2026, 1, 1),
      ),
      isNull,
    );
    expect(
      newProfessionalProfile(
        id: 'p',
        fullName: 'مكتب',
        category: 'unknown-trade',
        specialty: 'عقد',
        phone: '1',
        now: DateTime(2026, 1, 1),
      ),
      isNull,
    );
  });

  test('شام كاش والمحفظة لا يخصمان ولا يعلّمان الدفع', () {
    final sham = refuseDirectoryPayment('shamcash');
    final wallet = refuseDirectoryPayment('global_wallet');
    expect(sham.charged, isFalse);
    expect(sham.isPaid, isFalse);
    expect(wallet.charged, isFalse);
    expect(wallet.isPaid, isFalse);
    expect(sham.messageAr, contains('لم يُخصم'));
  });

  test('البحث يطابق التخصص ولا يخترع إحداثيات', () {
    final profile = newProfessionalProfile(
      id: 'p2',
      fullName: 'ورشة الخط',
      category: ProfessionCategory.crafts,
      specialty: 'نجارة',
      phone: '022',
      now: DateTime(2026, 5, 1),
      city: 'حمص',
    )!;
    expect(profile.point, isNull);
    final found = searchProfessionals([profile], 'نجارة');
    expect(found, hasLength(1));
    expect(searchProfessionals([profile], 'محاماة'), isEmpty);
  });

  test('عشر هويات بصرية', () {
    expect(directoryThemes, hasLength(10));
    expect(directoryThemeById('missing').id, 'general');
  });

  test('المنبه يتقدم ساعتين ثم ساعة ثم بحثاً مرة واحدة', () {
    final at = DateTime(2026, 10, 26, 15);
    final alarm = newDirectoryAlarm(
      id: 'a',
      userId: 'local',
      targetNameOrKeyword: 'حلاق',
      scheduled: at,
      reason: 'متابعة حجز',
      now: at.subtract(const Duration(days: 1)),
    )!;
    expect(dueDirectoryCue(alarm, at.subtract(const Duration(hours: 3))), isNull);
    final twoHours = dueDirectoryCue(
      alarm,
      at.subtract(const Duration(hours: 2)),
    );
    expect(twoHours, DirectoryAlarmCue.remind2h);
    final afterTwo = applyDirectoryCue(alarm, twoHours!);
    final oneHour = dueDirectoryCue(
      afterTwo,
      at.subtract(const Duration(minutes: 30)),
    );
    expect(oneHour, DirectoryAlarmCue.remind1h);
    final afterOne = applyDirectoryCue(afterTwo, oneHour!);
    expect(dueDirectoryCue(afterOne, at), DirectoryAlarmCue.searchNow);
    final done = applyDirectoryCue(afterOne, DirectoryAlarmCue.searchNow);
    expect(done.status, DirectoryAlarmStatus.executed);
    expect(dueDirectoryCue(done, at.add(const Duration(minutes: 5))), isNull);
    final phrase = directoryAlarmPhrase(
      alarm: alarm,
      cue: DirectoryAlarmCue.searchNow,
      arabic: true,
    );
    expect(phrase, contains('متابعة حجز'));
    expect(phrase, contains('حلاق'));
    expect(phrase.contains('تم الحجز'), isFalse);
  });

  test('منبه بلا سبب لا يُقبل', () {
    expect(
      newDirectoryAlarm(
        id: 'a',
        userId: 'local',
        targetNameOrKeyword: 'طبيب',
        scheduled: DateTime(2026, 1, 1, 9),
        reason: ' ',
        now: DateTime(2026, 1, 1),
      ),
      isNull,
    );
  });
}
