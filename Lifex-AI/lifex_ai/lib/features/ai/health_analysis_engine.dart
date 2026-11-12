/// =============================================================
/// Lifex-AI — الذكاء الاصطناعي الصحي
/// الملف: health_analysis_engine.dart
/// المسار: lib/features/ai/health_analysis_engine.dart
/// الوصف: محرك فرعي متخصص بتحليل الأعراض المُدخلة من المستخدم بالاستناد
/// إلى قاعدة medical_knowledge.json، مع تصعيد فوري لأي مؤشر طارئ.
///
/// ⚠️ هذا المحرك لا يشخّص. أقصى ما يفعله هو ربط الأعراض بمعلومات مرجعية
/// عامة وتوجيه المستخدم لأنسب خطوة تالية (مراجعة طبيب / اتصال بالإسعاف).
/// =============================================================
library;

import 'ai_engine.dart';

/// نتيجة تحليل الأعراض — تُبنى فوق AiResponse لكن بتفاصيل إضافية خاصة
/// بمحرك التحليل الصحي تحديداً.
class SymptomAnalysisResult {
  final List<String> matchedSymptomIds;
  final List<String> possibleGeneralCategories;
  final bool isEmergencyIndicator;
  final AiResponse response;

  const SymptomAnalysisResult({
    required this.matchedSymptomIds,
    required this.possibleGeneralCategories,
    required this.isEmergencyIndicator,
    required this.response,
  });
}

/// محرك تحليل الأعراض. يعتمد على خريطة أعراض مُمررة إليه (تُحمَّل من
/// symptoms_database.json عبر طبقة تحميل بيانات منفصلة) بدلاً من قراءة
/// ملف JSON مباشرة من داخل هذا الملف، حفاظاً على فصل الاهتمامات.
class HealthAnalysisEngine {
  HealthAnalysisEngine({
    required this.symptomKeywordMap,
    required this.emergencySymptomIds,
  });

  /// خريطة: كلمة مفتاحية (بالعربي) → معرّف العرض في قاعدة البيانات.
  /// مثال: {'صداع': 's001', 'ألم في الصدر': 's008'}
  final Map<String, String> symptomKeywordMap;

  /// معرّفات الأعراض التي تُعتبر مؤشرات طوارئ مباشرة (تُحمَّل من
  /// emergencyEscalationRules في medical_knowledge.json).
  final Set<String> emergencySymptomIds;

  /// تسجيل هذا المحرك كمعالج للاستعلامات من نوع symptomCheck داخل
  /// AiEngine المركزي. يُستدعى مرة واحدة عند تهيئة التطبيق.
  void registerWithAiEngine(AiEngine engine) {
    engine.registerHandler(
      AiQueryType.symptomCheck,
      (query, context) => _analyze(query).response,
    );
  }

  /// التحليل الفعلي: البحث عن الكلمات المفتاحية داخل نص المستخدم.
  SymptomAnalysisResult _analyze(String userInput) {
    final normalizedInput = userInput.trim();
    final matchedIds = <String>[];

    symptomKeywordMap.forEach((keyword, symptomId) {
      if (normalizedInput.contains(keyword)) {
        matchedIds.add(symptomId);
      }
    });

    final isEmergency =
        matchedIds.any((id) => emergencySymptomIds.contains(id));

    if (isEmergency) {
      return SymptomAnalysisResult(
        matchedSymptomIds: matchedIds,
        possibleGeneralCategories: const [],
        isEmergencyIndicator: true,
        response: const AiResponse(
          summaryAr: 'الأعراض التي ذكرتها قد تشير إلى حالة طارئة تستدعي '
              'تدخلاً طبياً فورياً.',
          suggestedNextSteps: [
            'اتصل بالإسعاف فوراً',
            'لا تنتظر ولا تعتمد على هذا التطبيق في هذه اللحظة',
          ],
          recommendsDoctorVisit: true,
          triggeredEmergency: true,
        ),
      );
    }

    if (matchedIds.isEmpty) {
      return const SymptomAnalysisResult(
        matchedSymptomIds: [],
        possibleGeneralCategories: [],
        isEmergencyIndicator: false,
        response: AiResponse(
          summaryAr: 'لم أستطع التعرّف بوضوح على أعراض محددة من النص المُدخل. '
              'يُرجى وصف الأعراض بمزيد من التفصيل، أو مراجعة طبيب مباشرة إن '
              'كانت الأعراض تزعجك.',
        ),
      );
    }

    return SymptomAnalysisResult(
      matchedSymptomIds: matchedIds,
      possibleGeneralCategories: const [],
      isEmergencyIndicator: false,
      response: AiResponse(
        summaryAr: 'تم رصد ${matchedIds.length} من الأعراض المذكورة في '
            'قاعدة المعرفة العامة. هذه معلومة استرشادية فقط.',
        suggestedNextSteps: const [
          'يُفضّل مراجعة طبيب لتقييم الحالة بدقة',
          'يمكنك مراجعة سجل أعراضك السابق داخل ملفك الصحي',
        ],
        recommendsDoctorVisit: true,
      ),
    );
  }

  /// واجهة عامة يمكن استدعاؤها مباشرة من وحدات أخرى (مثل chat_ai_assistant
  /// لاحقاً) دون المرور عبر AiEngine إن لزم الأمر.
  SymptomAnalysisResult analyze(String userInput) => _analyze(userInput);
}
