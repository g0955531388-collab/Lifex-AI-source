/// نداء تبرع على هذا الجهاز. المصدر واحد داخل صندوق الملف.
/// لا يوجد خادم يوزّع النداء إلى هواتف أخرى، ووصول الإشعار الخارجي غير مؤكد.
library lifex_ai.features.blood_network.blood_appeal_desk;

import '../../core/health_event_manager.dart';
import '../hospital/hospital_blood_bank.dart';
import '../messaging/chat_engine.dart';
import '../network_box/profile_box_store.dart';
import '../profile/health_profile.dart';
import 'blood_request_engine.dart';
import 'blood_type_match.dart';
import 'donor_eligibility_filter.dart';
import 'donor_history_registry.dart';
import 'flash_alert_notifier.dart';
import 'geo_expansion_dispatcher.dart';
import 'profile_donor_directory.dart';

class BloodAppealOutcome {
  const BloodAppealOutcome({
    this.errorAr,
    this.requestId,
    this.invited = 0,
    this.serverDeliveryConfirmed = false,
  });

  final String? errorAr;
  final String? requestId;
  final int invited;
  final bool serverDeliveryConfirmed;
}

class BloodAppealBanner {
  const BloodAppealBanner({
    required this.requestId,
    required this.unitName,
    required this.bloodLabel,
    required this.whereAr,
    required this.expiresAt,
  });

  final String requestId;
  final String unitName;
  final String bloodLabel;
  final String whereAr;
  final String expiresAt;
}

class BloodAppealDesk {
  const BloodAppealDesk();

  static const appealsKey = 'bloodAppeals';
  static const auditKey = 'bloodAppealAudit';
  static const privateEvalKey = 'bloodAppealPrivateEvals';
  static const responsesKey = 'bloodAppealResponses';
  static const groupsKey = 'bloodAppealGroups';
  static const publishersKey = 'bloodAppealPublishers';
  static const idempotencyKey = 'bloodAppealIdempotency';
  static const publicFeedKey = 'bloodPublicFeed';
  static const invitesKey = 'bloodInvites';
  static const dismissedKey = 'bloodDismissed';
  static const inboxKey = 'bloodSystemInbox';
  static const publicConversationId = 'blood-appeals-public';

  static const initialRadiusKm = 10.0;
  static const maxRadiusKm = 40.0;
  static const expansionStepKm = 10.0;

  static bool mayPublish(ProfileBoxStore store, String profileId) {
    return store.map(publishersKey)[profileId] == true;
  }

  static void grantPublisher(ProfileBoxStore store, String profileId) {
    final grants = store.map(publishersKey);
    grants[profileId] = true;
    store.setMap(publishersKey, grants);
  }

