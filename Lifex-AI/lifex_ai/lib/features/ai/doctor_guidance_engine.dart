/// =============================================================
/// Lifex-AI — الذكاء الاصطناعي الصحي
/// الملف: doctor_guidance_engine.dart
/// المسار: lib/features/ai/doctor_guidance_engine.dart
/// الوصف: محرك يساعد المستخدم على تحديد أي تخصص طبي يحتاج مراجعته
/// بناءً على الأعراض أو الحالة المذكورة، ويُجهّز ملخصاً منظماً يسهّل
/// على الطبيب فهم الحالة سريعاً (وليس بديلاً عن الفحص السريري).
/// =============================================================
library;

import 'ai_engine.dart';
import 'health_analysis_engine.dart';

/// التخصصات الطبية الأساسية التي يمكن التوجيه إليها.
enum MedicalSpecialty {
  generalPractice,
  cardiology,
  endocrinology,
  pulmonology,
  neurology,
  hematology,
  dermatology,
  dentistry,
  obstetricsGynecology,
  emergencyMedicine,
}

/// خريطة توجيه: أي نظام جسدي (bodySystem في قاعدة الأعراض) يقود لأي
/// تخصص طبي عادة.
const Map<String, MedicalSpecialty> _bodySystemToSpecialty = {
  'cardiovascular': MedicalSpecialty.cardiology,
  'respiratory': MedicalSpecialty.pulmonology,
  'neurological': MedicalSpecialty.neurology,
  'endocrine': MedicalSpecialty.endocrinology,
  'hematology': MedicalSpecialty.hematology,
  'dental': MedicalSpecialty.dentistry,
};

/// نتيجة توجيه المستخدم لتخصص طبي مناسب.
class DoctorGuidanceResult {
  final MedicalSpecialty recommendedSpecialty;
  final String specialtyNameAr;
  final String prefilledSummaryForDoctor;
  final AiResponse response;

  const DoctorGuidanceResult({
    required this.recommendedSpecialty,
    required this.specialtyNameAr,
    required this.prefilledSummaryForDoctor,
    required this.response,
  });
}

const Map<MedicalSpecialty, String> _specialtyNamesAr = {
  MedicalSpecialty.generalPractice: 'طب عام',
  MedicalSpecialty.cardiology: 'أمراض القلب',
  MedicalSpecialty.endocrinology: 'الغدد الصماء والسكري',
  MedicalSpecialty.pulmonology: 'أمراض الصدر والتنفس',
  MedicalSpecialty.neurology: 'الأعصاب',
  MedicalSpecialty.hematology: 'أمراض الدم',
  MedicalSpecialty.dermatology: 'الجلدية',
  MedicalSpecialty.dentistry: 'طب الأسنان',
  MedicalSpecialty.obstetricsGynecology: 'النسائية والتوليد',
  MedicalSpecialty.emergencyMedicine: 'طب الطوارئ',
};

/// محرك التوجيه للطبيب المناسب، ويعمل عادة بعد HealthAnalysisEngine
/// لأنه يحتاج نتائجه (الأعراض المطابقة والنظام الجسدي المرتبط بها).
class DoctorGuidanceEngine {
  DoctorGuidanceEngine({required this.symptomBodySystemMap});

  /// خريطة: معرّف العرض → النظام الجسدي (مثال: {'s008': 'cardiovascular'}).
  /// تُبنى من نفس بيانات symptoms_database.json.
  final Map<String, String> symptomBodySystemMap;

  void registerWithAiEngine(AiEngine engine, HealthAnalysisEngine analysisEngine) {
    engine.registerHandler(
      AiQueryType.generalHealthQuestion,
      (query, context) {
        final analysis = analysisEngine.analyze(query);
        return guideFromAnalysis(analysis).response;
      },
    );
  }

  /// تحديد التخصص المناسب بناءً على نتيجة تحليل الأعراض.
  DoctorGuidanceResult guideFromAnalysis(SymptomAnalysisResult analysis) {
    if (analysis.isEmergencyIndicator) {
      return DoctorGuidanceResult(
        recommendedSpecialty: MedicalSpecialty.emergencyMedicine,
        specialtyNameAr: _specialtyNamesAr[MedicalSpecialty.emergencyMedicine]!,
        prefilledSummaryForDoctor: _buildSummary(analysis.matchedSymptomIds),
        response: analysis.response,
      );
    }

    if (analysis.matchedSymptomIds.isEmpty) {
      return DoctorGuidanceResult(
        recommendedSpecialty: MedicalSpecialty.generalPractice,
        specialtyNameAr: _specialtyNamesAr[MedicalSpecialty.generalPractice]!,
        prefilledSummaryForDoctor: 'لم تُحدَّد أعراض واضحة بعد.',
        response: analysis.response,
      );
    }

    // تحديد التخصص الأكثر تكراراً بين الأنظمة الجسدية للأعراض المطابقة.
    final Map<MedicalSpecialty, int> specialtyVotes = {};
    for (final symptomId in analysis.matchedSymptomIds) {
      final bodySystem = symptomBodySystemMap[symptomId];
      final specialty = _bodySystemToSpecialty[bodySystem];
      if (specialty != null) {
        specialtyVotes.update(specialty, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    final chosenSpecialty = specialtyVotes.isEmpty
        ? MedicalSpecialty.generalPractice
        : specialtyVotes.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key;

    return DoctorGuidanceResult(
      recommendedSpecialty: chosenSpecialty,
      specialtyNameAr: _specialtyNamesAr[chosenSpecialty]!,
      prefilledSummaryForDoctor: _buildSummary(analysis.matchedSymptomIds),
      response: AiResponse(
        summaryAr:
            'بناءً على الأعراض المذكورة، قد يكون من المناسب مراجعة تخصص '
            '"${_specialtyNamesAr[chosenSpecialty]}". هذا اقتراح استرشادي '
            'فقط وليس تحويلاً طبياً رسمياً.',
        suggestedNextSteps: const ['يمكنك حجز موعد مباشرة من داخل التطبيق'],
        recommendsDoctorVisit: true,
      ),
    );
  }

  String _buildSummary(List<String> symptomIds) {
    if (symptomIds.isEmpty) return 'لا توجد أعراض مسجّلة.';
    return 'الأعراض المُدخلة من المريض (معرّفات مرجعية): ${symptomIds.join(', ')}. '
        'هذا الملخص آلي ويحتاج تأكيداً سريرياً من الطبيب.';
  }
}
