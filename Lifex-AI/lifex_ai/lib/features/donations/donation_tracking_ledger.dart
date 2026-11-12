/// =============================================================
/// Lifex-AI — التبرعات الإنسانية
/// الملف: donation_tracking_ledger.dart
/// المسار: lib/features/donations/donation_tracking_ledger.dart
/// الوصف: سجل شفاف (Ledger) لكل خطوة في رحلة التبرع، ليتمكن المتبرع من
/// رؤية أثر تبرعه دون كشف هوية المستفيد الكاملة.
/// =============================================================
library;

enum LedgerEventType { pledged, matched, fulfilled, cancelled }

class LedgerEntry {
  final String donationId;
  final LedgerEventType eventType;
  final DateTime timestamp;
  final String descriptionAr;

  LedgerEntry({
    required this.donationId,
    required this.eventType,
    required this.descriptionAr,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// سجل تتبّع شفاف لكل تبرع.
class DonationTrackingLedger {
  DonationTrackingLedger();

  final Map<String, List<LedgerEntry>> _ledgerByDonation = {};

  void recordEvent({
    required String donationId,
    required LedgerEventType eventType,
    required String descriptionAr,
  }) {
    _ledgerByDonation.putIfAbsent(donationId, () => []).add(
          LedgerEntry(
            donationId: donationId,
            eventType: eventType,
            descriptionAr: descriptionAr,
          ),
        );
  }

  List<LedgerEntry> historyFor(String donationId) =>
      List.unmodifiable(_ledgerByDonation[donationId] ?? const []);
}
