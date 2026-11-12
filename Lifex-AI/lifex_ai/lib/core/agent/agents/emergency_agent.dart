/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: emergency_agent.dart
/// المسار: lib/core/agent/agents/emergency_agent.dart
/// الوصف: وكيل الطوارئ (بند 14/15). يراقب شروط طوارئ معرّفة مسبقاً عبر
/// RiskLevelEngine الموجود فعلاً في features/emergency/risk_level_engine.dart
/// (قواعد صريحة، وليس تخميناً). القاعدة الصارمة غير القابلة للتفاوض:
/// هذا الوكيل لا يتخذ أي إجراء خطير تلقائياً بذاته — فقط يُطلِق Alert
/// عبر NotificationTool، ويطلب دائماً تأكيداً بشرياً للإجراءات الفعلية
/// (اتصال بالإسعاف، إرسال بيانات لطرف ثالث، إلخ).
/// =============================================================
library;

import '../../../core/app_constants.dart';
import '../../../features/emergency/risk_level_engine.dart';
import 'specialized_agent.dart';

class EmergencyAssessmentResult {
  const EmergencyAssessmentResult({
    required this.riskLevel,
    required this.reasonAr,
    required this.requiresImmediateHumanAttention,
  });

  final String riskLevel; // AppConstants.riskLevel*
  final String reasonAr;

  /// true فقط عند 'critical' أو 'high' — يعني: يجب على الواجهة عرض
  /// تنبيه واضح فوراً وطلب تأكيد المستخدم لأي إجراء تالٍ، وليس تنفيذ
  /// إجراء تلقائياً (بند 15: Human-in-the-Loop إلزامي).
  final bool requiresImmediateHumanAttention;
}

class EmergencyAgent implements SpecializedAgent {
  EmergencyAgent({RiskLevelEngine? riskEngine})
      : _riskEngine = riskEngine ?? RiskLevelEngine();

  final RiskLevelEngine _riskEngine;

  @override
  String get agentName => 'EmergencyAgent';

  @override
  String get responsibilityAr =>
      'مراقبة شروط الطوارئ وإطلاق تنبيه دون اتخاذ إجراء خطير مستقل.';

  /// تقييم حالة واحدة — لا يُطلق أي إجراء بذاته؛ يُعيد فقط تقييماً
  /// يستخدمه Coordinator لتحديد ما إذا كانت الخطوة التالية تتطلب توقفاً
  /// لطلب تأكيد بشري (بند 15).
  EmergencyAssessmentResult assess(Map<String, dynamic> triggerContext) {
    final assessment = _riskEngine.assess(triggerContext);

    final requiresAttention = assessment.level == AppConstants.riskLevelCritical ||
        assessment.level == AppConstants.riskLevelHigh;

    return EmergencyAssessmentResult(
      riskLevel: assessment.level,
      reasonAr: assessment.reasonAr,
      requiresImmediateHumanAttention: requiresAttention,
    );
  }
}
