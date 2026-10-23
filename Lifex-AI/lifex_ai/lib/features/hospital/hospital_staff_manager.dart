/// =============================================================
/// Lifex-AI — وحدة المستشفيات
/// الملف: hospital_staff_manager.dart
/// المسار: lib/features/hospital/hospital_staff_manager.dart
/// الوصف: إدارة الأطباء والطاقم الطبي الداخلي للمستشفى ومناوباتهم،
/// منفصل عن doctor_schedule_manager.dart الخاص بالأطباء المستقلين.
/// =============================================================
library;

enum StaffRole { physician, nurse, technician, administrator }

class HospitalStaffMember {
  final String staffId;
  final String hospitalId;
  final String fullName;
  final StaffRole role;
  final String? departmentId;

  const HospitalStaffMember({
    required this.staffId,
    required this.hospitalId,
    required this.fullName,
    required this.role,
    this.departmentId,
  });
}

class ShiftAssignment {
  final String staffId;
  final DateTime start;
  final DateTime end;

  const ShiftAssignment({
    required this.staffId,
    required this.start,
    required this.end,
  });

  bool coversTime(DateTime time) => time.isAfter(start) && time.isBefore(end);
}

/// مدير الطاقم الطبي الداخلي.
class HospitalStaffManager {
  HospitalStaffManager();

  final Map<String, HospitalStaffMember> _staff = {};
  final List<ShiftAssignment> _shifts = [];

  void registerStaffMember(HospitalStaffMember member) {
    _staff[member.staffId] = member;
  }

  void assignShift(ShiftAssignment shift) {
    _shifts.add(shift);
  }

  List<HospitalStaffMember> staffInDepartment(String departmentId) {
    return _staff.values.where((s) => s.departmentId == departmentId).toList();
  }

  /// الطاقم المناوب حالياً في قسم معيّن.
  List<HospitalStaffMember> onDutyNowInDepartment(String departmentId) {
    final now = DateTime.now();
    final onDutyIds = _shifts
        .where((s) => s.coversTime(now))
        .map((s) => s.staffId)
        .toSet();

    return staffInDepartment(departmentId)
        .where((s) => onDutyIds.contains(s.staffId))
        .toList();
  }
}
