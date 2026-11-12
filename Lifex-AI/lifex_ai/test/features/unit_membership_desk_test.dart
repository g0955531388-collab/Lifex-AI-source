import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/network_box/profile_box_store.dart';
import 'package:lifex_ai/features/network_box/unit_membership_desk.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';

void main() {
  test('المتابعة تُبقي الزائر زائراً، واعتماد الوحدة يجعله عضواً', () {
    final profile = HealthProfile(
      profileId: 'p1',
      fullName: 'ليان',
      statedAgeYears: 30,
    );
    final store = ProfileBoxStore(profile);
    const desk = UnitMembershipDesk();

    expect(
      desk.follow(
        store: store,
        unitId: 'labs',
        profileId: profile.profileId,
        displayName: profile.fullName,
      ),
      isTrue,
    );
    expect(
      desk.follow(
        store: store,
        unitId: 'labs',
        profileId: profile.profileId,
        displayName: profile.fullName,
      ),
      isFalse,
    );
    expect(desk.followers(store, 'labs'), hasLength(1));
    expect(desk.isVisitor(store, 'labs', profile.profileId), isTrue);

    expect(desk.notices(store, 'labs'), hasLength(1));
    expect(desk.notices(store, 'labs').single['title'], 'متابعة خارجية');
    expect(
      desk.notices(store, 'labs').single['detail'].toString(),
      contains('لا يحق'),
    );

    desk.accredit(
      store: store,
      unitId: 'labs',
      profileId: profile.profileId,
      displayName: profile.fullName,
    );
    expect(desk.isMember(store, 'labs', profile.profileId), isTrue);
    expect(desk.notices(store, 'labs'), hasLength(2));
    expect(desk.notices(store, 'labs').last['title'], 'تسجيل عضوية');
    expect(
      desk.notices(store, 'labs').last['detail'].toString(),
      contains('فحص ملفه'),
    );
    expect(
      desk.mayExamineHealthFile(store, 'labs', profile.profileId),
      isTrue,
    );
    expect(desk.isVisitor(store, 'labs', profile.profileId), isFalse);
    expect(desk.followers(store, 'labs'), hasLength(1));

    desk.leave(
      store: store,
      unitId: 'labs',
      profileId: profile.profileId,
    );
    expect(desk.isVisitor(store, 'labs', profile.profileId), isTrue);
    expect(
      desk.mayExamineHealthFile(store, 'labs', profile.profileId),
      isFalse,
    );
    expect(desk.isFollowing(store, 'labs', profile.profileId), isTrue);
  });
}
