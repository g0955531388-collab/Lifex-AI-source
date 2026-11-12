import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lasting_search_index.dart';
import 'package:lifex_ai/core/local_knowledge.dart';
import 'package:lifex_ai/core/search_refresh_engine.dart';
import 'package:lifex_ai/data/medical_database_manager.dart';
import 'package:lifex_ai/features/location/gps_priority_monitor.dart';
import 'package:lifex_ai/features/messaging/conversation_type_router.dart';
import 'package:lifex_ai/features/messaging/health_channel_filter.dart';
import 'package:lifex_ai/features/messaging/health_thread_ledger.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

HealthProfile _p(String id, {String seat = 'individual'}) => HealthProfile(
      profileId: id,
      fullName: id,
      dateOfBirth: DateTime(1990, 1, 1),
      billingSeat: seat,
    );

void main() {
  const filter = HealthChannelFilter();

  test('العامة ترفض الإباحي والنابية والعيادة تقبل مرفقاً طبياً', () {
    expect(
      filter
          .inspect(
            type: ConversationType.direct,
            senderSeat: 'individual',
            text: 'pornhub',
            subscriber: true,
          )
          .allowed,
      isFalse,
    );
    expect(
      filter
          .inspect(
            type: ConversationType.direct,
            senderSeat: 'individual',
            text: 'كسمك',
            subscriber: false,
          )
          .allowed,
      isFalse,
    );
    expect(
      filter
          .inspect(
            type: ConversationType.medical,
            senderSeat: 'hospital',
            text: 'أشعة رحم',
            fileName: 'pelvic-ultrasound.dcm',
            sizeBytes: 2 * 1024 * 1024 * 1024,
            subscriber: true,
          )
          .allowed,
      isTrue,
    );
  });

  test('غير المشترك لا يرسل أكثر من 25 ميغا', () {
    final blocked = filter.inspect(
      type: ConversationType.direct,
      senderSeat: 'individual',
      text: 'قاعدة',
      fileName: 'db.json',
      sizeBytes: 40 * 1024 * 1024,
      subscriber: false,
    );
    expect(blocked.allowed, isFalse);
  });

  test('الخيط المحلي يحفظ بعد الفلتر', () {
    final a = _p('a');
    final b = _p('b');
    final result = HealthThreadLedger().send(
      from: a,
      to: b,
      type: ConversationType.direct,
      text: 'موعد الغد',
      subscriber: true,
    );
    expect(result.ok, isTrue);
    expect(
      HealthThreadLedger().posts(a, HealthThreadLedger.threadId('a', 'b')),
      isNotEmpty,
    );
    final blank = HealthThreadLedger().send(
      from: a,
      to: b,
      type: ConversationType.direct,
      text: '   ',
      subscriber: true,
    );
    expect(blank.ok, isFalse);
    expect(blank.messageAr, contains('اكتب رسالة'));
  });

  test('فهرس البحث الدائم لا ينتهي ويُدمج مع المرجع', () {
    final lasting = LastingSearchIndex();
    lasting.ingest([
      {'nameAr': 'داء اختباري دائم', 'description': 'للتوعية'},
    ]);
    expect(lasting.neverExpires, isTrue);
    final knowledge = LocalKnowledge(
      diseases: const [],
      medications: const [],
      symptoms: const [],
      tests: const [],
      namedConditions: const [],
      cameraSigns: const [],
      disclaimerAr: '',
    );
    final hits =
        InternalSearchEngine(knowledge: knowledge, lasting: lasting).search('اختباري');
    expect(hits, isNotEmpty);
  });

  test('تحديث البحث يجلب المحلي حتى لو فشل الخادم', () async {
    final lasting = LastingSearchIndex();
    final knowledge = LocalKnowledge(
      diseases: [
        {'nameAr': 'حصبة', 'nameEn': 'measles'},
      ],
      medications: const [],
      symptoms: const [],
      tests: const [],
      namedConditions: const [],
      cameraSigns: const [],
      disclaimerAr: '',
    );
    final db = MedicalDatabaseManager(
      remoteManifestUrl: 'https://example.invalid/manifest',
      httpClient: MockClient((_) async => http.Response('no', 404)),
    );
    final report = await const SearchRefreshEngine().refresh(
      knowledge: knowledge,
      lasting: lasting,
      database: db,
    );
    expect(report.localIngested, greaterThan(0));
    expect(report.remoteOk, isFalse);
    expect(lasting.search('حصبة'), isNotEmpty);
  });

  test('GPS أولوية عالية والنظام يعمل بلا تثبيت', () {
    const monitor = GpsPriorityMonitor();
    final off = monitor.fromPermission(granted: false);
    expect(off.lane, GpsLane.permissionMissing);
    expect(off.priority, GpsPriorityMonitor.bannerPriority);
    expect(GpsPriorityMonitor.inventedCoordinatesAllowed, isFalse);
    expect(GpsPriorityMonitor.userPlaceFieldsStartEmpty, isTrue);
    expect(monitor.fromPermission(granted: true).lane, GpsLane.permissionReady);
  });
}
