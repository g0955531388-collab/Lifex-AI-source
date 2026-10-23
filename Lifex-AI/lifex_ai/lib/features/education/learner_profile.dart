/// =============================================================
/// Lifex-AI — وحدة التأهيل والتدريب
/// الملف: learner_profile.dart
/// المسار: lib/features/education/learner_profile.dart
/// الوصف: ملف المتعلم/المتدرب داخل منصة التأهيل — منفصل عن الملف
/// الصحي، لكن قد يرتبط به لأغراض تدريب طبي متخصص (مثل تدريب مسعفين).
/// =============================================================
library;

class LearnerProfile {
  final String learnerId;
  final String? linkedHealthProfileId;
  final String fullName;
  final List<String> enrolledCourseIds;
  final List<String> completedCourseIds;

  LearnerProfile({
    required this.learnerId,
    this.linkedHealthProfileId,
    required this.fullName,
    List<String>? enrolledCourseIds,
    List<String>? completedCourseIds,
  })  : enrolledCourseIds = enrolledCourseIds ?? [],
        completedCourseIds = completedCourseIds ?? [];

  void enrollInCourse(String courseId) {
    if (!enrolledCourseIds.contains(courseId)) {
      enrolledCourseIds.add(courseId);
    }
  }

  void markCourseCompleted(String courseId) {
    enrolledCourseIds.remove(courseId);
    if (!completedCourseIds.contains(courseId)) {
      completedCourseIds.add(courseId);
    }
  }
}
