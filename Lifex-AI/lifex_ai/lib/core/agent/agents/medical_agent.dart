/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: medical_agent.dart
/// المسار: lib/core/agent/agents/medical_agent.dart
/// الوصف: الوكيل الطبي (بند 14). مسؤوليته تفسير البيانات الطبية،
/// تنظيم النتائج، مقارنتها بالمعرفة المتاحة، وصياغة تحليل أولي —
/// دون تشخيص قطعي أبداً (بند 31). لا يحتوي منطق مطابقة أعراض بذاته؛
/// يُعيد استخدام HealthAnalysisEngine/DoctorGuidanceEngine الموجودين
/// فعلاً في features/ai/ عند توفر أعراض واضحة في النص.
/// =============================================================
library;

import '../../../features/ai/doctor_guidance_engine.dart';
import '../../../features/ai/health_analysis_engine.dart';
import '../agent_confidence.dart';
import '../knowledge/knowledge_context.dart';
import 'specialized_agent.dart';

class MedicalAgentAnalysis {
  const MedicalAgentAnalysis({
    required this.summaryAr,
    required this.confidence,
    required this.recommendedSpecialtyAr,
    required this.disclaimerAr,
    this.matchedSymptomIds = const [],
  });

  final String summaryAr;
  final AgentConfidence confidence;
  final String recommendedSpecialtyAr;
  final String disclaimerAr;
  final List<String> matchedSymptomIds;
}

class MedicalAgent implements SpecializedAgent {
  MedicalAgent({
    HealthAnalysisEngine? analysisEngine,
    DoctorGuidanceEngine? guidanceEngine,
  })  : _analysisEngine = analysisEngine,
        _guidanceEngine = guidanceEngine;

  final HealthAnalysisEngine? _analysisEngine;
  final DoctorGuidanceEngine? _guidanceEngine;

  @override
  String get agentName => 'MedicalAgent';

  @override
  String get responsibilityAr =>
      'تفسير البيانات الطبية ومقارنتها بالمعرفة المتاحة دون تشخيص قطعي.';

  /// يبني تحليلاً أولياً من نص حر (أعراض المستخدم) مع نتائج معرفة
  /// مسترجعة مسبقاً من KnowledgeAgent. لا يُصدر أبداً عبارة تشخيص
  /// نهائي — العبارات دائماً محوّطة (hedged) عند الثقة المنخفضة (بند 17).
  MedicalAgentAnalysis analyze({
    required String userTextAr,
    required KnowledgeContext knowledgeContext,
  }) {
    // إن توفّر HealthAnalysisEngine/DoctorGuidanceEngine (يُمرَّران من
    // composition root)، استخدمهما لتوجيه تخصص طبي حقيقي بدل تخمين محلي.
    if (_analysisEngine != null && _guidanceEngine != null) {
      final analysis = _analysisEngine!.analyze(userTextAr);
      final guidance = _guidanceEngine!.guideFromAnalysis(analysis);

      return MedicalAgentAnalysis(
        summaryAr: analysis.isEmergencyIndicator
            ? 'تشير الأعراض المذكورة إلى ضرورة تقييم طبي عاجل.'
            : 'تم تحديد ${analysis.matchedSymptomIds.length} عرض/أعراض ذات صلة بالمعرفة المتوفرة.',
        confidence: analysis.matchedSymptomIds.isEmpty
            ? AgentConfidence.low
            : AgentConfidence.medium,
        recommendedSpecialtyAr: guidance.specialtyNameAr,
        disclaimerAr: analysis.response.disclaimer,
        matchedSymptomIds: analysis.matchedSymptomIds,
      );
    }

    // مسار احتياطي عندما لا تتوفر المحركات المتقدمة (مثلاً في اختبارات
    // وحدة معزولة) — يعتمد فقط على نتائج KnowledgeRetriever المُمرَّرة.
    if (knowledgeContext.isEmpty) {
      return const MedicalAgentAnalysis(
        summaryAr: 'لم يتم العثور على معلومات كافية في قاعدة المعرفة المحلية.',
        confidence: AgentConfidence.unknown,
        recommendedSpecialtyAr: 'طب عام',
        disclaimerAr:
            'هذه معلومة عامة وليست تشخيصاً. يُرجى استشارة مختص عند استمرار الأعراض.',
      );
    }

    return MedicalAgentAnalysis(
      summaryAr:
          'توجد ${knowledgeContext.matches.length} نتيجة ذات صلة في قاعدة المعرفة المحلية.',
      confidence: AgentConfidence.low,
      recommendedSpecialtyAr: 'طب عام',
      disclaimerAr:
          'هذه معلومة عامة وليست تشخيصاً. يُرجى استشارة مختص عند استمرار الأعراض.',
    );
  }
}
