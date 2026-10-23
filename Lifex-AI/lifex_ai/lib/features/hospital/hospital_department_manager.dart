/// =============================================================
/// Lifex-AI — وحدة المستشفيات
/// الملف: hospital_department_manager.dart
/// المسار: lib/features/hospital/hospital_department_manager.dart
/// الوصف: إدارة الأقسام الطبية داخل المستشفى (قلب، جراحة، أطفال...).
/// =============================================================
library;

class HospitalDepartment {
  final String departmentId;
  final String hospitalId;
  final String departmentNameAr;
  final int bedCapacity;

  const HospitalDepartment({
    required this.departmentId,
    required this.hospitalId,
    required this.departmentNameAr,
    required this.bedCapacity,
  });
}

/// مدير الأقسام الطبية.
class HospitalDepartmentManager {
  HospitalDepartmentManager();

  final Map<String, HospitalDepartment> _departments = {};

  void registerDepartment(HospitalDepartment department) {
    _departments[department.departmentId] = department;
  }

  List<HospitalDepartment> departmentsFor(String hospitalId) {
    return _departments.values
        .where((d) => d.hospitalId == hospitalId)
        .toList();
  }

  HospitalDepartment? getById(String departmentId) =>
      _departments[departmentId];
}
