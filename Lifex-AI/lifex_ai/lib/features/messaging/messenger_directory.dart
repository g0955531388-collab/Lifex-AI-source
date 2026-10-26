/// تسجيل المسنجر على الملف نفسه: هاتف أو بريد، واسم مستعار للعرض.
/// الاسم المستعار ليس مفتاح بحث وليس شخصاً جديداً.
/// من لا يملك الرقم أو البريد لا يجد الملف.
library lifex_ai.features.messaging.messenger_directory;

import '../profile/health_profile.dart';
import 'messenger_desk.dart';
import 'phone_messenger_desk.dart';

class MessengerDirectory {
  const MessengerDirectory();

  static const aliasKey = 'messengerAlias';
  static const placeKey = 'messengerPlace';

  static String normalizeEmail(String raw) {
    final email = raw.trim().toLowerCase();
    final at = email.indexOf('@');
    if (at <= 0 || at != email.lastIndexOf('@')) return '';
    final domain = email.substring(at + 1);
    if (!domain.contains('.') || domain.startsWith('.') || domain.endsWith('.')) {
      return '';
    }
    return email;
  }

  static String emailOf(HealthProfile profile) {
    final stored = profile.questionnaireData['accountEmail'];
    if (stored is! String) return '';
    return normalizeEmail(stored);
  }

  static String aliasOf(HealthProfile profile) {
    final stored = profile.questionnaireData[aliasKey];
    if (stored is! String) return '';
    return stored.trim();
  }

  /// اسم العرض. الاسم القانوني لا يُعاد من هنا.
  static String labelOf(HealthProfile profile) => aliasOf(profile);

  /// null عند النجاح. غير ذلك مفتاح العبارة.
  String? register({
    required HealthProfile me,
    required String alias,
    String rawPhone = '',
    String rawEmail = '',
    String rawPlace = '',
  }) {
    final name = alias.trim();
    if (name.length < 2) return 'aliasShort';
    final phone = PhoneMessengerDesk.digitsOf(rawPhone);
    final email = normalizeEmail(rawEmail);
    if (phone.isEmpty && email.isEmpty) return 'needPhoneOrEmail';
    if (phone.isNotEmpty) me.questionnaireData['accountPhone'] = phone;
    if (email.isNotEmpty) me.questionnaireData['accountEmail'] = email;
    final place = rawPlace.trim();
    if (place.isNotEmpty) me.questionnaireData[placeKey] = place;
    me.questionnaireData[aliasKey] = name;
    return null;
  }

  static String placeOf(HealthProfile profile) {
    for (final key in [placeKey, 'city', 'accountCity']) {
      final value = profile.questionnaireData[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  /// بحث محلي بالاسم أو المعرّف أو المكان. لا يفتح شبكة.
  List<MessengerSearchHit> search({
    required HealthProfile me,
    required List<HealthProfile> peers,
    required String query,
  }) {
    final raw = query.trim();
    final folded = raw.toLowerCase();
    if (raw.isEmpty) return const [];
    final hits = <MessengerSearchHit>[];
    for (final peer in peers) {
      if (peer.profileId == me.profileId) continue;
      if (_idHit(peer, raw)) {
        hits.add(MessengerSearchHit(profile: peer, via: 'id'));
      } else if (folded.length >= 2 && _nameHit(peer, folded)) {
        hits.add(MessengerSearchHit(profile: peer, via: 'name'));
      } else if (folded.length >= 2 && _placeHit(peer, folded)) {
        hits.add(MessengerSearchHit(profile: peer, via: 'place'));
      }
    }
    return hits;
  }

  bool _idHit(HealthProfile peer, String raw) {
    return MessengerDesk.lifexIdOf(peer) == raw || peer.profileId.trim() == raw;
  }

  bool _nameHit(HealthProfile peer, String folded) {
    final alias = aliasOf(peer).toLowerCase();
    final legal = peer.fullName.trim().toLowerCase();
    return (alias.isNotEmpty && alias.contains(folded)) ||
        (legal.isNotEmpty && legal.contains(folded));
  }

  bool _placeHit(HealthProfile peer, String folded) {
    final place = placeOf(peer).toLowerCase();
    return place.isNotEmpty && place.contains(folded);
  }

  /// مطابقة تامة للرقم أو للبريد. الاسم المستعار لا يطابق أحداً.
  HealthProfile? find({
    required HealthProfile me,
    required List<HealthProfile> peers,
    String rawPhone = '',
    String rawEmail = '',
  }) {
    final phone = PhoneMessengerDesk.digitsOf(rawPhone);
    final email = normalizeEmail(rawEmail);
    if (phone.isEmpty && email.isEmpty) return null;
    if (phone.isNotEmpty && phone == PhoneMessengerDesk.phoneOf(me)) return null;
    if (email.isNotEmpty && email == emailOf(me)) return null;
    final hits = [
      for (final peer in peers)
        if (peer.profileId != me.profileId &&
            ((phone.isNotEmpty && PhoneMessengerDesk.phoneOf(peer) == phone) ||
                (email.isNotEmpty && emailOf(peer) == email)))
          peer,
    ];
    if (hits.length != 1) return null;
    return hits.single;
  }
}

class MessengerSearchHit {
  const MessengerSearchHit({required this.profile, required this.via});

  final HealthProfile profile;

  /// name أو id أو place.
  final String via;
}
