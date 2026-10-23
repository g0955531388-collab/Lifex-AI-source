/// =============================================================
/// Lifex-AI — التبرعات الإنسانية
/// الملف: donation_manager.dart
/// المسار: lib/features/donations/donation_manager.dart
/// الوصف: المدير المركزي لحملات ودورة حياة التبرعات — ينسّق بين نوع
/// التبرع، التحقق من المستفيد، والمطابقة.
/// =============================================================
library;

import 'donation_type_engine.dart';

enum DonationStatus { pledged, matched, fulfilled, cancelled }

class Donation {
  final String donationId;
  final String donorLifexId;
  final DonationKind kind;
  final double? monetaryAmount;
  DonationStatus status;
  String? matchedBeneficiaryId;

  Donation({
    required this.donationId,
    required this.donorLifexId,
    required this.kind,
    this.monetaryAmount,
    this.status = DonationStatus.pledged,
    this.matchedBeneficiaryId,
  });
}

/// المدير المركزي للتبرعات.
class DonationManager {
  DonationManager();

  final Map<String, Donation> _donations = {};
  int _counter = 0;

  Donation pledgeDonation({
    required String donorLifexId,
    required DonationKind kind,
    double? monetaryAmount,
  }) {
    _counter++;
    final donation = Donation(
      donationId: 'DON-$_counter',
      donorLifexId: donorLifexId,
      kind: kind,
      monetaryAmount: monetaryAmount,
    );
    _donations[donation.donationId] = donation;
    return donation;
  }

  bool matchToBeneficiary(String donationId, String beneficiaryId) {
    final donation = _donations[donationId];
    if (donation == null || donation.status != DonationStatus.pledged) {
      return false;
    }
    donation.status = DonationStatus.matched;
    donation.matchedBeneficiaryId = beneficiaryId;
    return true;
  }

  bool markFulfilled(String donationId) {
    final donation = _donations[donationId];
    if (donation == null || donation.status != DonationStatus.matched) {
      return false;
    }
    donation.status = DonationStatus.fulfilled;
    return true;
  }

  List<Donation> pledgedDonationsByKind(DonationKind kind) {
    return _donations.values
        .where((d) => d.kind == kind && d.status == DonationStatus.pledged)
        .toList();
  }

  List<Donation> donationsByDonor(String donorLifexId) {
    return _donations.values.where((d) => d.donorLifexId == donorLifexId).toList();
  }
}
