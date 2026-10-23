/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: coordinator_agent.dart
/// المسار: lib/core/agent/agents/coordinator_agent.dart
/// الوصف: الوكيل المركزي (بند 4) — نقطة الدخول الوحيدة التي تستخدمها
/// الواجهة (screens/ai_agent_screen.dart). يغلّف AgentOrchestrator مضيفاً
/// فحص طوارئ استباقي عبر EmergencyAgent قبل تشغيل أي خطة (بند 15: أي
/// عملية عالية الخطورة تتوقف قبل التنفيذ)، ويُبقي بقية الوكلاء
/// المتخصصين (Medical/Vision/Knowledge/Report) متاحين لخطوات التنفيذ
/// الفعلية داخل الأدوات دون الحاجة لأن تعرف الواجهة بوجودهم.
/// =============================================================
library;

import '../agent_confidence.dart';
import '../agent_context.dart';
import '../agent_orchestrator.dart';
import '../agent_result.dart';
import '../agent_state.dart';
import 'emergency_agent.dart';
import 'knowledge_agent.dart';
import 'medical_agent.dart';
import 'report_agent.dart';
import 'specialized_agent.dart';
import 'vision_agent.dart';

class CoordinatorAgent implements SpecializedAgent {
  CoordinatorAgent({
    required AgentOrchestrator orchestrator,
    required EmergencyAgent emergencyAgent,
    required MedicalAgent medicalAgent,
    required VisionAgent visionAgent,
    required KnowledgeAgent knowledgeAgent,
    required ReportAgent reportAgent,
  })  : _orchestrator = orchestrator,
        _emergencyAgent = emergencyAgent,
        medical = medicalAgent,
        vision = visionAgent,
        knowledge = knowledgeAgent,
        report = reportAgent;

  final AgentOrchestrator _orchestrator;
  final EmergencyAgent _emergencyAgent;

  // مكشوفة للقراءة فقط — الأدوات (tools/) هي من تستدعي هذه الوكلاء
  // فعلياً أثناء التنفيذ عبر AgentToolRegistry، وليس Coordinator مباشرة.
  final MedicalAgent medical;
  final VisionAgent vision;
  final KnowledgeAgent knowledge;
  final ReportAgent report;

  @override
  String get agentName => 'CoordinatorAgent';

  @override
  String get responsibilityAr =>
      'استقبال طلب المستخدم، فحص الطوارئ أولاً، ثم تشغيل الخطة عبر Orchestrator.';

  AgentTaskState stateOf(String taskId) => _orchestrator.stateOf(taskId);

  void cancelTask(String taskId) => _orchestrator.cancelTask(taskId);

  /// نقطة الدخول الرئيسية من الواجهة (بند 4، خطوات 1-10). فحص الطوارئ
  /// يحدث أولاً وبمعزل عن الخطة العادية — إن كانت الحالة حرجة/عالية
  /// الخطورة، تتوقف المهمة العادية وتُعاد نتيجة تطلب تأكيداً بشرياً
  /// فورياً بدل المتابعة التلقائية (بند 15).
  Future<AgentResult> handleUserRequest({
    required AgentContext context,
    required String sessionId,
    Map<String, dynamic>? emergencyTriggerContext,
    AgentTaskProgressListener? onProgress,
  }) async {
    if (emergencyTriggerContext != null) {
      final emergencyAssessment = _emergencyAgent.assess(emergencyTriggerContext);

      if (emergencyAssessment.requiresImmediateHumanAttention) {
        return AgentResult(
          taskId: context.taskId,
          finalState: AgentTaskState.blocked,
          summaryAr:
              'تم رصد مؤشر يستدعي انتباهاً عاجلاً: ${emergencyAssessment.reasonAr}',
          confidence: _confidenceFromRiskLevel(emergencyAssessment.riskLevel),
          disclaimerAr: kAgentDefaultDisclaimerAr,
          errorMessageAr:
              'الرجاء تأكيد الحالة يدوياً أو التواصل مع خدمات الطوارئ فوراً إذا لزم الأمر.',
        );
      }
    }

    return _orchestrator.runTask(
      context: context,
      sessionId: sessionId,
      onProgress: onProgress,
    );
  }

  AgentConfidence _confidenceFromRiskLevel(String level) {
    // مستوى الخطر ليس مستوى ثقة، لكن حالات الطوارئ الحرجة تُعامَل دوماً
    // كمعلومة عالية الثقة من ناحية "يجب التصرف الآن" — التحويل هنا
    // توثيقي فقط ولا يُستخدم لتبرير قرار سريري.
    return level == 'critical' || level == 'high'
        ? AgentConfidence.high
        : AgentConfidence.medium;
  }
}
