/// تعريف المسنجر برقم الهاتف. لا واتساب ولا جسر فيديو.
library lifex_ai.features.messaging.phone_messenger_desk;

import '../profile/health_profile.dart';

enum MessengerPhonePath { onDevice, sms, wifi, bluetooth }

class MessengerPhonePlan {
  const MessengerPhonePlan({
    required this.ok,
    required this.phraseKey,
    this.profileId,
    this.digits = '',
    this.delivered = false,
    this.transportOpen = false,
  });

  final bool ok;
  final String phraseKey;
  final String? profileId;
  final String digits;

  /// وصلت إلى ملف على هذا الجهاز. ليست تأكيداً لشبكة خارجية.
  final bool delivered;

  /// قناة واي فاي أو بلوتوث مفتوحة نحو طرف آخر.
  final bool transportOpen;
}

class PhoneMessengerDesk {
  const PhoneMessengerDesk();

  static String digitsOf(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 8) return '';
    return digits;
  }

  static String phoneOf(HealthProfile profile) {
    final stored = profile.questionnaireData['accountPhone'];
    if (stored is! String) return '';
    return digitsOf(stored);
  }

  MessengerPhonePlan plan({
    required HealthProfile me,
    required List<HealthProfile> peers,
    required String rawPhone,
    required MessengerPhonePath path,
    bool smsDraftOpened = false,
  }) {
    final digits = digitsOf(rawPhone);
    if (digits.isEmpty) {
      return const MessengerPhonePlan(ok: false, phraseKey: 'phoneShort');
    }
    if (digits == phoneOf(me)) {
      return MessengerPhonePlan(
        ok: false,
        phraseKey: 'phoneSelf',
        digits: digits,
      );
    }
    final hits = [
      for (final peer in peers)
        if (peer.profileId != me.profileId && phoneOf(peer) == digits) peer,
    ];
    final peer = hits.length == 1 ? hits.single : null;
    switch (path) {
      case MessengerPhonePath.onDevice:
        if (peer == null) {
          return MessengerPhonePlan(
            ok: false,
            phraseKey: 'phoneMissing',
            digits: digits,
          );
        }
        return MessengerPhonePlan(
          ok: true,
          phraseKey: 'deliveredHere',
          profileId: peer.profileId,
          digits: digits,
          delivered: true,
        );
      case MessengerPhonePath.sms:
        return MessengerPhonePlan(
          ok: smsDraftOpened,
          phraseKey: smsDraftOpened ? 'smsDraftOpened' : 'smsDraftFailed',
          profileId: peer?.profileId,
          digits: digits,
        );
      case MessengerPhonePath.wifi:
        return MessengerPhonePlan(
          ok: false,
          phraseKey: 'wifiUnbound',
          digits: digits,
        );
      case MessengerPhonePath.bluetooth:
        return MessengerPhonePlan(
          ok: false,
          phraseKey: 'bluetoothUnbound',
          digits: digits,
        );
    }
  }
}
