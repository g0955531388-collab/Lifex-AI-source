/// مسنجر محلي: محادثات ومجموعات وملفات وإعلان ونداء دم وقاعة وطلب اتصال.
/// لا جسر صوت أو فيديو إلى هاتف آخر.
library lifex_ai.features.messaging.messenger_desk;

import '../network_box/profile_box_store.dart';
import '../profile/health_profile.dart';
import 'conversation_type_router.dart';
import 'health_channel_filter.dart';

class MessengerAction {
  const MessengerAction({
    required this.ok,
    required this.phraseKey,
    this.id,
  });

  final bool ok;
  final String phraseKey;
  final String? id;
}

class MessengerDesk {
  const MessengerDesk({this.filter = const HealthChannelFilter()});

  final HealthChannelFilter filter;

  static const callStateRequested = 'requested';

  static String lifexIdOf(HealthProfile profile) {
    final stored = profile.questionnaireData['accountLifexId'];
    if (stored is String && stored.trim().isNotEmpty) return stored.trim();
    return profile.profileId.trim();
  }

  /// مطابقة تامة لمعرّف Lifex أو معرّف الملف على هذا الجهاز. لا مطابقة بالاسم.
  HealthProfile? findPeerByLifexId({
    required HealthProfile me,
    required List<HealthProfile> peers,
    required String rawId,
  }) {
    final id = rawId.trim();
    if (id.isEmpty || id == lifexIdOf(me)) return null;
    final hits = [
      for (final peer in peers)
        if (peer.profileId != me.profileId &&
            (lifexIdOf(peer) == id || peer.profileId.trim() == id))
          peer,
    ];
    if (hits.length != 1) return null;
    return hits.single;
  }

  List<Map<String, dynamic>> groupsFor(HealthProfile me) =>
      ProfileBoxStore(me).list(BoxKeys.messengerGroups);

  List<Map<String, dynamic>> posts(HealthProfile me, String threadId) {
    return ProfileBoxStore(me)
        .list(BoxKeys.messengerGroupPosts)
        .where((item) => item['threadId'] == threadId)
        .toList();
  }

  List<Map<String, dynamic>> callsFor(HealthProfile me) =>
      ProfileBoxStore(me).list(BoxKeys.messengerCalls);

  List<Map<String, dynamic>> announcementsFor(HealthProfile me) =>
      ProfileBoxStore(me).list(BoxKeys.messengerAnnouncements);

  List<Map<String, dynamic>> bloodNotesFor(HealthProfile me) =>
      ProfileBoxStore(me).list(BoxKeys.messengerBloodNotes);

  bool get bridgesLiveMedia => false;

  MessengerAction createGroup({
    required HealthProfile creator,
    required List<HealthProfile> members,
    required String title,
  }) {
    final name = title.trim();
    if (name.isEmpty) {
      return const MessengerAction(ok: false, phraseKey: 'needTitle');
    }
    final people = <String, HealthProfile>{
      for (final member in [creator, ...members]) member.profileId: member,
    };
    if (people.length < 2) {
      return const MessengerAction(ok: false, phraseKey: 'needMember');
    }
    final id = 'MG-${DateTime.now().microsecondsSinceEpoch}';
    final record = {
      'id': id,
      'title': name,
      'memberIds': people.keys.toList(),
      'createdBy': creator.profileId,
      'createdAt': DateTime.now().toIso8601String(),
    };
    for (final member in people.values) {
      ProfileBoxStore(member).add(BoxKeys.messengerGroups, record);
    }
    return MessengerAction(ok: true, phraseKey: 'sentHere', id: id);
  }

