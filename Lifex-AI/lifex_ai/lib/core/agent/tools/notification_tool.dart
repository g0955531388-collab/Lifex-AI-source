/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: notification_tool.dart
/// المسار: lib/core/agent/tools/notification_tool.dart
/// الوصف: يصدر حدثاً عبر HealthEventManager الموجود فعلاً في
/// core/health_event_manager.dart بدل بناء آلية تنبيه موازية. أي وحدة
/// تستمع بالفعل لهذه الأحداث (health_alert_dispatcher.dart،
/// multi_sensory_alert_manager.dart) تستقبل التنبيه تلقائياً دون أي
/// اعتماد مباشر من هذه الأداة عليها.
///
/// ⚠️ نطاق: هذه الأداة تُصدر حدثاً داخلياً فقط (Event Bus). دفع إشعار
/// فعلي (Push Notification) عبر flutter_local_notifications/Firebase
/// يبقى مسؤولية المستمع النهائي على الحدث — لا تُنفَّذ هنا مباشرة،
/// لأن ذلك تكرار لما هو مخطط في health_alert_dispatcher.dart.
/// =============================================================
library;

import '../../../core/health_event_manager.dart';
import '../agent_context.dart';
import '../agent_permissions.dart';
import 'agent_tool.dart';

class NotificationTool implements AgentTool {
  NotificationTool({HealthEventManager? eventManager})
      : _eventManager = eventManager ?? HealthEventManager.instance;

  final HealthEventManager _eventManager;

  @override
  String get name => 'notification_dispatch';

  @override
  String get descriptionAr => 'إصدار تنبيه/إشعار داخلي عبر ناقل الأحداث المركزي.';

  @override
  Map<String, String> get inputSchema => const {
        'messageAr': 'String — نص التنبيه',
        'isEmergency': 'bool — هل هذا تنبيه طوارئ؟ (اختياري، افتراضي false)',
      };

  @override
  AgentToolPermissionSpec get permissionSpec => const AgentToolPermissionSpec(
        requiredPermissions: {AgentPermission.sendNotification},
        riskLevel: AgentActionRiskLevel.medium,
        // إرسال تنبيه لطرف قد يراه آخرون (مثال: جهة طوارئ) يستدعي
        // تأكيداً — إلا في حالة الطوارئ الحرجة الفعلية، التي يديرها
        // EmergencyAgent عبر مسار مختلف مصمم خصيصاً لذلك.
        requiresHumanConfirmation: true,
      );

  @override
  bool validate(Map<String, dynamic> arguments) {
    final message = arguments['messageAr'];
    return message is String && message.trim().isNotEmpty;
  }

  @override
  Future<AgentToolExecutionResult> execute({
    required Map<String, dynamic> arguments,
    required AgentContext context,
  }) async {
    final message = arguments['messageAr'] as String;
    final isEmergency = arguments['isEmergency'] as bool? ?? false;

    _eventManager.emitQuick(
      isEmergency
          ? HealthEventType.emergencyTriggered
          : HealthEventType.custom,
      sourceModule: 'agent_notification_tool',
      profileId: context.profileId,
      data: {'messageAr': message, 'taskId': context.taskId},
    );

    return const AgentToolExecutionResult.success({
      'dataType': 'notification_dispatched',
      'confidence': 'high',
    });
  }
}
