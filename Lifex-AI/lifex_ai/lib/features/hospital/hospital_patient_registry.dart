/// =============================================================
/// Lifex-AI — وحدة المستشفيات
/// الملف: hospital_patient_registry.dart
/// المسار: lib/features/hospital/hospital_patient_registry.dart
/// الوصف: سجل المرضى المنوَّمين حالياً داخل المستشفى، مرتبطين بالقسم
/// المسؤول عنهم. يشير فقط لمعرّف الملف الصحي؛ البيانات الطبية نفسها
/// تبقى في health_profile.dart احتراماً لفصل الاهتمامات والخصوصية.
/// =============================================================
library;

enum AdmissionStatus { admitted, dischargedHome, transferred, deceased }

class HospitalAdmissionRecord {
  final String admissionId;
  final String patientProfileId;
  final String hospitalId;
  final String departmentId;
  final DateTime admittedAt;
  AdmissionStatus status;
  DateTime? dischargedAt;

  HospitalAdmissionRecord({
    required this.admissionId,
    required this.patientProfileId,
    required this.hospitalId,
    required this.departmentId,
    DateTime? admittedAt,
    this.status = AdmissionStatus.admitted,
    this.dischargedAt,
  }) : admittedAt = admittedAt ?? DateTime.now();
}

/// سجل مرضى المستشفى.
class HospitalPatientRegistry {
  HospitalPatientRegistry();

  final Map<String, HospitalAdmissionRecord> _admissions = {};
  int _counter = 0;

  HospitalAdmissionRecord admitPatient({
    required String patientProfileId,
    required String hospitalId,
    required String departmentId,
  }) {
    _counter++;
    final record = HospitalAdmissionRecord(
      admissionId: 'ADM-$_counter',
      patientProfileId: patientProfileId,
      hospitalId: hospitalId,
      departmentId: departmentId,
    );
    _admissions[record.admissionId] = record;
    return record;
  }

  bool dischargePatient(String admissionId, AdmissionStatus finalStatus) {
    final record = _admissions[admissionId];
    if (record == null || record.status != AdmissionStatus.admitted) {
      return false;
    }
    record.status = finalStatus;
    record.dischargedAt = DateTime.now();
    return true;
  }

  bool transferToDepartment(String admissionId, String newDepartmentId) {
    final record = _admissions[admissionId];
    if (record == null) return false;
    _admissions[admissionId] = HospitalAdmissionRecord(
      admissionId: record.admissionId,
      patientProfileId: record.patientProfileId,
      hospitalId: record.hospitalId,
      departmentId: newDepartmentId,
      admittedAt: record.admittedAt,
      status: record.status,
    );
    return true;
  }

  int admittedPatientsCount(String hospitalId) {
    return _admissions.values
        .where((a) =>
            a.hospitalId == hospitalId && a.status == AdmissionStatus.admitted)
        .length;
  }

  List<HospitalAdmissionRecord> patientsInDepartment(String departmentId) {
    return _admissions.values
        .where((a) =>
            a.departmentId == departmentId &&
            a.status == AdmissionStatus.admitted)
        .toList();
  }
}
