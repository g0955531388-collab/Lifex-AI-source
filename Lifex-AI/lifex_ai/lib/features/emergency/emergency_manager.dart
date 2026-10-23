/// =============================================================
/// Lifex-AI — الطوارئ
/// الملف: emergency_manager.dart
/// المسار: lib/features/emergency/emergency_manager.dart
/// الوصف: المدير المركزي لحالة الطوارئ الكاملة — من إطلاقها حتى حلها،
/// وينسّق بين تقييم الخطر وإرسال الاستغاثة.
/// =============================================================
library;

import '../../core/health_event_manager.dart';
import '../accessibility/multi_sensory_alert_manager.dart';
import 'emergency_message_manager.dart';
import 'risk_level_engine.dart';
import 'silent_emergency_signal_controller.dart';

enum EmergencyStatus { none, active, resolved }

class EmergencyCase {
  final String caseId;
  final String profileId;
  final DateTime triggeredAt;
  EmergencyStatus status;
  final String triggerReasonAr;
  DateTime? resolvedAt;

  EmergencyCase({
    required this.caseId,
    required this.profileId,
    required this.triggerReasonAr,
    this.status = EmergencyStatus.active,
    DateTime? triggeredAt,
    this.resolvedAt,
  }) : triggeredAt = triggeredAt ?? DateTime.now();
}

/// المدير المركزي لحالات الطوارئ.
class EmergencyManager {
  EmergencyManager({
    required this.riskLevelEngine,
    required this.messageManager,
    this.multiSensoryAlertManager,
    this.silentSignalController,
  });

  final RiskLevelEngine riskLevelEngine;
  final EmergencyMessageManager messageManager;

  /// اختياري عمداً (nullable) حتى لا يفشل النظام كاملاً لو لم يُهيَّأ.
  /// يُستخدم فقط كخيار احتياطي مباشر إن لم يُوفَّر
  /// [silentSignalController] (مثلاً في اختبارات مبسّطة)؛ عند توفر
  /// silentSignalController يُفضَّل عليه دائماً لأنه يحترم الوضع الصامت.
  final MultiSensoryAlertManager? multiSensoryAlertManager;

  /// الطبقة المعتمدة فعلياً لتقرير: تنبيه حسي طبيعي (صوت+اهتزاز+ومضة)،
  /// أم وضع صامت (ومضة فقط) — انظر silent_emergency_signal_controller.dart
  /// للتفاصيل الكاملة وسبب وجود هذا الفرق تحديداً في حالات الطوارئ.
  final SilentEmergencySignalController? silentSignalController;

  final Map<String, EmergencyCase> _activeCases = {};
  int _caseCounter = 0;

  /// إطلاق حالة طوارئ جديدة — نقطة الدخول الوحيدة المعتمدة لإنشاء حالة
  /// طوارئ من أي وحدة أخرى في النظام.
  Future<EmergencyDispatchOutcome> triggerEmergency({
    required String profileId,
    required String reasonAr,
    Map<String, dynamic>? context,
  }) async {
    _caseCounter++;
    final caseId = 'EMG-${DateTime.now().millisecondsSinceEpoch}-$_caseCounter';

    final riskAssessment = riskLevelEngine.assess(context ?? {});

    final emergencyCase = EmergencyCase(
      caseId: caseId,
      profileId: profileId,
      triggerReasonAr: reasonAr,
    );
    _activeCases[caseId] = emergencyCase;

    final outcome = await messageManager.dispatchEmergencyMessage(
      profileId: profileId,
      caseId: caseId,
      riskLevel: riskAssessment.level,
      reasonAr: reasonAr,
      latitude: (context?['latitude'] as num?)?.toDouble(),
      longitude: (context?['longitude'] as num?)?.toDouble(),
    );

    // تنبيه حسي فوري على جهاز المستخدم — صوت وضوء واهتزاز طبيعي، أو
    // ضوء فقط إن كان الوضع الصامت مفعَّلاً (انظر تعليق الحقلين أعلاه).
    if (silentSignalController != null) {
      silentSignalController!.signalEmergency(
        profileId: profileId,
        severity: AlertSeverityForSenses.critical,
      );
    } else {
      multiSensoryAlertManager?.triggerAlert(AlertSeverityForSenses.critical);
    }

    HealthEventManager.instance.emitQuick(
      HealthEventType.emergencyTriggered,
      sourceModule: 'emergency_manager',
      profileId: profileId,
      data: {'caseId': caseId, 'riskLevel': riskAssessment.level},
    );

    return outcome;
  }

  /// إغلاق حالة طوارئ بعد التأكد من استقرار الوضع (يتم يدوياً من قِبل
  /// المستخدم أو جهة ثقة، وليس تلقائياً أبداً).
  bool resolveEmergency(String caseId) {
    final emergencyCase = _activeCases[caseId];
    if (emergencyCase == null || emergencyCase.status != EmergencyStatus.active) {
      return false;
    }
    emergencyCase.status = EmergencyStatus.resolved;
    emergencyCase.resolvedAt = DateTime.now();
    silentSignalController?.clearTrustedCallOverride(emergencyCase.profileId);

    HealthEventManager.instance.emitQuick(
      HealthEventType.emergencyResolved,
      sourceModule: 'emergency_manager',
      profileId: emergencyCase.profileId,
      data: {'caseId': caseId},
    );
    return true;
  }

  List<EmergencyCase> activeCasesFor(String profileId) {
    return _activeCases.values
        .where((c) => c.profileId == profileId && c.status == EmergencyStatus.active)
        .toList();
  }
}
