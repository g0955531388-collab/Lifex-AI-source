/// =============================================================
/// Lifex-AI — وحدة التأهيل والتدريب
/// الملف: ai_training_mentor.dart
/// المسار: lib/features/education/ai_training_mentor.dart
/// الوصف: مساعد ذكي يقترح مسار تعلّم مناسباً للمتدرب بناءً على تقدّمه
/// الحالي، ويجيب على أسئلة عامة حول محتوى الدورة.
/// =============================================================
library;

import 'institution_program_manager.dart';
import 'learner_profile.dart';

class MentorRecommendation {
  final List<String> recommendedNextCourseIds;
  final String messageAr;

  const MentorRecommendation({
    required this.recommendedNextCourseIds,
    required this.messageAr,
  });
}

/// مساعد التدريب الذكي.
class AiTrainingMentor {
  AiTrainingMentor({required this.programManager});

  final InstitutionProgramManager programManager;

  /// اقتراح دورات تالية مناسبة بناءً على ما أكمله المتعلم بالفعل ضمن
  /// نفس المؤسسة (منطق بسيط: دورات لم يُكملها بعد من نفس المؤسسات التي
  /// أكمل منها دورة واحدة على الأقل).
  MentorRecommendation recommendNextSteps(LearnerProfile learner) {
    if (learner.completedCourseIds.isEmpty) {
      return const MentorRecommendation(
        recommendedNextCourseIds: [],
        messageAr: 'ابدأ بأول دورة تناسب اهتماماتك لنقترح عليك مساراً مخصصاً بعدها.',
      );
    }

    final completedInstitutionIds = learner.completedCourseIds
        .map((id) => programManager.getCourseById(id)?.institutionId)
        .whereType<String>()
        .toSet();

    final candidates = <String>[];
    for (final institutionId in completedInstitutionIds) {
      final courses = programManager.coursesForInstitution(institutionId);
      for (final course in courses) {
        if (!learner.completedCourseIds.contains(course.courseId) &&
            !learner.enrolledCourseIds.contains(course.courseId)) {
          candidates.add(course.courseId);
        }
      }
    }

    return MentorRecommendation(
      recommendedNextCourseIds: candidates,
      messageAr: candidates.isEmpty
          ? 'أنت مواكب لكل الدورات المتاحة حالياً من مؤسساتك المفضّلة!'
          : 'بناءً على تقدّمك، قد تهمّك هذه الدورات التالية.',
    );
  }
}
