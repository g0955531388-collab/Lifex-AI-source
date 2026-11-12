/// =============================================================
/// Lifex-AI — وحدة التأهيل والتدريب
/// الملف: trainer_profile.dart
/// المسار: lib/features/education/trainer_profile.dart
/// الوصف: ملف المدرب — قد يكون طبيباً أو أخصائياً معتمداً من مؤسسة
/// شريكة (institution_program_manager.dart).
/// =============================================================
library;

class TrainerProfile {
  final String trainerId;
  final String fullName;
  final String specializationAr;
  final String? affiliatedInstitutionId;
  final List<String> taughtCourseIds;

  TrainerProfile({
    required this.trainerId,
    required this.fullName,
    required this.specializationAr,
    this.affiliatedInstitutionId,
    List<String>? taughtCourseIds,
  }) : taughtCourseIds = taughtCourseIds ?? [];

  void assignCourse(String courseId) {
    if (!taughtCourseIds.contains(courseId)) {
      taughtCourseIds.add(courseId);
    }
  }
}
