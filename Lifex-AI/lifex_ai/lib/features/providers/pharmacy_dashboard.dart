/// =============================================================
/// Lifex-AI — الصيدليات والمخابر
/// الملف: pharmacy_dashboard.dart
/// المسار: lib/features/providers/pharmacy_dashboard.dart
/// الوصف: مجمّع بيانات لوحة تحكم الصيدلية — طلبات الوصفات المعلّقة
/// ومستوى المخزون الحرج، دون تكرار منطق الملفات الأخرى.
/// =============================================================
library;

import 'pharmacy_inventory_manager.dart';
import 'prescription_link_engine.dart';

class PharmacyDashboardSummary {
  final int pendingPrescriptionsCount;
  final List<String> lowStockMedicationIds;

  const PharmacyDashboardSummary({
    required this.pendingPrescriptionsCount,
    required this.lowStockMedicationIds,
  });
}

class PharmacyDashboard {
  PharmacyDashboard({
    required this.inventoryManager,
    required this.prescriptionEngine,
  });

  final PharmacyInventoryManager inventoryManager;
  final PrescriptionLinkEngine prescriptionEngine;

  PharmacyDashboardSummary buildSummary(String pharmacyId) {
    final pending = prescriptionEngine.pendingRequestsFor(pharmacyId).length;
    final lowStock = inventoryManager.lowStockMedicationIds(pharmacyId);

    return PharmacyDashboardSummary(
      pendingPrescriptionsCount: pending,
      lowStockMedicationIds: lowStock,
    );
  }
}
