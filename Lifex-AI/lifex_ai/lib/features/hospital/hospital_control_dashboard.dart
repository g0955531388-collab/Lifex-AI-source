/// =============================================================
/// Lifex-AI — وحدة المستشفيات
/// الملف: hospital_control_dashboard.dart
/// المسار: lib/features/hospital/hospital_control_dashboard.dart
/// الوصف: مجمّع بيانات لوحة التحكم الإدارية الشاملة للمستشفى — يجمع
/// ملخصات من كل الوحدات الفرعية (مرضى، طوارئ، أقسام) دون تكرار منطقها.
/// =============================================================
library;

import 'hospital_department_manager.dart';
import 'hospital_emergency_ems.dart';
import 'hospital_patient_registry.dart';

class HospitalOverviewSummary {
  final int totalAdmittedPatients;
  final int activeEmergencyCases;
  final int totalDepartments;
  final Map<String, int> occupancyByDepartment;

  const HospitalOverviewSummary({
    required this.totalAdmittedPatients,
    required this.activeEmergencyCases,
    required this.totalDepartments,
    required this.occupancyByDepartment,
  });
}

/// لوحة التحكم الإدارية للمستشفى.
class HospitalControlDashboard {
  HospitalControlDashboard({
    required this.patientRegistry,
    required this.departmentManager,
    required this.emergencyEms,
  });

  final HospitalPatientRegistry patientRegistry;
  final HospitalDepartmentManager departmentManager;
  final HospitalEmergencyEms emergencyEms;

  HospitalOverviewSummary buildOverview(String hospitalId) {
    final admittedCount = patientRegistry.admittedPatientsCount(hospitalId);
    final activeEms = emergencyEms.activeCasesCount(hospitalId);
    final departments = departmentManager.departmentsFor(hospitalId);

    final occupancy = <String, int>{};
    for (final dept in departments) {
      occupancy[dept.departmentNameAr] =
          patientRegistry.patientsInDepartment(dept.departmentId).length;
    }

    return HospitalOverviewSummary(
      totalAdmittedPatients: admittedCount,
      activeEmergencyCases: activeEms,
      totalDepartments: departments.length,
      occupancyByDepartment: occupancy,
    );
  }
}
