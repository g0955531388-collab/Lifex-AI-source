/// =============================================================
/// Lifex-AI — الذكاء الاصطناعي الصحي
/// الملف: ai_engine.dart
/// المسار: lib/features/ai/ai_engine.dart
/// الوصف: المحرك الرئيسي للذكاء الاصطناعي الصحي الداخلي في Lifex-AI.
/// هذا المحرك لا يُصدر تشخيصاً نهائياً أبداً — دوره تنظيم الاستعلامات
/// وتوجيهها للمحركات الفرعية المتخصصة (تحليل، توجيه للطبيب، قرار).
///
/// ⚠️ التزام إلزامي بمتطلبات متاجر التطبيقات (Google Play):
/// أي استجابة تخرج من هذا المحرك تحتوي حقل [AiResponse.disclaimer] الذي
/// يجب عرضه دائماً في الواجهة ولا يجوز حذفه أو إخفاؤه برمجياً.
/// =============================================================
library;

import '../../core/error_handler.dart';
import '../../core/health_event_manager.dart';

/// تصنيف نوع الاستعلام الذي يُرسله المستخدم للذكاء الاصطناعي.
enum AiQueryType {
  symptomCheck, // "عندي صداع ودوخة"
  medicationQuestion, // "هل يمكنني أخذ هذا الدواء مع ذاك؟"
  generalHealthQuestion, // سؤال توعوي عام
  labResultExplanation, // "فسّرلي نتيجة التحليل دي"
  emergencyIndicator, // نص يحمل مؤشرات طارئة صريحة
}

/// استجابة موحّدة من محرك الذكاء الاصطناعي — تُستخدم كنموذج واحد لكل
/// المحركات الفرعية حتى تتوحد طريقة عرضها في الواجهة.
class AiResponse {
  final String summaryAr;
  final List<String> suggestedNextSteps;
  final bool recommendsDoctorVisit;
  final bool triggeredEmergency;

  /// نص إخلاء المسؤولية — إلزامي ويُعرض دائماً مع أي رد يخص الصحة.
  final String disclaimer;

  const AiResponse({
    required this.summaryAr,
    this.suggestedNextSteps = const [],
    this.recommendsDoctorVisit = false,
    this.triggeredEmergency = false,
    this.disclaimer =
        'هذه معلومة استرشادية عامة من الذكاء الاصطناعي ولا تُعد تشخيصاً طبياً. '
        'يُرجى دائماً استشارة طبيب مختص، وفي حال وجود أعراض خطيرة اتصل بالإسعاف فوراً.',
  });
}

/// توقيع دالة أي محرك فرعي يمكن توصيله بـ AiEngine (نمط Strategy/Plugin)
/// حتى يسهل إضافة محركات جديدة دون تعديل هذا الملف.
typedef AiSubEngineHandler = AiResponse Function(String query, Map<String, dynamic> context);

/// المحرك الرئيسي — نقطة الدخول الموحدة لكل استعلامات الذكاء الاصطناعي
/// الصحي داخل التطبيق. لا يحتوي منطقاً طبياً بذاته؛ يوجّه فقط.
class AiEngine {
  AiEngine._internal();
  static final AiEngine instance = AiEngine._internal();

  final Map<AiQueryType, AiSubEngineHandler> _handlers = {};

  /// تسجيل محرك فرعي متخصص لنوع استعلام معيّن. يُستدعى هذا من كل محرك
  /// فرعي (health_analysis_engine.dart، doctor_guidance_engine.dart...)
  /// عند تهيئة التطبيق.
  void registerHandler(AiQueryType type, AiSubEngineHandler handler) {
    _handlers[type] = handler;
  }

  /// معالجة استعلام المستخدم وتوجيهه للمحرك الفرعي المناسب.
  AiResponse process({
    required String query,
    required AiQueryType type,
    String? profileId,
    Map<String, dynamic>? context,
  }) {
    final handler = _handlers[type];

    if (handler == null) {
      ErrorHandler.instance.report(
        'AI_NO_HANDLER_REGISTERED',
        'لا يوجد محرك فرعي مسجّل لنوع الاستعلام: ${type.name}',
        sourceModule: 'ai_engine',
        severity: ErrorSeverity.warning,
      );
      return const AiResponse(
        summaryAr: 'تعذر معالجة هذا الطلب حالياً. يُرجى المحاولة لاحقاً أو التواصل مع طبيب مباشرة.',
      );
    }

    final response = handler(query, context ?? {});

    if (response.triggeredEmergency) {
      HealthEventManager.instance.emitQuick(
        HealthEventType.emergencyTriggered,
        sourceModule: 'ai_engine',
        profileId: profileId,
        data: {'triggerType': type.name, 'query': query},
      );
    }

    return response;
  }

  /// هل يوجد محرك فرعي مسجّل بالفعل لنوع استعلام معيّن؟
  bool hasHandlerFor(AiQueryType type) => _handlers.containsKey(type);
}
