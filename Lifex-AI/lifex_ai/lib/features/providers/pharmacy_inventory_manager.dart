/// =============================================================
/// Lifex-AI — الصيدليات والمخابر
/// الملف: pharmacy_inventory_manager.dart
/// المسار: lib/features/providers/pharmacy_inventory_manager.dart
/// الوصف: إدارة مخزون الأدوية داخل صيدلية واحدة، مرتبطاً بمعرّفات
/// medications_database.json دون تكرار بيانات الدواء نفسها.
/// =============================================================
library;

class PharmacyStockItem {
  final String pharmacyId;
  final String medicationId;
  int unitsInStock;
  final int minimumSafeThreshold;

  PharmacyStockItem({
    required this.pharmacyId,
    required this.medicationId,
    required this.unitsInStock,
    this.minimumSafeThreshold = 10,
  });

  bool get isLowStock => unitsInStock < minimumSafeThreshold;
}

/// مدير مخزون الصيدلية.
class PharmacyInventoryManager {
  PharmacyInventoryManager();

  final Map<String, Map<String, PharmacyStockItem>> _stockByPharmacy = {};
  final Map<String, Map<String, String>> _barcodeToMedication = {};

  void setStock({
    required String pharmacyId,
    required String medicationId,
    required int units,
    int minSafe = 10,
  }) {
    final pharmacyStock = _stockByPharmacy.putIfAbsent(pharmacyId, () => {});
    pharmacyStock[medicationId] = PharmacyStockItem(
      pharmacyId: pharmacyId,
      medicationId: medicationId,
      unitsInStock: units,
      minimumSafeThreshold: minSafe,
    );
  }

  bool consumeUnits(String pharmacyId, String medicationId, int units) {
    final item = _stockByPharmacy[pharmacyId]?[medicationId];
    if (item == null || item.unitsInStock < units) return false;
    item.unitsInStock -= units;
    return true;
  }

  void restockUnits(String pharmacyId, String medicationId, int units) {
    final item = _stockByPharmacy[pharmacyId]?[medicationId];
    if (item != null) item.unitsInStock += units;
  }

  bool isAvailable(String pharmacyId, String medicationId) {
    final item = _stockByPharmacy[pharmacyId]?[medicationId];
    return item != null && item.unitsInStock > 0;
  }

  /// باركود يُربط بمعرّف دواء موجود. المسح الثاني لا ينشئ صنفاً ثانياً.
  String? rememberBarcode({
    required String pharmacyId,
    required String barcode,
    required String medicationId,
  }) {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty || medicationId.trim().isEmpty) return null;
    final book = _barcodeToMedication.putIfAbsent(pharmacyId, () => {});
    return book.putIfAbsent(trimmed, () => medicationId);
  }

  List<String> lowStockMedicationIds(String pharmacyId) {
    final stock = _stockByPharmacy[pharmacyId];
    if (stock == null) return [];
    return stock.values.where((i) => i.isLowStock).map((i) => i.medicationId).toList();
  }
}
