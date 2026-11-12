import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/device_guardian/lost_phone_desk.dart';
import 'package:lifex_ai/features/voice/voice_turn_desk.dart';

void main() {
  final now = DateTime.utc(2026, 10, 14, 12);

  LostFix sample() => LostFix(
        latitude: 33.5,
        longitude: 36.3,
        accuracyMeters: 18,
        capturedAt: now,
      );

  test('التفعيل يحتاج موافقة وقياساً للبيانات والموقع', () {
    final desk = LostPhoneDesk();
    expect(
      desk.arm(userConsent: false, mobileDataOn: true, locationOn: true, now: now),
      contains('قبل موافقتك'),
    );
    expect(desk.armed, isFalse);
    expect(
      desk.arm(userConsent: true, mobileDataOn: null, locationOn: true, now: now),
      contains('لم أستطع قياس'),
    );
    expect(desk.armed, isFalse);
    expect(
      desk.arm(userConsent: true, mobileDataOn: true, locationOn: false, now: now),
      contains('مرفوض'),
    );
    final ready = desk.arm(
      userConsent: true,
      mobileDataOn: true,
      locationOn: true,
      now: now,
    );
    expect(desk.armed, isTrue);
    expect(ready, contains('لا يضمن'));
  });

  test('انقطاع البيانات بعد التفعيل يجعل الحماية محدودة', () {
    final desk = LostPhoneDesk();
    desk.arm(userConsent: true, mobileDataOn: true, locationOn: true, now: now);
    final limited = desk.observe(
      mobileDataOn: false,
      locationOn: true,
      now: now.add(const Duration(minutes: 5)),
    );
    expect(desk.armed, isFalse);
    expect(limited, contains('محدودة'));
    expect(limited, contains('لا أستطيع إجبار'));
  });

  test('الرمز الخاطئ يوقف التخمين ولا يُخزَّن واضحاً', () async {
    final desk = LostPhoneDesk();
    await desk.rememberSecret('2468');
    expect(desk.secretHash, isNot('2468'));
    expect(desk.toMap()['pinHash'], isNot('2468'));
    for (var i = 0; i < LostPhoneDesk.attemptLimit; i++) {
      await desk.acceptRemote(
        channelAuthenticated: true,
        secret: '0000',
        fresh: null,
        canSend: true,
        now: now,
        send: (_) async => true,
      );
    }
    final locked = await desk.acceptRemote(
      channelAuthenticated: true,
      secret: '2468',
      fresh: sample(),
      canSend: true,
      now: now,
      send: (_) async => true,
    );
    expect(locked, contains('موقوفة'));
    expect(desk.pendingUnsent, isFalse);
    expect(desk.events.join(), isNot(contains('2468')));
  });

  test('بلا قناة مصادق عليها لا يُرسل الموقع', () async {
    final desk = LostPhoneDesk();
    await desk.rememberSecret('2468');
    var called = false;
    final note = await desk.acceptRemote(
      channelAuthenticated: false,
      secret: '2468',
      fresh: sample(),
      canSend: true,
      now: now,
      send: (_) async {
        called = true;
        return true;
      },
    );
    expect(called, isFalse);
    expect(note, contains('لا تُقرأ تلقائياً'));
  });

  test('الموقع يُحفظ بلا شبكة ثم يُرسل عند عودتها فقط إذا نجحت القناة', () async {
    final desk = LostPhoneDesk();
    await desk.rememberSecret('2468');
    final held = await desk.acceptRemote(
      channelAuthenticated: true,
      secret: '2468',
      fresh: sample(),
      canSend: false,
      now: now,
      send: (_) async => true,
    );
    expect(held, contains('لم يُعلَن نجاح'));
    expect(desk.pendingUnsent, isTrue);
    final failed = await desk.retryPending(
      canSend: true,
      send: (_) async => false,
    );
    expect(failed, contains('فشلاً'));
    expect(desk.pendingUnsent, isTrue);
    final sent = await desk.retryPending(
      canSend: true,
      send: (_) async => true,
    );
    expect(sent, contains('أُرسلت النقطة'));
    expect(desk.pendingUnsent, isFalse);
  });

  test('بعد فقدان المسار الخلوي يُرسل عبر Wi-Fi دون ادّعاء رصد الشريحة', () async {
    final desk = LostPhoneDesk();
    desk.pending = sample();
    desk.pendingUnsent = true;
    final note = await desk.onPathChanged(
      hadMobilePath: false,
      onWifi: true,
      simEventKnown: false,
      simRemoved: false,
      canSend: true,
      send: (_) async => true,
    );
    expect(desk.events.first, contains('لم يُرصد'));
    expect(note, contains('أُرسلت النقطة'));
  });

  test('استعادة التطبيق لا تُعد فحصاً جديداً', () {
    final desk = LostPhoneDesk();
    desk.arm(userConsent: true, mobileDataOn: true, locationOn: true, now: now);
    final saved = desk.toMap();
    final restored = LostPhoneDesk()..restore(saved);
    expect(restored.lostMode, isFalse);
    expect(restored.readinessAr(), contains('ليست جاهزية حالية'));
    restored.enterLostMode();
    final again = LostPhoneDesk()..restore(restored.toMap());
    expect(again.lostMode, isTrue);
    expect(again.sessionChecked, isFalse);
  });

  test('أين جوالي يُعلن أنا هنا فقط إذا كان الاستماع متاحاً', () {
    final desk = LostPhoneDesk();
    expect(desk.nearbyReply(earAvailable: false), isNot(contains('أنا هنا.')));
    expect(desk.nearbyReply(earAvailable: true), contains('أنا هنا'));
    expect(desk.nearbyReply(earAvailable: true), contains('لا يضمن'));
    expect(planVoiceTurn('أين جوالي؟').kind, VoiceTurnKind.findPhone);
  });
}
