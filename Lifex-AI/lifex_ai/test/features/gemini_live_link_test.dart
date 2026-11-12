import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/gemini_live_link.dart';

void main() {
  test('بلا إنترنت تُغلق الجلسة الجاهزة مرة واحدة', () {
    final first = geminiLiveLinkOrder(
      consent: true,
      online: false,
      sessionReady: true,
      announcedOffline: false,
    );
    expect(first.step, GeminiLiveLinkStep.close);
    expect(first.announce, isTrue);
    final again = geminiLiveLinkOrder(
      consent: true,
      online: false,
      sessionReady: false,
      announcedOffline: true,
    );
    expect(again.step, GeminiLiveLinkStep.stayClosed);
    expect(again.announce, isFalse);
  });

  test('رجوع الإنترنت يعيد الفتح بعد الإعلان عن انقطاعه', () {
    final order = geminiLiveLinkOrder(
      consent: true,
      online: true,
      sessionReady: false,
      announcedOffline: true,
    );
    expect(order.step, GeminiLiveLinkStep.open);
    expect(order.announce, isTrue);
  });

  test('مع الإنترنت والجلسة الجاهزة تبقى الإطارات', () {
    final order = geminiLiveLinkOrder(
      consent: true,
      online: true,
      sessionReady: true,
      announcedOffline: false,
    );
    expect(order.step, GeminiLiveLinkStep.keep);
    expect(order.announce, isFalse);
  });

  test('SPOT يمسك الإرسال ثم يفلته', () async {
    await GeminiBlindLink.hold();
    expect(GeminiBlindLink.held, isTrue);
    GeminiBlindLink.release();
    expect(GeminiBlindLink.held, isFalse);
  });

  test('بلا موافقة لا يُفتح الاتصال', () {
    final order = geminiLiveLinkOrder(
      consent: false,
      online: true,
      sessionReady: false,
      announcedOffline: false,
    );
    expect(order.step, GeminiLiveLinkStep.stayClosed);
    expect(order.announce, isFalse);
  });
}
