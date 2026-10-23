import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/messaging/phone_messenger_desk.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';

void main() {
  HealthProfile person(String id, String phone) => HealthProfile(
        profileId: id,
        fullName: id,
        questionnaireData: {'accountPhone': phone},
      );

  const desk = PhoneMessengerDesk();

  test('رقم الهاتف يطابق الملف على الجهاز ولا يفتح شبكة', () {
    final me = person('me', '+963900000111');
    final peer = person('peer', '963900000222');
    final hit = desk.plan(
      me: me,
      peers: [peer],
      rawPhone: '963 900 000 222',
      path: MessengerPhonePath.onDevice,
    );
    expect(hit.ok, isTrue);
    expect(hit.profileId, 'peer');
    expect(hit.delivered, isTrue);
    expect(hit.transportOpen, isFalse);
    expect(
      desk.plan(
        me: me,
        peers: [peer],
        rawPhone: 'أحمد',
        path: MessengerPhonePath.onDevice,
      ).phraseKey,
      'phoneShort',
    );
    expect(
      desk.plan(
        me: me,
        peers: [peer],
        rawPhone: '900000222',
        path: MessengerPhonePath.onDevice,
      ).phraseKey,
      'phoneMissing',
    );
    expect(
      desk.plan(
        me: me,
        peers: [peer],
        rawPhone: me.questionnaireData['accountPhone'] as String,
        path: MessengerPhonePath.onDevice,
      ).phraseKey,
      'phoneSelf',
    );
  });

  test('الرسالة القصيرة مسودة والواي فاي والبلوتوث بلا نقل', () {
    final me = person('me', '963900000111');
    final peer = person('peer', '963900000222');
    final draft = desk.plan(
      me: me,
      peers: [peer],
      rawPhone: '963900000222',
      path: MessengerPhonePath.sms,
      smsDraftOpened: true,
    );
    expect(draft.ok, isTrue);
    expect(draft.delivered, isFalse);
    expect(draft.transportOpen, isFalse);
    expect(draft.phraseKey, 'smsDraftOpened');
    final wifi = desk.plan(
      me: me,
      peers: [peer],
      rawPhone: '963900000222',
      path: MessengerPhonePath.wifi,
    );
    final bluetooth = desk.plan(
      me: me,
      peers: [peer],
      rawPhone: '963900000222',
      path: MessengerPhonePath.bluetooth,
    );
    expect(wifi.phraseKey, 'wifiUnbound');
    expect(bluetooth.phraseKey, 'bluetoothUnbound');
    expect(wifi.transportOpen, isFalse);
    expect(bluetooth.delivered, isFalse);
  });
}
