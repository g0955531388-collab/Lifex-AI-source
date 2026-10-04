/// =============================================================
/// Lifex-AI — الطوارئ المتعددة الحواس
/// الملف: platform_notification_adapter.dart
/// المسار: lib/features/accessibility/platform_notification_adapter.dart
/// الوصف: تنفيذ حقيقي لإرسال تنبيهات الطوارئ عبر
/// flutter_local_notifications مع معالجة آمنة للأخطاء.
/// =============================================================

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// تنفيذ حقيقي لإرسال تنبيهات نظام التشغيل.
class PlatformNotificationAdapter {
  PlatformNotificationAdapter({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// تهيئة الإضافة (يجب استدعاؤه مرة واحدة فقط عند الإقلاع).
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      const androidSettings = AndroidInitializationSettings(
        'mipmap/ic_launcher', // استخدام الأيقونة الافتراضية
      );
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _plugin.initialize(initSettings);
      _initialized = true;
    } catch (_) {
      // فشل التهيئة — التطبيق يستمر بدون تنبيهات محلية
      _initialized = false;
    }
  }

  /// إنشاء قناة تنبيه الطوارئ (Android only).
  Future<void> createEmergencyChannel() async {
    try {
      const channel = AndroidNotificationChannel(
        id: 'lifex_emergency',
        name: 'Lifex Emergency Alerts',
        description: 'Critical health emergency notifications',
        importance: Importance.max,
        enableVibration: true,
        enableLights: true,
        sound: RawResourceAndroidNotificationSound('alarm'),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    } catch (_) {
      // Channel creation failed — continue without custom sound
    }
  }

  /// إرسال تنبيه طوارئ.
  Future<void> showEmergencyAlert({
    required String title,
    required String body,
  }) async {
    try {
      if (!_initialized) {
        await initialize();
      }

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'lifex_emergency',
          'Lifex Emergency Alerts',
          channelDescription: 'Critical health emergency notifications',
          importance: Importance.max,
          priority: Priority.max,
          enableVibration: true,
          enableLights: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _plugin.show(
        0, // notification ID
        title,
        body,
        details,
      );
    } catch (_) {
      // Notification failed — emergency continues without platform notification
    }
  }

  /// إلغاء جميع التنبيهات.
  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {
      // Cancel failed — continue
    }
  }
}
