import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/emergency/emergency_message_manager.dart';
import 'package:lifex_ai/features/emergency/emergency_phone_contacts_registry.dart';
import 'package:lifex_ai/features/emergency/risk_level_engine.dart';
import 'package:lifex_ai/features/emergency/emergency_manager.dart';
import 'package:lifex_ai/features/voice/emergency_voice_handler.dart';
import 'package:lifex_ai/core/license_manager.dart';

void main() {
  test('بدون قناة إرسال لا يدّعي وصول الاستغاثة', () async {
    final registry = EmergencyPhoneContactsRegistry();
    registry.replaceForProfile('p1', ['+963955531388']);
    final manager = EmergencyMessageManager(
      emergencyContactsRegistry: registry,
    );
    final outcome = await manager.dispatchEmergencyMessage(
      profileId: 'p1',
      caseId: 'EMG-1',
      riskLevel: 'critical',
      reasonAr: 'فحص',
    );
    expect(outcome.localCaseOpened, isTrue);
    expect(outcome.outboundSent, isFalse);
    expect(outcome.contactCount, 1);
    expect(outcome.messageAr, isNot(contains('أُرسلت الاستغاثة')));
    expect(outcome.messageAr, contains('غير مربوطة'));
  });

  test('جهات الثقة المحفوظة في الملف تُطوى إلى السجل', () {
    final phones = EmergencyPhoneContactsRegistry.phonesFromTrustedMaps([
      {'name': 'أب', 'phone': ' +963900000000 '},
      {'name': 'بدون رقم'},
    ]);
    expect(phones, ['+963900000000']);
    final registry = EmergencyPhoneContactsRegistry();
    registry.replaceForProfile('p1', phones);
    expect(registry.contactsFor('p1').single.phoneNumber, '+963900000000');
  });

  test('إطلاق الطوارئ يبقى محلياً حتى توجد قناة حقيقية', () async {
    final registry = EmergencyPhoneContactsRegistry();
    final manager = EmergencyManager(
      riskLevelEngine: RiskLevelEngine(),
      messageManager: EmergencyMessageManager(
        emergencyContactsRegistry: registry,
      ),
    );
    final outcome = await manager.triggerEmergency(
      profileId: 'p1',
      reasonAr: 'فحص',
    );
    expect(outcome.outboundSent, isFalse);
    expect(outcome.messageAr, contains('لا أرقام ثقة'));
  });

  test('أوامر أنا بخير واتصل لا ترسل ولا تؤرشف فيديو', () {
    const voice = EmergencyVoiceHandler();
    expect(voice.isCancel('أنا بخير'), isTrue);
    expect(voice.isEscalate('اتصل بالطوارئ'), isTrue);
    expect(voice.mayArchiveVideoOrStills, isFalse);
    expect(voice.mayUseSimulatedAudioClassifier, isFalse);
    expect(voice.mayInventGps, isFalse);
    expect(voice.escalateAr(), contains('غير مربوطة'));
    expect(voice.cancelAr(), contains('لم يُلتقط فيديو'));
  });

  test('الإسناد لا يُكرَّر إذا وُجد اسم المخترع', () {
    const notice =
        'تم تصنيف وإعداد هذه الموسوعة العلمية وأجهزة الفحص من قبل خبير الهندسة الطبية المصمم العالمي غازي سليم بكفلاوي';
    final once = LicenseManager.instance.appendAr(notice);
    expect(once, notice);
    expect(LicenseManager.instance.appendAr(once), notice);
  });

  test('مسودة SMS لا تُعدّ إرسالاً ناجحاً', () async {
    final registry = EmergencyPhoneContactsRegistry();
    registry.replaceForProfile('p1', ['+963955531388']);
    final manager = EmergencyMessageManager(
      emergencyContactsRegistry: registry,
      draftHandoffFunction: (phone, msg) async => true,
    );
    final outcome = await manager.dispatchEmergencyMessage(
      profileId: 'p1',
      caseId: 'EMG-2',
      riskLevel: 'critical',
      reasonAr: 'فحص',
    );
    expect(outcome.outboundSent, isFalse);
    expect(outcome.messageAr, contains('مسودة SMS'));
    expect(outcome.messageAr, isNot(contains('أُرسلت الاستغاثة')));
  });
}