  BloodAppealOutcome publish({
    required ProfileBoxStore unitStore,
    required HealthProfile publisher,
    required List<HealthProfile> candidates,
    required String clientKey,
    required String unitId,
    required String unitName,
    required String address,
    required double latitude,
    required double longitude,
    required BloodTypeSimple bloodType,
    required BloodRequestUrgency urgency,
    required String contact,
    required DateTime expiresAt,
    String city = '',
    String reason = '',
    int? unitsNeeded,
    bool allowExpansion = false,
    DonorHistoryRegistry? history,
    FlashAlertNotifier? alerts,
    ChatEngine? chat,
    GeoExpansionDispatcher? expansion,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final key = clientKey.trim();
    if (key.isEmpty) {
      return const BloodAppealOutcome(errorAr: 'معرّف الطلب فارغ.');
    }
    final seen = unitStore.map(idempotencyKey);
    final previous = seen[key]?.toString();
    if (previous != null && previous.isNotEmpty) {
      return BloodAppealOutcome(requestId: previous, invited: 0);
    }
    if (!mayPublish(unitStore, publisher.profileId)) {
      return const BloodAppealOutcome(
        errorAr: 'النشر الرسمي يحتاج تفويض الوحدة. الحساب الحالي غير مفوّض.',
      );
    }
    if (unitName.trim().isEmpty || address.trim().isEmpty) {
      return const BloodAppealOutcome(
        errorAr: 'اسم الوحدة والعنوان مطلوبان.',
      );
    }
    if (contact.trim().isEmpty) {
      return const BloodAppealOutcome(
        errorAr: 'وسيلة التواصل مع الوحدة مطلوبة.',
      );
    }
    if (!DonorEligibilityFilter.coordinatesUsable(latitude, longitude)) {
      return const BloodAppealOutcome(
        errorAr: 'إحداثيات الوحدة غير صالحة.',
      );
    }
    if (!expiresAt.isAfter(clock)) {
      return const BloodAppealOutcome(errorAr: 'موعد انتهاء الطلب غير صالح.');
    }
    if (unitsNeeded != null && unitsNeeded < 1) {
      return const BloodAppealOutcome(
        errorAr: 'عدد الوحدات، إن ذُكر، يكون واحداً على الأقل.',
      );
    }

    final requestId = 'BRQ-${clock.microsecondsSinceEpoch}-${key.hashCode.abs()}';
    final appeal = <String, dynamic>{
      'id': requestId,
      'clientKey': key,
      'healthUnitId': unitId,
      'healthUnitName': unitName.trim(),
      'address': address.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'city': city.trim(),
      'requiredBloodGroup': bloodType.name,
      'unitsNeeded': unitsNeeded,
      'confirmedByUnit': 0,
      'urgency': urgency.name,
      'reason': reason.trim(),
      'contact': contact.trim(),
      'status': 'active',
      'createdAt': clock.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'createdBy': publisher.profileId,
      'approvedAt': clock.toIso8601String(),
      'radiusKm': initialRadiusKm,
      'allowExpansion': allowExpansion,
      'serverDeliveryConfirmed': false,
    };
    unitStore.add(appealsKey, appeal);
    seen[key] = requestId;
    unitStore.setMap(idempotencyKey, seen);

    final invited = _dispatch(
      unitStore: unitStore,
      appeal: _find(unitStore, requestId) ?? appeal,
      candidates: candidates,
      history: history ?? DonorHistoryRegistry(),
      alerts: alerts,
      chat: chat,
      now: clock,
    );
    unitStore.add(auditKey, {
      'requestId': requestId,
      'action': 'published',
      'invited': invited,
      'at': clock.toIso8601String(),
    });
    HealthEventManager.instance.emitQuick(
      HealthEventType.bloodRequestCreated,
      sourceModule: 'blood_appeal_desk',
      profileId: publisher.profileId,
      data: {
        'requestId': requestId,
        'unitId': unitId,
        'bloodType': bloodType.name,
      },
    );
    if (allowExpansion) {
      expansion?.scheduleExpansion(requestId, initialRadiusKm);
    }
    return BloodAppealOutcome(requestId: requestId, invited: invited);
  }

  int expand({
    required ProfileBoxStore unitStore,
    required String requestId,
    required List<HealthProfile> candidates,
    DonorHistoryRegistry? history,
    FlashAlertNotifier? alerts,
    ChatEngine? chat,
    DateTime? now,
  }) {
    final appeal = _find(unitStore, requestId);
    if (appeal == null || appeal['status'] != 'active') return 0;
    if (appeal['allowExpansion'] != true) return 0;
    final current = (appeal['radiusKm'] as num?)?.toDouble() ?? initialRadiusKm;
    final next = current + expansionStepKm;
    if (next > maxRadiusKm) return 0;
    appeal['radiusKm'] = next;
    _replace(unitStore, appeal);
    final added = _dispatch(
      unitStore: unitStore,
      appeal: appeal,
      candidates: candidates,
      history: history ?? DonorHistoryRegistry(),
      alerts: alerts,
      chat: chat,
      now: now ?? DateTime.now(),
    );
    unitStore.add(auditKey, {
      'requestId': requestId,
      'action': 'expanded',
      'radiusKm': next,
      'invited': added,
    });
    return added;
  }

  String? close({
    required ProfileBoxStore unitStore,
    required String actorProfileId,
    required String requestId,
    required String status,
    DateTime? now,
  }) {
    if (!mayPublish(unitStore, actorProfileId)) {
      return 'إغلاق الطلب للمفوّض فقط.';
    }
    if (status != 'completed' && status != 'cancelled') {
      return 'حالة الإغلاق غير مقبولة.';
    }
    final appeal = _find(unitStore, requestId);
    if (appeal == null) return 'الطلب غير موجود.';
    appeal['status'] = status;
    appeal['closedAt'] = (now ?? DateTime.now()).toIso8601String();
    _replace(unitStore, appeal);
    unitStore.add(auditKey, {
      'requestId': requestId,
      'action': status,
    });
    return null;
  }

  String? respond({
    required ProfileBoxStore unitStore,
    required HealthProfile donor,
    required String requestId,
    required String responseStatus,
    DateTime? now,
  }) {
    if (responseStatus != 'willing' && responseStatus != 'unavailable') {
      return 'الاستجابة غير مقبولة.';
    }
    final appeal = _open(unitStore, requestId, now ?? DateTime.now());
    if (appeal == null) return 'الطلب ليس نشطاً.';
    final rows = unitStore.list(responsesKey);
    final index = rows.indexWhere(
      (row) =>
          row['requestId'] == requestId && row['profileId'] == donor.profileId,
    );
    final record = {
      'requestId': requestId,
      'profileId': donor.profileId,
      'responseStatus': responseStatus,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (index >= 0) {
      rows[index] = {...rows[index], ...record};
      unitStore.setList(responsesKey, rows);
    } else {
      unitStore.add(responsesKey, record);
    }
    return null;
  }

  String? confirmArrival({
    required ProfileBoxStore unitStore,
    required String actorProfileId,
    required String requestId,
    DateTime? now,
  }) {
    if (!mayPublish(unitStore, actorProfileId)) {
      return 'تأكيد الوصول للمفوّض فقط.';
    }
    final appeal = _open(unitStore, requestId, now ?? DateTime.now());
    if (appeal == null) return 'الطلب ليس نشطاً.';
    final confirmed = ((appeal['confirmedByUnit'] as num?)?.toInt() ?? 0) + 1;
    appeal['confirmedByUnit'] = confirmed;
    final needed = (appeal['unitsNeeded'] as num?)?.toInt();
    if (needed != null && confirmed >= needed) {
      appeal['status'] = 'completed';
    }
    _replace(unitStore, appeal);
    return null;
  }

  Map<String, dynamic> unitSummary(
      ProfileBoxStore unitStore, String requestId) {
    final appeal = _find(unitStore, requestId);
    final responses = unitStore
        .list(responsesKey)
        .where((row) => row['requestId'] == requestId);
    return {
      'requestId': requestId,
      'status': appeal?['status'],
      'willing':
          responses.where((row) => row['responseStatus'] == 'willing').length,
      'unavailable': responses
          .where((row) => row['responseStatus'] == 'unavailable')
          .length,
    };
  }

  void registerGroup({
    required ProfileBoxStore unitStore,
    required String groupId,
    required bool acceptsAppeals,
  }) {
    final groups = unitStore.list(groupsKey);
    groups.removeWhere((row) => row['groupId'] == groupId);
    groups.add({'groupId': groupId, 'acceptsAppeals': acceptsAppeals});
    unitStore.setList(groupsKey, groups);
  }

  static ProfileBoxStore? storeFor(
    List<HealthProfile> profiles,
    String requestId,
  ) {
    for (final profile in profiles) {
      final store = ProfileBoxStore(profile);
      if (store.list(appealsKey).any((row) => row['id'] == requestId)) {
        return store;
      }
    }
    return null;
  }

  void dismiss(HealthProfile donor, String requestId) {
    final store = ProfileBoxStore(donor);
    final ids = store.list(dismissedKey);
    if (ids.any((row) => row['requestId'] == requestId)) return;
    store.add(dismissedKey, {'requestId': requestId});
  }

  BloodAppealBanner? bannerFor({
    required HealthProfile donor,
    required ProfileBoxStore unitStore,
    DateTime? now,
  }) {
    if (!donor.acceptsBloodDonationAlerts) return null;
    final channels = _channels(donor);
    if (!channels.contains('system') && !channels.contains('push')) {
      return null;
    }
    final clock = now ?? DateTime.now();
    final dismissed = ProfileBoxStore(donor)
        .list(dismissedKey)
        .map((row) => row['requestId'])
        .toSet();
    for (final invite in ProfileBoxStore(donor).list(invitesKey).reversed) {
      final requestId = invite['requestId']?.toString() ?? '';
      if (requestId.isEmpty || dismissed.contains(requestId)) continue;
      final appeal = _open(unitStore, requestId, clock);
      if (appeal == null) continue;
      return BloodAppealBanner(
        requestId: requestId,
        unitName: appeal['healthUnitName']?.toString() ?? '',
        bloodLabel: BloodTypeMatch.label(
          BloodTypeSimple.values.byName(
            appeal['requiredBloodGroup']?.toString() ?? 'oPositive',
          ),
        ),
        whereAr: invite['whereAr']?.toString() ?? '',
        expiresAt: appeal['expiresAt']?.toString() ?? '',
      );
    }
    return null;
  }

  int _dispatch({
    required ProfileBoxStore unitStore,
    required Map<String, dynamic> appeal,
    required List<HealthProfile> candidates,
    required DonorHistoryRegistry history,
    required FlashAlertNotifier? alerts,
    required ChatEngine? chat,
    required DateTime now,
  }) {
    if (_open(unitStore, appeal['id'].toString(), now) == null) return 0;
    final blood = BloodTypeSimple.values.byName(
      appeal['requiredBloodGroup'].toString(),
    );
    final radius = (appeal['radiusKm'] as num?)?.toDouble() ?? initialRadiusKm;
    final filter = DonorEligibilityFilter(
      historyRegistry: history,
      donorDirectory: () => ProfileDonorDirectory.fromProfiles(candidates),
    );
    final matched = filter.findEligibleDonors(
      bloodType: blood,
      centerLatitude: (appeal['latitude'] as num).toDouble(),
      centerLongitude: (appeal['longitude'] as num).toDouble(),
      radiusKm: radius,
      compatibleRedCells: true,
      targetCity: appeal['city']?.toString() ?? '',
    );
    final byId = {for (final profile in candidates) profile.profileId: profile};
    var invited = 0;
    var groupAudience = false;
    for (final donor in matched) {
      final profile = byId[donor.profileId];
      if (profile == null) continue;
      if (_alreadyInvited(profile, appeal['id'].toString())) continue;
      final review = profile.chronicConditions.isNotEmpty;
      ProfileBoxStore(profile).add('bloodOwnEval', {
        'requestId': appeal['id'],
        'result': 'preliminaryInvite',
        'medicallyCleared': false,
        'needsClinicalReview': review,
        'ruleVersion': 'red-cells-v1',
        'updatedAt': now.toIso8601String(),
      });
      final where =
          donor.city.trim().isEmpty ? 'ضمن النطاق' : donor.city.trim();
      ProfileBoxStore(profile).add(invitesKey, {
        'requestId': appeal['id'],
        'whereAr': where,
      });
      final channels = _channels(profile);
      final text = _appealText(appeal);
      if (channels.contains('system')) {
        ProfileBoxStore(profile).add(inboxKey, {
          'requestId': appeal['id'],
          'text': text,
        });
      }
      if (channels.contains('push') && alerts != null) {
        alerts.sendAlert(
          donor.donorLifexId,
          BloodRequest(
            requestId: appeal['id'].toString(),
            bloodType: blood,
            unitsNeeded: (appeal['unitsNeeded'] as num?)?.toInt() ?? 0,
            urgency: BloodRequestUrgency.values.byName(
              appeal['urgency']?.toString() ?? 'urgent',
            ),
            requestLatitude: (appeal['latitude'] as num).toDouble(),
            requestLongitude: (appeal['longitude'] as num).toDouble(),
            healthUnitName: appeal['healthUnitName']?.toString() ?? '',
            address: appeal['address']?.toString() ?? '',
            contact: appeal['contact']?.toString() ?? '',
          ),
        );
      }
      if (channels.contains('groups')) groupAudience = true;
      invited++;
    }
    if (invited > 0 &&
        matched.any((donor) {
          final profile = byId[donor.profileId];
          return profile != null && _channels(profile).contains('public');
        })) {
      final text = _appealText(appeal);
      unitStore.add(publicFeedKey, {'requestId': appeal['id'], 'text': text});
      chat?.sendMessage(
        conversationId: publicConversationId,
        senderLifexId: 'blood-unit',
        content: text,
        contentType: MessageContentType.systemNotice,
      );
    }
    if (groupAudience) {
      final text = _appealText(appeal);
      for (final group in unitStore.list(groupsKey)) {
        if (group['acceptsAppeals'] != true) continue;
        final groupId = group['groupId']?.toString() ?? '';
        if (groupId.isEmpty) continue;
        chat?.sendMessage(
          conversationId: 'blood-group-$groupId',
          senderLifexId: 'blood-unit',
          content: text,
          contentType: MessageContentType.systemNotice,
        );
      }
    }
    return invited;
  }

  bool _alreadyInvited(HealthProfile profile, String requestId) {
    return ProfileBoxStore(profile)
        .list(invitesKey)
        .any((row) => row['requestId'] == requestId);
  }

  Set<String> _channels(HealthProfile profile) {
    final raw = profile.questionnaireData['bloodChannels'];
    if (raw is! List) return const {};
    return raw.map((item) => item.toString()).toSet();
  }

  String _appealText(Map<String, dynamic> appeal) {
    final blood = BloodTypeMatch.label(
      BloodTypeSimple.values.byName(appeal['requiredBloodGroup'].toString()),
    );
    return 'نداء للتبرع بالدم: ${appeal['healthUnitName']}، '
        'العنوان: ${appeal['address']}. الزمرة المطلوبة: $blood. '
        'التواصل: ${appeal['contact']}. '
        'دعوة أولية وبنك الدم يقرر الأهلية.';
  }

  Map<String, dynamic>? _open(
    ProfileBoxStore store,
    String requestId,
    DateTime now,
  ) {
    final appeal = _find(store, requestId);
    if (appeal == null || appeal['status'] != 'active') return null;
    final expiry = DateTime.tryParse(appeal['expiresAt']?.toString() ?? '');
    if (expiry != null && !expiry.isAfter(now)) {
      appeal['status'] = 'expired';
      _replace(store, appeal);
      return null;
    }
    return appeal;
  }

  Map<String, dynamic>? _find(ProfileBoxStore store, String requestId) {
    for (final row in store.list(appealsKey)) {
      if (row['id'] == requestId) return row;
    }
    return null;
  }

  void _replace(ProfileBoxStore store, Map<String, dynamic> appeal) {
    final rows = store.list(appealsKey);
    final index = rows.indexWhere((row) => row['id'] == appeal['id']);
    if (index < 0) return;
    rows[index] = appeal;
    store.setList(appealsKey, rows);
  }
}
