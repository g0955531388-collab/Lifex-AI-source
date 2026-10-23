/// =============================================================
/// Lifex-AI — وحدة المستشفيات
/// الملف: hospital_equipment_manager.dart
/// المسار: lib/features/hospital/hospital_equipment_manager.dart
/// الوصف: تتبّع الأجهزة الطبية داخل المستشفى وحالتها التشغيلية وجداول
/// الصيانة الدورية.
/// =============================================================
library;

enum EquipmentStatus { operational, underMaintenance, outOfService }

class MedicalEquipmentItem {
  final String equipmentId;
  final String hospitalId;
  final String nameAr;
  EquipmentStatus status;
  DateTime? lastMaintenanceAt;
  DateTime? nextMaintenanceDueAt;

  MedicalEquipmentItem({
    required this.equipmentId,
    required this.hospitalId,
    required this.nameAr,
    this.status = EquipmentStatus.operational,
    this.lastMaintenanceAt,
    this.nextMaintenanceDueAt,
  });
}

/// مدير الأجهزة الطبية.
class HospitalEquipmentManager {
  HospitalEquipmentManager();

  final Map<String, MedicalEquipmentItem> _equipment = {};

  void registerEquipment(MedicalEquipmentItem item) {
    _equipment[item.equipmentId] = item;
  }

  void markUnderMaintenance(String equipmentId) {
    _equipment[equipmentId]?.status = EquipmentStatus.underMaintenance;
  }

  void markOperational(String equipmentId, {DateTime? maintenanceCompletedAt}) {
    final item = _equipment[equipmentId];
    if (item == null) return;
    item.status = EquipmentStatus.operational;
    item.lastMaintenanceAt = maintenanceCompletedAt ?? DateTime.now();
  }

  void markOutOfService(String equipmentId) {
    _equipment[equipmentId]?.status = EquipmentStatus.outOfService;
  }

  List<MedicalEquipmentItem> equipmentDueForMaintenance(String hospitalId) {
    final now = DateTime.now();
    return _equipment.values
        .where((e) =>
            e.hospitalId == hospitalId &&
            e.nextMaintenanceDueAt != null &&
            e.nextMaintenanceDueAt!.isBefore(now))
        .toList();
  }

  List<MedicalEquipmentItem> operationalEquipmentFor(String hospitalId) {
    return _equipment.values
        .where((e) =>
            e.hospitalId == hospitalId &&
            e.status == EquipmentStatus.operational)
        .toList();
  }
}
