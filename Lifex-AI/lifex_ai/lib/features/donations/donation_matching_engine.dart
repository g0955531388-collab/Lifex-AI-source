/// =============================================================
/// Lifex-AI — التبرعات الإنسانية
/// الملف: donation_matching_engine.dart
/// المسار: lib/features/donations/donation_matching_engine.dart
/// الوصف: مطابقة التبرعات المعلَّقة بالمستفيدين المؤهَّلين (بعد التحقق)،
/// بقواعد أولوية بسيطة وشفافة.
/// =============================================================
library;

import 'donation_manager.dart';
import 'donation_type_engine.dart';
import 'special_needs_beneficiary_registry.dart';

class MatchResult {
  final bool matched;
  final String? donationId;
  final String? beneficiaryId;

  const MatchResult({required this.matched, this.donationId, this.beneficiaryId});
}

/// محرك مطابقة التبرعات بالمستفيدين — قائم على قواعد بسيطة (أول تبرع
/// معلَّق يُطابق أول مستفيد مؤهل بنفس نوع الحاجة) وليس نموذجاً معقداً.
class DonationMatchingEngine {
  DonationMatchingEngine({
    required this.donationManager,
    required this.beneficiaryRegistry,
  });

  final DonationManager donationManager;
  final SpecialNeedsBeneficiaryRegistry beneficiaryRegistry;

  /// محاولة مطابقة أقدم تبرع معلَّق من نوع معيّن مع أول مستفيد مؤهل.
  MatchResult attemptMatch(DonationKind kind) {
    final pledgedDonations = donationManager.pledgedDonationsByKind(kind);
    final verifiedBeneficiaries = beneficiaryRegistry.verifiedBeneficiaries();

    if (pledgedDonations.isEmpty || verifiedBeneficiaries.isEmpty) {
      return const MatchResult(matched: false);
    }

    final donation = pledgedDonations.first;
    final beneficiary = verifiedBeneficiaries.first;

    final success = donationManager.matchToBeneficiary(
      donation.donationId,
      beneficiary.beneficiaryId,
    );

    return MatchResult(
      matched: success,
      donationId: donation.donationId,
      beneficiaryId: beneficiary.beneficiaryId,
    );
  }
}
