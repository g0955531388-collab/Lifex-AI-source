/// =============================================================
/// Lifex-AI — صندوق المشروع
/// متابعة خارجية واعتماد لكل وحدة، على هذا الجهاز.
/// الزائر يتابع من الخارج. اعتماد الوحدة يجعله عضواً.
/// الاعتماد ليس ترخيصاً وطنياً ولا يكشف ملفات الآخرين.
/// =============================================================
library lifex_ai.features.network_box.unit_membership_desk;

import 'profile_box_store.dart';

class UnitMembershipDesk {
  const UnitMembershipDesk();

  static String followersKey(String unitId) => 'unitExternalFollowers_$unitId';

  static String enrollmentKey(String unitId) => 'unitEnrollment_$unitId';

  static String examConsentKey(String unitId) => 'unitExamConsent_$unitId';

  static String noticesKey(String unitId) => 'unitNotices_$unitId';

  List<Map<String, dynamic>> notices(ProfileBoxStore store, String unitId) =>
      store.list(noticesKey(unitId));

  List<Map<String, dynamic>> followers(ProfileBoxStore store, String unitId) =>
      store.list(followersKey(unitId));

  bool isFollowing(ProfileBoxStore store, String unitId, String profileId) {
    return followers(store, unitId)
        .any((item) => item['profileId']?.toString() == profileId);
  }

  bool isMember(ProfileBoxStore store, String unitId, String profileId) {
    return store.stringField(enrollmentKey(unitId)) == profileId;
  }

  bool isVisitor(ProfileBoxStore store, String unitId, String profileId) =>
      !isMember(store, unitId, profileId);

  /// حق الفحص يثبت مع العضوية ويُسحب مع إلغاء الاعتماد.
  bool mayExamineHealthFile(
    ProfileBoxStore store,
    String unitId,
    String profileId,
  ) {
    if (!isMember(store, unitId, profileId)) return false;
    final consent = store.map(examConsentKey(unitId));
    if (consent.isEmpty) return true;
    return consent['granted'] == true &&
        consent['profileId']?.toString() == profileId;
  }

  /// متابعة من الواجهة الخارجية. الزائر يبقى زائراً.
  bool follow({
    required ProfileBoxStore store,
    required String unitId,
    required String profileId,
    required String displayName,
  }) {
    if (profileId.isEmpty || isFollowing(store, unitId, profileId)) {
      return false;
    }
    store.add(followersKey(unitId), {
      'profileId': profileId,
      'name': displayName.trim().isEmpty ? 'متابع' : displayName.trim(),
    });
    if (unitId == 'women') {
      store.setString(BoxKeys.womenMembership, 'interested');
    }
    _notify(
      store: store,
      unitId: unitId,
      profileId: profileId,
      name: displayName.trim().isEmpty ? 'متابع' : displayName.trim(),
      title: 'متابعة خارجية',
      detail: 'زائر جديد. لا يحق للوحدة فحص ملفه الصحي.',
    );
    return true;
  }

  /// اعتماد الوحدة: الزائر يصبح عضواً على هذا الجهاز.
  void accredit({
    required ProfileBoxStore store,
    required String unitId,
    required String profileId,
    required String displayName,
  }) {
    if (profileId.isEmpty) return;
    store.setString(enrollmentKey(unitId), profileId);
    store.setMap(examConsentKey(unitId), {
      'profileId': profileId,
      'granted': true,
      'purpose': 'unit_health_file_exam',
      'scope': 'health_file_on_this_device',
    });
    if (unitId == 'women') {
      store.setString(BoxKeys.womenMembership, 'enrolled');
    }
    final name = displayName.trim().isEmpty ? 'عضو' : displayName.trim();
    _notify(
      store: store,
      unitId: unitId,
      profileId: profileId,
      name: name,
      title: 'تسجيل عضوية',
      detail: 'أصبح عضواً. يحق للوحدة فحص ملفه الصحي على هذا الجهاز.',
    );
  }

  void leave({
    required ProfileBoxStore store,
    required String unitId,
    required String profileId,
  }) {
    if (!isMember(store, unitId, profileId)) return;
    store.setString(enrollmentKey(unitId), '');
    store.setMap(examConsentKey(unitId), {
      'profileId': profileId,
      'granted': false,
      'purpose': 'unit_health_file_exam',
      'scope': 'health_file_on_this_device',
    });
    if (unitId == 'women' &&
        store.stringField(BoxKeys.womenMembership) == 'enrolled') {
      store.setString(BoxKeys.womenMembership, '');
    }
  }

  void _notify({
    required ProfileBoxStore store,
    required String unitId,
    required String profileId,
    required String name,
    required String title,
    required String detail,
  }) {
    store.add(noticesKey(unitId), {
      'profileId': profileId,
      'name': name,
      'title': title,
      'detail': '$name: $detail',
    });
  }
}