  MessengerAction post({
    required HealthProfile from,
    required List<HealthProfile> audience,
    required String threadId,
    required String text,
    String fileName = '',
    int sizeBytes = 0,
    required bool subscriber,
    String boxKey = BoxKeys.messengerGroupPosts,
    String successKey = 'sentHere',
  }) {
    final trimmed = text.trim();
    final named = fileName.trim();
    if (trimmed.isEmpty && named.isEmpty) {
      return const MessengerAction(ok: false, phraseKey: 'empty');
    }
    final verdict = filter.inspect(
      type: ConversationType.direct,
      senderSeat: from.billingSeat,
      text: trimmed,
      fileName: named,
      sizeBytes: sizeBytes,
      subscriber: subscriber,
    );
    if (!verdict.allowed) {
      return MessengerAction(ok: false, phraseKey: _blocked(verdict.code));
    }
    final id = 'MP-${DateTime.now().microsecondsSinceEpoch}';
    final record = {
      'id': id,
      'threadId': threadId,
      'fromId': from.profileId,
      'text': trimmed,
      'fileName': named,
      'sizeBytes': sizeBytes,
      'at': DateTime.now().toIso8601String(),
      'serverDeliveryConfirmed': false,
    };
    final people = <String, HealthProfile>{
      for (final member in [from, ...audience]) member.profileId: member,
    };
    for (final member in people.values) {
      ProfileBoxStore(member).add(boxKey, record);
    }
    return MessengerAction(ok: true, phraseKey: successKey, id: id);
  }

  MessengerAction placeCall({
    required HealthProfile host,
    required HealthProfile peer,
    required String kind,
  }) {
    if (host.profileId == peer.profileId) {
      return const MessengerAction(ok: false, phraseKey: 'needMember');
    }
    if (kind != 'voice' && kind != 'video') {
      return const MessengerAction(ok: false, phraseKey: 'callNotBridged');
    }
    final id = 'MC-${DateTime.now().microsecondsSinceEpoch}';
    final record = {
      'id': id,
      'kind': kind,
      'hostId': host.profileId,
      'peerIds': [peer.profileId],
      'state': callStateRequested,
      'transport': false,
      'at': DateTime.now().toIso8601String(),
    };
    ProfileBoxStore(host).add(BoxKeys.messengerCalls, record);
    ProfileBoxStore(peer).add(BoxKeys.messengerCalls, record);
    return MessengerAction(ok: true, phraseKey: 'callNotBridged', id: id);
  }

  MessengerAction announce({
    required bool mayAnnounce,
    required HealthProfile from,
    required List<HealthProfile> audience,
    required String text,
    required bool subscriber,
  }) {
    if (!mayAnnounce) {
      return const MessengerAction(ok: false, phraseKey: 'announceDenied');
    }
    return post(
      from: from,
      audience: audience,
      threadId: 'admin-announcements',
      text: text,
      subscriber: subscriber,
      boxKey: BoxKeys.messengerAnnouncements,
      successKey: 'announceSent',
    );
  }

  MessengerAction urgentBloodNote({
    required HealthProfile from,
    required List<HealthProfile> audience,
    required String text,
    required bool subscriber,
  }) {
    return post(
      from: from,
      audience: audience,
      threadId: 'local-blood-urgent',
      text: text,
      subscriber: subscriber,
      boxKey: BoxKeys.messengerBloodNotes,
      successKey: 'bloodLocalSaved',
    );
  }

  MessengerAction openMeeting({
    required HealthProfile host,
    required List<HealthProfile> members,
  }) {
    final people = <String, HealthProfile>{
      for (final member in [host, ...members]) member.profileId: member,
    };
    if (people.length < 2) {
      return const MessengerAction(ok: false, phraseKey: 'needMember');
    }
    final room = ConversationTypeRouter().openMeetingRoom(
      participantLifexIds: people.keys.toList(),
    );
    if (room == null) {
      return const MessengerAction(ok: false, phraseKey: 'needMember');
    }
    final record = {
      'id': room.conversationId,
      'conversationId': room.conversationId,
      'type': room.type.name,
      'participantLifexIds': room.participantLifexIds,
      'createdAt': room.createdAt.toIso8601String(),
      'videoBridge': false,
    };
    for (final member in people.values) {
      ProfileBoxStore(member).add(BoxKeys.meetingRooms, record);
    }
    return MessengerAction(
      ok: true,
      phraseKey: 'meetingNotZoom',
      id: room.conversationId,
    );
  }

  static String _blocked(String code) {
    switch (code) {
      case 'adult':
      case 'adultClinical':
        return 'blockedAdult';
      case 'tooLarge':
        return 'blockedSize';
      default:
        return 'blockedProfanity';
    }
  }
}
