/// =============================================================
/// Lifex-AI — شبكة التبرع بالدم
/// الملف: donor_history_registry.dart
/// المسار: lib/features/blood_network/donor_history_registry.dart
/// الوصف: سجل تاريخ تبرعات كل شخص بالدم — يُستخدم لتحديد الأهلية
/// (الفاصل الزمني الآمن) ولإظهار "شارات" تقدير للمتبرعين المنتظمين.
/// =============================================================
library;

class BloodDonationRecord {
  final String donorLifexId;
  final DateTime donatedAt;
  final String? hospitalId;

  const BloodDonationRecord({
    required this.donorLifexId,
    required this.donatedAt,
    this.hospitalId,
  });
}

/// سجل تاريخ التبرع بالدم.
class DonorHistoryRegistry {
  DonorHistoryRegistry();

  final Map<String, List<BloodDonationRecord>> _historyByDonor = {};

  void recordDonation(BloodDonationRecord record) {
    _historyByDonor.putIfAbsent(record.donorLifexId, () => []).add(record);
  }

  DateTime? lastDonationDateFor(String donorLifexId) {
    final history = _historyByDonor[donorLifexId];
    if (history == null || history.isEmpty) return null;
    return history
        .map((r) => r.donatedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  int totalDonationsCountFor(String donorLifexId) {
    return _historyByDonor[donorLifexId]?.length ?? 0;
  }

  List<BloodDonationRecord> historyFor(String donorLifexId) =>
      List.unmodifiable(_historyByDonor[donorLifexId] ?? const []);
}
