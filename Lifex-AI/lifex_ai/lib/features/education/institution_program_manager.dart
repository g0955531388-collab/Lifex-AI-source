/// =============================================================
/// Lifex-AI — وحدة التأهيل والتدريب
/// الملف: institution_program_manager.dart
/// المسار: lib/features/education/institution_program_manager.dart
/// الوصف: إدارة برامج التدريب التي تطرحها مؤسسات شريكة (مستشفى، جامعة،
/// منظمة) — كل برنامج يضم عدة دورات ومدربين.
/// =============================================================
library;

class TrainingCourse {
  final String courseId;
  final String institutionId;
  final String titleAr;
  final String trainerId;
  final int totalHours;

  const TrainingCourse({
    required this.courseId,
    required this.institutionId,
    required this.titleAr,
    required this.trainerId,
    required this.totalHours,
  });
}

class PartnerInstitution {
  final String institutionId;
  final String nameAr;
  final String institutionType; // "hospital" | "university" | "ngo"

  const PartnerInstitution({
    required this.institutionId,
    required this.nameAr,
    required this.institutionType,
  });
}

/// مدير برامج المؤسسات الشريكة.
class InstitutionProgramManager {
  InstitutionProgramManager();

  final Map<String, PartnerInstitution> _institutions = {};
  final Map<String, TrainingCourse> _courses = {};

  void registerInstitution(PartnerInstitution institution) {
    _institutions[institution.institutionId] = institution;
  }

  void addCourse(TrainingCourse course) {
    _courses[course.courseId] = course;
  }

  List<TrainingCourse> coursesForInstitution(String institutionId) {
    return _courses.values
        .where((c) => c.institutionId == institutionId)
        .toList();
  }

  TrainingCourse? getCourseById(String courseId) => _courses[courseId];
}
