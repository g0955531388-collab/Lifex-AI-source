import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/messaging/messenger_desk.dart';
import 'package:lifex_ai/features/messaging/messenger_phrases.dart';
import 'package:lifex_ai/features/network_box/profile_box_store.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';

void main() {
  HealthProfile person(String id) =>
      HealthProfile(profileId: id, fullName: id);

  test('المسنجر محلي واللغة تسقط إلى الإنجليزية والاتصال لا يتصل', () {
    expect(MessengerPhrases.line('ar', 'title').text, 'المسنجر');
    expect(MessengerPhrases.line('fr', 'title').fallback, isFalse);
    expect(MessengerPhrases.line('zz', 'title').fallback, isTrue);
    expect(MessengerPhrases.line('zz', 'title').text, 'Messenger');

    const desk = MessengerDesk();
    expect(desk.bridgesLiveMedia, isFalse);
    final me = person('me');
    final peer = person('peer');
    final group = desk.createGroup(
      creator: me,
      members: [peer],
      title: 'العيادة',
    );
    expect(group.ok, isTrue);
    final sent = desk.post(
      from: me,
      audience: [peer],
      threadId: group.id!,
      text: 'ملف المتابعة',
      fileName: 'note.jpg',
      sizeBytes: 20,
      subscriber: false,
    );
    expect(sent.ok, isTrue);
    expect(
      ProfileBoxStore(peer).list(BoxKeys.messengerGroupPosts).single['serverDeliveryConfirmed'],
      isFalse,
    );

    final call = desk.placeCall(host: me, peer: peer, kind: 'video');
    expect(call.phraseKey, 'callNotBridged');
    final stored = ProfileBoxStore(me).list(BoxKeys.messengerCalls).single;
    expect(stored['state'], 'requested');
    expect(stored['transport'], isFalse);

    expect(
      desk.announce(
        mayAnnounce: false,
        from: me,
        audience: [peer],
        text: 'إعلان',
        subscriber: false,
      ).phraseKey,
      'announceDenied',
    );
    final note = desk.urgentBloodNote(
      from: me,
      audience: [peer],
      text: 'نحتاج O سالب',
      subscriber: false,
    );
    expect(note.phraseKey, 'bloodLocalSaved');
    final room = desk.openMeeting(host: me, members: [peer]);
    expect(room.phraseKey, 'meetingNotZoom');
    expect(
      ProfileBoxStore(me).list(BoxKeys.meetingRooms).single['videoBridge'],
      isFalse,
    );
    final named = HealthProfile(
      profileId: 'p2',
      fullName: 'أحمد',
      questionnaireData: {'accountLifexId': 'LX-200'},
    );
    expect(
      desk.findPeerByLifexId(me: me, peers: [named], rawId: 'LX-200')?.profileId,
      'p2',
    );
    expect(
      desk.findPeerByLifexId(me: me, peers: [named], rawId: 'أحمد'),
      isNull,
    );
    expect(
      desk.findPeerByLifexId(me: me, peers: [named], rawId: 'LX-20'),
      isNull,
    );
    expect(
      desk.findPeerByLifexId(me: named, peers: [me], rawId: 'LX-200'),
      isNull,
    );
    expect(MessengerPhrases.line('ar', 'idMissing').text, contains('هاتف آخر'));
  });
}
