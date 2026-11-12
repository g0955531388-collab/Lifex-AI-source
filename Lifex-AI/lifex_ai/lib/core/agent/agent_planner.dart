/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_planner.dart
/// المسار: lib/core/agent/agent_planner.dart
/// الوصف: محرك التخطيط (بند 12) وإعادة التخطيط عند الفشل (بند 13).
/// يحوّل هدف المستخدم إلى خطوات قابلة للتتبع، كل خطوة مرتبطة بأداة
/// واحدة محددة سلفاً. هذا Planner قائم على قواعد صريحة (Rule-based) —
/// وليس نموذج تخطيط حر — لضمان قابلية التفسير الكاملة والاختبار
/// الحتمي (نفس فلسفة RiskLevelEngine في features/emergency/).
/// =============================================================
library;

import 'agent_context.dart';

class PlanStep {
  const PlanStep({
    required this.stepId,
    required this.toolName,
    required this.descriptionAr,
    this.dependsOnStepIds = const [],
  });

  final String stepId;
  final String toolName;
  final String descriptionAr;

  /// خطوات يجب أن تنجح قبل هذه الخطوة — تُستخدم من AgentExecutor لمنع
  /// تنفيذ خطوة تعتمد على مُخرج خطوة سابقة فشلت.
  final List<String> dependsOnStepIds;
}

class AgentPlan {
  const AgentPlan({required this.goalAr, required this.steps});

  final String goalAr;
  final List<PlanStep> steps;

  bool get isEmpty => steps.isEmpty;
}

/// نية مُكتشَفة من طلب المستخدم — نتاج "فهم الطلب" (Understanding) قبل
/// التخطيط الفعلي.
enum DetectedIntent {
  analyzeDocument, // "حلل هذا التقرير"
  analyzeImage, // صورة جلد/جرح/دواء
  symptomQuestion, // سؤال أعراض نصي بسيط
  generalKnowledgeQuestion, // سؤال معرفي عام
  unknown,
}

class AgentPlanner {
  const AgentPlanner();

  /// اكتشاف نية بسيطة وشفافة من الطلب + السياق المرفق (وجود ملف/صورة
  /// من عدمه) — بدون استدعاء نموذج خارجي لهذه الخطوة تحديداً، لأن
  /// اكتشاف "هل يوجد ملف مرفق؟" معلومة محلية أكيدة لا تحتاج استنتاجاً.
  DetectedIntent detectIntent(AgentContext context) {
    final hasDocument = context.taskContext['hasAttachedDocument'] == true;
    final hasImage = context.taskContext['hasAttachedImage'] == true;

    if (hasDocument) return DetectedIntent.analyzeDocument;
    if (hasImage) return DetectedIntent.analyzeImage;

    final request = context.userRequest;
    if (request.trim().isEmpty) return DetectedIntent.unknown;

    // فحص كلمات مفتاحية بسيطة لأعراض — مطابقة مبدئية فقط؛ الفهم
    // الفعلي العميق يبقى لـ Medical Agent عبر قاعدة المعرفة.
    const symptomKeywords = ['أشعر', 'عندي', 'ألم', 'صداع', 'حمى', 'وجع'];
    if (symptomKeywords.any(request.contains)) {
      return DetectedIntent.symptomQuestion;
    }

    return DetectedIntent.generalKnowledgeQuestion;
  }

  /// بناء خطة وفق النية المكتشفة. كل مثال هنا يطابق سيناريو "حلل هذا
  /// التقرير الطبي وأنشئ تقريراً مختصراً" الوارد في بند 4 و38.
  AgentPlan buildPlan(DetectedIntent intent, AgentContext context) {
    switch (intent) {
      case DetectedIntent.analyzeDocument:
        return const AgentPlan(
          goalAr: 'تحليل المستند وإنشاء تقرير مختصر',
          steps: [
            PlanStep(
              stepId: 'read_document',
              toolName: 'document_reader',
              descriptionAr: 'قراءة المستند واستخراج النص',
            ),
            PlanStep(
              stepId: 'search_knowledge',
              toolName: 'knowledge_search',
              descriptionAr: 'البحث في قاعدة المعرفة عن العناصر ذات الصلة',
              dependsOnStepIds: ['read_document'],
            ),
            PlanStep(
              stepId: 'generate_report',
              toolName: 'report_generator',
              descriptionAr: 'إنشاء التقرير النهائي',
              dependsOnStepIds: ['read_document', 'search_knowledge'],
            ),
          ],
        );

      case DetectedIntent.analyzeImage:
        return const AgentPlan(
          goalAr: 'تحليل الصورة المرفقة',
          steps: [
            PlanStep(
              stepId: 'analyze_image',
              toolName: 'image_analysis',
              descriptionAr: 'تحليل الصورة المرفقة',
            ),
            PlanStep(
              stepId: 'search_knowledge',
              toolName: 'knowledge_search',
              descriptionAr: 'البحث في قاعدة المعرفة عن العناصر ذات الصلة',
              dependsOnStepIds: ['analyze_image'],
            ),
            PlanStep(
              stepId: 'generate_report',
              toolName: 'report_generator',
              descriptionAr: 'إنشاء ملخص النتيجة',
              dependsOnStepIds: ['analyze_image', 'search_knowledge'],
            ),
          ],
        );

      case DetectedIntent.symptomQuestion:
        return const AgentPlan(
          goalAr: 'الإجابة عن استفسار الأعراض',
          steps: [
            PlanStep(
              stepId: 'search_knowledge',
              toolName: 'knowledge_search',
              descriptionAr: 'البحث في قاعدة المعرفة عن الأعراض المذكورة',
            ),
            PlanStep(
              stepId: 'generate_report',
              toolName: 'report_generator',
              descriptionAr: 'صياغة رد منظم',
              dependsOnStepIds: ['search_knowledge'],
            ),
          ],
        );

      case DetectedIntent.generalKnowledgeQuestion:
        return const AgentPlan(
          goalAr: 'الإجابة عن سؤال عام',
          steps: [
            PlanStep(
              stepId: 'search_knowledge',
              toolName: 'knowledge_search',
              descriptionAr: 'البحث في قاعدة المعرفة',
            ),
          ],
        );

      case DetectedIntent.unknown:
        return const AgentPlan(goalAr: 'غير محدد', steps: []);
    }
  }

  /// إعادة تخطيط بعد فشل خطوة (بند 13). لا تُعيد نفس الأداة إلى ما لا
  /// نهاية — الحد الأقصى للمحاولات يُفرض من AgentExecutor، وهذه الدالة
  /// فقط تقترح "بديلاً" منطقياً إن وُجد، وإلا تُرجع null (ما يعني:
  /// اطلب تدخل المستخدم أو أوقف بأمان — بند 13).
  PlanStep? suggestAlternativeStep(PlanStep failedStep) {
    const alternatives = {
      'image_analysis': 'document_reader', // إن فشل تحليل الصورة، جرّب OCR كبديل نصي
    };

    final alternativeTool = alternatives[failedStep.toolName];
    if (alternativeTool == null) return null;

    return PlanStep(
      stepId: '${failedStep.stepId}_alt',
      toolName: alternativeTool,
      descriptionAr: 'محاولة بديلة: ${failedStep.descriptionAr}',
      dependsOnStepIds: failedStep.dependsOnStepIds,
    );
  }
}
