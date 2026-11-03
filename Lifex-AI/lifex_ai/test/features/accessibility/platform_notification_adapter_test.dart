// =============================================================
// Lifex-AI — اختبارات محوّل الإشعارات المحلية
// يستخدم FakePlatform عند حد المنصة فقط. لا جهاز ولا إرسال خارجي.
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/platform_notification_adapter.dart';
import 'package:lifex_ai/features/emergency/emergency_message_manager.dart';
import 'package:lifex_ai/features/emergency/emergency_phone_contacts_registry.dart';

class FakePlatform implements LocalNotificationPlatform {
  bool initResult = true;
  Object? initError;
  Object? channelError;
  Object? showError;

  final List<String> initIcons = [];
  final List<String> channelIds = [];
  final List<Map<String, Object>> shown = [];
  int cancelCalls = 0;

  @override
  Future<bool> initialize({required String androidIcon}) async {
    initIcons.add(androidIcon);
    if (initError != null) throw initError!;
    return initResult;
  }

  @override
  Future<void> createAndroidChannel({
    required String id,
    required String name,
    required String description,
  }) async {
    if (channelError != null) throw channelError!;
    channelIds.add(id);
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) async {
    if (showError != null) throw showError!;
    shown.add({'title': title, 'body': body, 'channelId': channelId});
  }

  @override
  Future<void> cancelAll() async {
    cancelCalls++;
  }
}

void main() {
  late FakePlatform platform;
  late PlatformNotificationAdapter adapter;

  setUp(() {
    platform = FakePlatform();
    adapter = PlatformNotificationAdapter(platform: platform);
  });

  group('initialize', () {
    test('uses the launcher icon that exists in the Android project', () async {
      expect(await adapter.initialize(), isTrue);
      expect(platform.initIcons, ['@mipmap/ic_launcher']);
      expect(adapter.isInitialized, isTrue);
    });

    test('is idempotent', () async {
      await adapter.initialize();
      await adapter.initialize();
      expect(platform.initIcons, hasLength(1));
    });

    test('platform reporting failure => false, no throw', () async {
      platform.initResult = false;
      expect(await adapter.initialize(), isFalse);
      expect(adapter.isInitialized, isFalse);
    });

    test('platform exception => false, no throw', () async {
      platform.initError = StateError('plugin missing');
      expect(await adapter.initialize(), isFalse);
      expect(adapter.isInitialized, isFalse);
    });
  });

  group('createEmergencyChannel', () {
    test('creates the emergency channel', () async {
      await adapter.createEmergencyChannel();
      expect(platform.channelIds, ['lifex_emergency']);
    });

    test('failure does not throw', () async {
      platform.channelError = StateError('no android impl');
      await adapter.createEmergencyChannel();
      expect(platform.channelIds, isEmpty);
    });
  });

  group('showEmergencyAlert', () {
    test('initializes lazily and shows on the emergency channel', () async {
      final shown = await adapter.showEmergencyAlert(
        title: 'تنبيه صحي',
        body: 'Health alert',
      );
      expect(shown, isTrue);
      expect(platform.initIcons, hasLength(1));
      expect(platform.shown.single, {
        'title': 'تنبيه صحي',
        'body': 'Health alert',
        'channelId': 'lifex_emergency',
      });
    });

    test('not initialized => nothing shown, returns false', () async {
      platform.initResult = false;
      expect(await adapter.showEmergencyAlert(title: 't', body: 'b'), isFalse);
      expect(platform.shown, isEmpty);
    });

    test('platform show failure => false, no throw', () async {
      platform.showError = StateError('denied');
      expect(await adapter.showEmergencyAlert(title: 't', body: 'b'), isFalse);
      expect(platform.shown, isEmpty);
    });
  });

  group('local notification is not outbound delivery', () {
    test(
        'local alert shown, yet with no external channel outboundSent stays '
        'false and the audit record is kept', () async {
      final registry = EmergencyPhoneContactsRegistry();
      final manager = EmergencyMessageManager(
        emergencyContactsRegistry: registry,
      ); // no sendFunction: no external channel is wired

      final shownLocally = await adapter.showEmergencyAlert(
        title: 't',
        body: 'b',
      );
      final outcome = await manager.dispatchEmergencyMessage(
        profileId: 'p1',
        caseId: 'EMG-1',
        riskLevel: 'critical',
        reasonAr: 'test',
      );

      expect(shownLocally, isTrue);
      expect(outcome.localCaseOpened, isTrue);
      expect(outcome.outboundSent, isFalse);
      expect(manager.log, hasLength(1));
      expect(manager.log.single.caseId, 'EMG-1');
    });
  });
}
