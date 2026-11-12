/// =============================================================
/// Lifex-AI — وحدة المستشفيات
/// الملف: hospital_roles_permissions.dart
/// المسار: lib/features/hospital/hospital_roles_permissions.dart
/// الوصف: نظام صلاحيات إداري يحدد ما يُسمح لكل دور وظيفي داخل المستشفى
/// برؤيته أو تعديله (مدير، طبيب، ممرض، محاسب...).
/// =============================================================
library;

enum HospitalPermission {
  viewPatientRecords,
  editPatientRecords,
  manageStaffSchedule,
  manageEquipment,
  manageFinance,
  manageBloodBank,
  admitDischargePatients,
}

enum HospitalStaffRoleLevel { admin, physician, nurse, technician, financeStaff }

/// خريطة الصلاحيات الافتراضية لكل دور — صريحة وثابتة (Role-Based Access
/// Control بسيط)، يسهل مراجعتها والتدقيق عليها.
const Map<HospitalStaffRoleLevel, Set<HospitalPermission>> _defaultRolePermissions = {
  HospitalStaffRoleLevel.admin: {
    HospitalPermission.viewPatientRecords,
    HospitalPermission.editPatientRecords,
    HospitalPermission.manageStaffSchedule,
    HospitalPermission.manageEquipment,
    HospitalPermission.manageFinance,
    HospitalPermission.manageBloodBank,
    HospitalPermission.admitDischargePatients,
  },
  HospitalStaffRoleLevel.physician: {
    HospitalPermission.viewPatientRecords,
    HospitalPermission.editPatientRecords,
    HospitalPermission.admitDischargePatients,
  },
  HospitalStaffRoleLevel.nurse: {
    HospitalPermission.viewPatientRecords,
    HospitalPermission.admitDischargePatients,
  },
  HospitalStaffRoleLevel.technician: {
    HospitalPermission.manageEquipment,
  },
  HospitalStaffRoleLevel.financeStaff: {
    HospitalPermission.manageFinance,
  },
};

/// نظام إدارة الصلاحيات الإدارية داخل المستشفى.
class HospitalRolesPermissions {
  HospitalRolesPermissions();

  final Map<String, HospitalStaffRoleLevel> _staffRoles = {};

  void assignRole(String staffId, HospitalStaffRoleLevel role) {
    _staffRoles[staffId] = role;
  }

  bool hasPermission(String staffId, HospitalPermission permission) {
    final role = _staffRoles[staffId];
    if (role == null) return false;
    return _defaultRolePermissions[role]?.contains(permission) ?? false;
  }

  HospitalStaffRoleLevel? roleOf(String staffId) => _staffRoles[staffId];
}
