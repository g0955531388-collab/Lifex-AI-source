/// =============================================================
/// Lifex-AI — المراقبة الصحية عن بعد
/// الملف: health_alert_dispatcher.dart
/// المسار: lib/features/remote_health/health_alert_dispatcher.dart
/// الوصف: يستمع لأحداث النظام الحرجة (عبر health_event_manager.dart)
/// ويوزّع تنبيهات فعلية على جهات الثقة المناسبة حسب صلاحياتهم.
/// =============================================================
library;

import '../../core/health_event_manager.dart';
import 'trusted_contacts_manager.dart';

enum AlertChannel { push, sms, inAppMessage }

class DispatchedAlert {
  final String recipientLifexId;
  final AlertChannel channel;
  final String messageAr;
  final DateTime dispatchedAt;

  DispatchedAlert({
    required this.recipientLifexId,
    required this.channel,
    required this.messageAr,
    DateTime? dispatchedAt,
  }) : dispatchedAt = dispatchedAt ?? DateTime.now();
}

/// توقيع دالة الإرسال الفعلي عبر قناة معيّنة (Push/SMS/رسالة داخلية)،
/// سيُنفَّذ لاحقاً عبر خدمات فعلية (FCM، بوابة SMS...).
typedef AlertSendFunction = Future<bool> Function(DispatchedAlert alert);

/// موزّع تنبيهات الصحة — الجسر بين ناقل الأحداث المركزي وجهات الثقة.
class HealthAlertDispatcher {
  HealthAlertDispatcher({
    required this.trustedContactsProvider,
    required this.sendFunction,
  }) {
    HealthEventManager.instance.subscribe(
      HealthEventType.emergencyTriggered,
      _onEmergencyTriggered,
    );

    // الاستماع أيضاً للأخطاء الحرجة الصادرة من ErrorHandler (عبر النوع
    // العام custom مع علامة escalationReason)، حتى تصل الأخطاء الحرجة
    // المرتبطة بملف مستخدم معيّن لجهات الثقة تلقائياً، وليس فقط أحداث
    // الطوارئ الصريحة من emergency_manager.dart.
    HealthEventManager.instance.subscribe(
      HealthEventType.custom,
      _onCriticalSystemError,
    );
  }

  /// دالة تُرجع مدير جهات الثقة لملف صحي معيّن.
  final TrustedContactsManager Function(String profileId) trustedContactsProvider;
  final AlertSendFunction sendFunction;

  final List<DispatchedAlert> _dispatchLog = [];

  void _onCriticalSystemError(HealthEvent event) {
    if (event.profileId == null) return;
    if (event.data['escalationReason'] != 'critical_system_error') return;

    final manager = trustedContactsProvider(event.profileId!);
    final recipients = manager.emergencyNotificationList();

    final message = 'تنبيه: حدث خطأ حرج في النظام يتعلق بحسابك '
        '(${event.data['errorCode'] ?? 'غير محدَّد'}). يُرجى مراجعة '
        'التطبيق أو التواصل مع الدعم.';

    for (final contact in recipients) {
      final alert = DispatchedAlert(
        recipientLifexId: contact.contactLifexId,
        channel: AlertChannel.push,
        messageAr: message,
      );
      _dispatchLog.add(alert);
      sendFunction(alert);
    }
  }

  void _onEmergencyTriggered(HealthEvent event) {
    if (event.profileId == null) return;

    final manager = trustedContactsProvider(event.profileId!);
    final recipients = manager.emergencyNotificationList();

    const message = 'تنبيه: تم رصد مؤشر طوارئ صحي محتمل. '
        'يُرجى التواصل مع الشخص أو مراجعة التطبيق فوراً.';

    for (final contact in recipients) {
      final alert = DispatchedAlert(
        recipientLifexId: contact.contactLifexId,
        channel: AlertChannel.push,
        messageAr: message,
      );
      _dispatchLog.add(alert);
      sendFunction(alert);
    }
  }

  List<DispatchedAlert> get dispatchLog => List.unmodifiable(_dispatchLog);
}
