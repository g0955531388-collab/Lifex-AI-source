/// =============================================================
/// Lifex-AI — وحدة المستشفيات
/// الملف: hospital_blood_bank.dart
/// المسار: lib/features/hospital/hospital_blood_bank.dart
/// الوصف: إدارة مخزون بنك الدم الداخلي للمستشفى، وربطه اختيارياً بشبكة
/// التبرع بالدم الخارجية (blood_request_engine.dart) عند نقص المخزون.
/// =============================================================
library;

enum BloodTypeSimple { aPositive, aNegative, bPositive, bNegative, abPositive, abNegative, oPositive, oNegative }

class BloodBankInventoryItem {
  final BloodTypeSimple bloodType;
  int unitsAvailable;
  final int minimumSafeThreshold;

  BloodBankInventoryItem({
    required this.bloodType,
    required this.unitsAvailable,
    this.minimumSafeThreshold = 5,
  });

  bool get isBelowSafeThreshold => unitsAvailable < minimumSafeThreshold;
}

/// مدير بنك الدم الداخلي للمستشفى.
class HospitalBloodBank {
  HospitalBloodBank({required this.hospitalId});

  final String hospitalId;
  final Map<BloodTypeSimple, BloodBankInventoryItem> _inventory = {};

  void setInitialStock(BloodTypeSimple type, int units, {int minSafe = 5}) {
    _inventory[type] = BloodBankInventoryItem(
      bloodType: type,
      unitsAvailable: units,
      minimumSafeThreshold: minSafe,
    );
  }

  bool consumeUnits(BloodTypeSimple type, int units) {
    final item = _inventory[type];
    if (item == null || item.unitsAvailable < units) return false;
    item.unitsAvailable -= units;
    return true;
  }

  void addDonatedUnits(BloodTypeSimple type, int units) {
    final item = _inventory[type];
    if (item == null) {
      setInitialStock(type, units);
    } else {
      item.unitsAvailable += units;
    }
  }

  /// أنواع الدم التي وصلت لمستوى حرج ويجب طلب تبرعات إضافية لها عبر
  /// شبكة التبرع بالدم الخارجية.
  List<BloodTypeSimple> typesNeedingUrgentDonation() {
    return _inventory.values
        .where((item) => item.isBelowSafeThreshold)
        .map((item) => item.bloodType)
        .toList();
  }

  BloodBankInventoryItem? statusOf(BloodTypeSimple type) => _inventory[type];
}
