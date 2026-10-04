/// =============================================================
/// Lifex-AI — الطوارئ المتعددة الحواس
/// الملف: platform_notification_adapter.dart
/// الوصف: إشعار محلي على هذا الجهاز فقط عبر flutter_local_notifications ^15.
/// إظهار إشعار محلي ليس إرسالاً خارجياً: لا يصل أي شيء إلى جهة ثقة.
/// لذلك تعيد showEmergencyAlert نتيجة "عُرض محلياً" فقط، ولا تُستخدم
/// كدليل على outboundSent.
/// المنصة معزولة خلف [LocalNotificationPlatform] للاختبار بلا جهاز.
/// =============================================================

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// حد المنصة المحلي (التنفيذ الإنتاجي أدناه، والاختبارات تستخدم fake).
abstract class LocalNotificationPlatform {
  /// true فقط إذا نجحت التهيئة فعلاً.
  Future<bool> initialize({required String androidIcon});

  Future<void> createAndroidChannel({
    required String id,
    required String name,
    required String description,
  });

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
  });

  Future<void> cancelAll();
}

/// التنفيذ الإنتاجي فوق FlutterLocalNotificationsPlugin (^15.1.0).
class FlutterLocalNotificationsPlatform implements LocalNotificationPlatform {
  FlutterLocalNotificationsPlatform({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<bool> initialize({required String androidIcon}) async {
    final settings = InitializationSettings(
      android: AndroidInitializationSettings(androidIcon),
      iOS: const DarwinInitializationSettings(),
    );
    return (await _plugin.initialize(settings)) == true;
  }

  @override
  Future<void> createAndroidChannel({
    required String id,
    required String name,
    required String description,
  }) async {
    // في الإصدار 15: id و name معاملان موضعيان، وباقيهما مسماة.
    // لا sound مخصص: لا يوجد res/raw في مشروع Android.
    final channel = AndroidNotificationChannel(
      id,
      name,
      description: description,
      importance: Importance.max,
      enableVibration: true,
      enableLights: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
  }) {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        enableVibration: true,
        enableLights: true,
        playSound: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    return _plugin.show(id, title, body, details);
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}

/// محوّل الإشعارات المحلية لتنبيهات الطوارئ على هذا الجهاز.
class PlatformNotificationAdapter {
  PlatformNotificationAdapter({LocalNotificationPlatform? platform})
      : _platform = platform ?? FlutterLocalNotificationsPlatform();

  /// أيقونة التطبيق الموجودة فعلاً في android/app/src/main/res/mipmap-*/ic_launcher.png
  /// ومحددة في AndroidManifest (android:icon="@mipmap/ic_launcher").
  static const String androidIcon = '@mipmap/ic_launcher';
  static const String channelId = 'lifex_emergency';
  static const String channelName = 'Lifex Emergency Alerts';
  static const String channelDescription =
      'Critical health emergency notifications';

  final LocalNotificationPlatform _platform;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  /// يُستدعى مرة واحدة عند الإقلاع. تعيد true فقط إذا نجحت التهيئة فعلاً.
  Future<bool> initialize() async {
    if (_initialized) return true;
    try {
      _initialized = await _platform.initialize(androidIcon: androidIcon);
    } catch (_) {
      _initialized = false;
    }
    return _initialized;
  }

  Future<void> createEmergencyChannel() async {
    try {
      await _platform.createAndroidChannel(
        id: channelId,
        name: channelName,
        description: channelDescription,
      );
    } catch (_) {
      // فشل إنشاء القناة لا يوقف التطبيق.
    }
  }

  /// تعرض إشعاراً محلياً على هذا الجهاز. تعيد true إذا طلبت المنصة العرض
  /// بلا خطأ. هذا ليس تسليماً لجهة ثقة ولا يُستخدم لتحديد outboundSent.
  Future<bool> showEmergencyAlert({
    required String title,
    required String body,
  }) async {
    try {
      if (!_initialized && !await initialize()) return false;
      await _platform.show(
        id: 0,
        title: title,
        body: body,
        channelId: channelId,
        channelName: channelName,
        channelDescription: channelDescription,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> cancelAll() async {
    try {
      await _platform.cancelAll();
    } catch (_) {}
  }
}
