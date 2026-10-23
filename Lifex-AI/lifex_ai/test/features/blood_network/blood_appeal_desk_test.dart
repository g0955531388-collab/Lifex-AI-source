import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/blood_network/blood_appeal_banner_view.dart';
import 'package:lifex_ai/features/blood_network/blood_appeal_desk.dart';
import 'package:lifex_ai/features/blood_network/blood_request_engine.dart';
import 'package:lifex_ai/features/blood_network/donor_history_registry.dart';
import 'package:lifex_ai/features/hospital/hospital_blood_bank.dart';
import 'package:lifex_ai/features/messaging/chat_engine.dart';
import 'package:lifex_ai/features/network_box/profile_box_store.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';

void main() {
  HealthProfile person({
    required String id,
    required String name,
    BloodType blood = BloodType.oNegative,
    bool alerts = true,
    String city = 'دمشق',
    double? lat = 33.51,
    double? lon = 36.29,
    List<String> channels = const ['system', 'push', 'public', 'groups'],
    List<ChronicConditionRecord> chronic = const [],
  }) {
    return HealthProfile(
      profileId: id,
      fullName: name,
      statedAgeYears: 30,
      bloodType: blood,
      acceptsBloodDonationAlerts: alerts,
      chronicConditions: chronic,
      questionnaireData: {
        'bloodCity': city,
        'bloodLatitude': lat,
        'bloodLongitude': lon,
        'bloodChannels': channels,
      },
    );
  }

  BloodAppealOutcome send(
    ProfileBoxStore store,
    HealthProfile publisher,
    List<HealthProfile> people, {
    String key = 'once',
    BloodTypeSimple type = BloodTypeSimple.aPositive,
    String city = 'دمشق',
    DonorHistoryRegistry? history,
    ChatEngine? chat,
    DateTime? now,
    DateTime? expires,
    int? units = 2,
  }) {
    return const BloodAppealDesk().publish(
      unitStore: store,
      publisher: publisher,
      candidates: people,
      clientKey: key,
      unitId: 'blood',
      unitName: 'مستشفى الجامعة',
      address: 'المزة',
      latitude: 33.5138,
      longitude: 36.2765,
      bloodType: type,
      urgency: BloodRequestUrgency.urgent,
      contact: '011-000',
      expiresAt: expires ?? DateTime(2026, 10, 14, 18),
      city: city,
      reason: 'حاجة سريرية',
      unitsNeeded: units,
      history: history,
      chat: chat,
      now: now ?? DateTime(2026, 10, 14, 9),
    );
  }

  test('النداء المفوّض يصل للمتوافق داخل المدينة فقط', () {
    final publisher = person(id: 'unit', name: 'الوحدة', alerts: false);
    final store = ProfileBoxStore(publisher);
    BloodAppealDesk.grantPublisher(store, publisher.profileId);
    final near = person(id: 'near', name: 'قريب');
    final wrong = person(
      id: 'wrong',
      name: 'آخر',
      blood: BloodType.bPositive,
    );
    final far = person(
      id: 'far',
      name: 'بعيد',
      city: 'حلب',
      lat: 36.2,
      lon: 37.13,
    );
    final quiet = person(id: 'quiet', name: 'صامت', alerts: false);
    final sameCityCloseOtherName = person(
      id: 'homs',
      name: 'مدينة أخرى',
      city: 'حمص',
      lat: 33.52,
      lon: 36.28,
    );
    final outcome = send(store, publisher, [
      publisher,
      near,
      wrong,
      far,
      quiet,
      sameCityCloseOtherName,
    ]);

    expect(outcome.errorAr, isNull);
    expect(outcome.invited, 1);
    expect(outcome.serverDeliveryConfirmed, isFalse);
    expect(ProfileBoxStore(near).list(BloodAppealDesk.inboxKey), hasLength(1));
    expect(ProfileBoxStore(wrong).list(BloodAppealDesk.inboxKey), isEmpty);
    expect(ProfileBoxStore(far).list(BloodAppealDesk.inboxKey), isEmpty);
    expect(ProfileBoxStore(quiet).list(BloodAppealDesk.inboxKey), isEmpty);
    expect(
      ProfileBoxStore(sameCityCloseOtherName).list(BloodAppealDesk.inboxKey),
      isEmpty,
    );
    expect(
      store.list(BloodAppealDesk.appealsKey).single['serverDeliveryConfirmed'],
      isFalse,
    );
  });

  test('جهة غير مفوّضة لا تنشر نداءً', () {
    final publisher = person(id: 'visitor', name: 'زائر', alerts: false);
    final store = ProfileBoxStore(publisher);
    final outcome = send(store, publisher, [publisher]);
    expect(outcome.errorAr, contains('تفويض'));
    expect(store.list(BloodAppealDesk.appealsKey), isEmpty);
  });

  test('المرض المزمن لا يمنع الدعوة ولا يظهر في الرسالة', () {
    final publisher = person(id: 'unit', name: 'الوحدة', alerts: false);
    final store = ProfileBoxStore(publisher);
    BloodAppealDesk.grantPublisher(store, publisher.profileId);
    final donor = person(
      id: 'sugar',
      name: 'ليان',
      chronic: [
        ChronicConditionRecord(
          conditionName: 'السكري',
          diagnosedAt: DateTime(2020, 1, 1),
        ),
      ],
    );
    send(store, publisher, [publisher, donor]);
    final inbox = ProfileBoxStore(donor).list(BloodAppealDesk.inboxKey).single;
    expect(inbox['text'].toString(), isNot(contains('السكري')));
    expect(inbox['text'].toString(), contains('بنك الدم'));
    final eval = ProfileBoxStore(donor).list('bloodOwnEval').single;
    expect(eval['medicallyCleared'], isFalse);
    expect(eval['needsClinicalReview'], isTrue);
  });

  test('الملف بلا زمرة أو بلا موقع لا يُدعى، والتبرع القريب يُستبعد بلا سبب',
      () {
    final publisher = person(id: 'unit', name: 'الوحدة', alerts: false);
    final store = ProfileBoxStore(publisher);
    BloodAppealDesk.grantPublisher(store, publisher.profileId);
    final unknown = person(id: 'unk', name: 'مجهول', blood: BloodType.unknown);
    final noPlace =
        person(id: 'noplace', name: 'بلا موقع', city: '', lat: null, lon: null);
    final recent = person(id: 'recent', name: 'حديث');
    final history = DonorHistoryRegistry()
      ..recordDonation(BloodDonationRecord(
        donorLifexId: 'recent',
        donatedAt: DateTime(2026, 10, 1),
      ));
    send(
      store,
      publisher,
      [publisher, unknown, noPlace, recent],
      history: history,
      now: DateTime(2026, 10, 14, 9),
    );
    expect(ProfileBoxStore(unknown).list(BloodAppealDesk.inboxKey), isEmpty);
    expect(ProfileBoxStore(noPlace).list(BloodAppealDesk.inboxKey), isEmpty);
    expect(ProfileBoxStore(recent).list(BloodAppealDesk.inboxKey), isEmpty);
    final public = store.list(BloodAppealDesk.publicFeedKey);
    expect(public.every((row) => !row.toString().contains('السكري')), isTrue);
  });

  test('الإغلاق وانتهاء الصلاحية والتكرار يوقفون التوزيع', () {
    final publisher = person(id: 'unit', name: 'الوحدة', alerts: false);
    final store = ProfileBoxStore(publisher);
    BloodAppealDesk.grantPublisher(store, publisher.profileId);
    final donor = person(id: 'near', name: 'قريب');
    final chat = ChatEngine();
    const BloodAppealDesk().registerGroup(
      unitStore: store,
      groupId: 'city',
      acceptsAppeals: true,
    );
    const BloodAppealDesk().registerGroup(
      unitStore: store,
      groupId: 'private',
      acceptsAppeals: false,
    );
    final first = send(
      store,
      publisher,
      [publisher, donor],
      chat: chat,
      key: 'same',
    );
    final again = send(
      store,
      publisher,
      [publisher, donor],
      chat: chat,
      key: 'same',
    );
    expect(again.requestId, first.requestId);
    expect(again.invited, 0);
    expect(
        chat.messagesFor(BloodAppealDesk.publicConversationId), hasLength(1));
    expect(
      chat.messagesFor(BloodAppealDesk.publicConversationId).single.delivered,
      isFalse,
    );
    expect(chat.messagesFor('blood-group-city'), hasLength(1));
    expect(chat.messagesFor('blood-group-private'), isEmpty);
    expect(
      chat.messagesFor('blood-group-city').single.content,
      isNot(contains('قريب')),
    );

    expect(
      const BloodAppealDesk().close(
        unitStore: store,
        actorProfileId: donor.profileId,
        requestId: first.requestId!,
        status: 'completed',
      ),
      contains('إغلاق الطلب'),
    );
    expect(
      const BloodAppealDesk().close(
        unitStore: store,
        actorProfileId: publisher.profileId,
        requestId: first.requestId!,
        status: 'completed',
      ),
      isNull,
    );
    expect(
      const BloodAppealDesk().expand(
        unitStore: store,
        requestId: first.requestId!,
        candidates: [donor],
      ),
      0,
    );

    send(
      store,
      publisher,
      [publisher, donor],
      key: 'expired',
      now: DateTime(2026, 10, 14, 9),
      expires: DateTime(2026, 10, 14, 12),
    );
    expect(
      const BloodAppealDesk().bannerFor(
        donor: donor,
        unitStore: store,
        now: DateTime(2026, 10, 14, 13),
      ),
      isNull,
    );
    expect(
      store.list(BloodAppealDesk.appealsKey).last['status'],
      'expired',
    );
  });

  test('الاستجابة ليست أهلية، والملخص لا يكشف الأسماء', () {
    final publisher = person(id: 'unit', name: 'الوحدة', alerts: false);
    final store = ProfileBoxStore(publisher);
    BloodAppealDesk.grantPublisher(store, publisher.profileId);
    final donor = person(id: 'near', name: 'قريب');
    final clock = DateTime(2026, 10, 14, 10);
    final outcome = send(store, publisher, [publisher, donor], units: 1);
    expect(
      const BloodAppealDesk().respond(
        unitStore: store,
        donor: donor,
        requestId: outcome.requestId!,
        responseStatus: 'willing',
        now: clock,
      ),
      isNull,
    );
    final summary =
        const BloodAppealDesk().unitSummary(store, outcome.requestId!);
    expect(summary['willing'], 1);
    expect(summary.containsKey('profileId'), isFalse);
    expect(summary.toString(), isNot(contains('قريب')));
    expect(
      store.list(BloodAppealDesk.appealsKey).single['status'],
      'active',
    );
    expect(
      const BloodAppealDesk().confirmArrival(
        unitStore: store,
        actorProfileId: publisher.profileId,
        requestId: outcome.requestId!,
        now: clock,
      ),
      isNull,
    );
    expect(
      store.list(BloodAppealDesk.appealsKey).last['status'],
      'completed',
    );
  });

  testWidgets('الشريط يُغلق ولا يعود ويُقرأ باسم الوحدة والزمرة',
      (tester) async {
    final publisher = person(id: 'unit', name: 'الوحدة', alerts: false);
    final store = ProfileBoxStore(publisher);
    BloodAppealDesk.grantPublisher(store, publisher.profileId);
    final donor = person(id: 'near', name: 'قريب');
    send(store, publisher, [publisher, donor]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BloodAppealBannerView(
          donor: donor,
          profiles: [publisher, donor],
          onOpen: () {},
          now: DateTime(2026, 10, 14, 10),
        ),
      ),
    ));
    expect(find.text('مستشفى الجامعة'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('نداء تبرع بالدم')), findsOneWidget);
    await tester.tap(find.text('إغلاق التنبيه'));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BloodAppealBannerView(
          donor: donor,
          profiles: [publisher, donor],
          onOpen: () {},
          now: DateTime(2026, 10, 14, 10),
        ),
      ),
    ));
    expect(find.text('مستشفى الجامعة'), findsNothing);
  });
}
