import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/dental/dental_dashboard.dart';
import 'package:lifex_ai/features/messaging/conversation_type_router.dart';
import 'package:lifex_ai/features/network_box/profile_box_store.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';

void main() {
  HealthProfile profile() => HealthProfile(
        profileId: 'p-session',
        fullName: 'اختبار',
        dateOfBirth: DateTime(1990, 1, 1),
      );

  test('جلسة الأسنان تُرفض بلا نوع أو مدة أو سعر سالب ثم تُحفظ في الصندوق', () {
    final dashboard = DentalDashboard();
    expect(
      dashboard.recordSession(
        patientProfileId: 'p-session',
        dentalProviderId: 'den-1',
        workTypeAr: ' ',
        duration: const Duration(minutes: 20),
        materialsConsumed: const [],
        priceMinorUnits: 100,
      ),
      isNull,
    );
    expect(
      dashboard.recordSession(
        patientProfileId: 'p-session',
        dentalProviderId: 'den-1',
        workTypeAr: 'حشو',
        duration: Duration.zero,
        materialsConsumed: const [],
        priceMinorUnits: 100,
      ),
      isNull,
    );
    expect(
      dashboard.recordSession(
        patientProfileId: 'p-session',
        dentalProviderId: '',
        workTypeAr: 'حشو',
        duration: const Duration(minutes: 20),
        materialsConsumed: const [],
        priceMinorUnits: 100,
      ),
      isNull,
    );
    final session = dashboard.recordSession(
      patientProfileId: 'p-session',
      dentalProviderId: 'den-1',
      workTypeAr: 'حشو',
      duration: const Duration(minutes: 30),
      materialsConsumed: const ['كومبوزيت'],
      priceMinorUnits: 2500,
    );
    expect(session, isNotNull);
    final store = ProfileBoxStore(profile());
    store.add(BoxKeys.dentalSessions, {
      'sessionId': session!.sessionId,
      'workTypeAr': session.workTypeAr,
      'durationMinutes': session.duration.inMinutes,
      'priceMinorUnits': session.priceMinorUnits,
    });
    final saved = store.list(BoxKeys.dentalSessions).single;
    expect(saved['workTypeAr'], 'حشو');
    expect(saved['priceMinorUnits'], 2500);
    expect(saved['durationMinutes'], 30);
  });

  test('غرفة الاجتماع المحلية تحتاج مشاركَين وليست محادثة مباشرة', () {
    final router = ConversationTypeRouter();
    expect(
      router.openMeetingRoom(participantLifexIds: const ['only-me']),
      isNull,
    );
    final room = router.openMeetingRoom(
      participantLifexIds: const ['me', 'clinic', 'me'],
    );
    expect(room, isNotNull);
    expect(room!.type, ConversationType.meeting);
    expect(room.participantLifexIds, ['me', 'clinic']);
    final store = ProfileBoxStore(profile());
    store.add(BoxKeys.meetingRooms, {
      'conversationId': room.conversationId,
      'type': room.type.name,
      'participantLifexIds': room.participantLifexIds,
    });
    expect(store.list(BoxKeys.meetingRooms).single['type'], 'meeting');
  });
}
