/// =============================================================
/// Lifex-AI — التبرعات الإنسانية
/// الملف: donation_type_engine.dart
/// المسار: lib/features/donations/donation_type_engine.dart
/// الوصف: تصنيف أنواع التبرع الممكنة (مالي/خدمي/عيني) وقواعد التحقق
/// الأساسية الخاصة بكل نوع.
/// =============================================================
library;

enum DonationKind { monetary, medicalService, inKindSupplies, volunteering }

class DonationTypeRequirements {
  final DonationKind kind;
  final bool requiresAmount;
  final bool requiresBeneficiaryVerification;

  const DonationTypeRequirements({
    required this.kind,
    required this.requiresAmount,
    required this.requiresBeneficiaryVerification,
  });
}

/// خريطة متطلبات كل نوع تبرع — صريحة وثابتة لسهولة المراجعة.
const Map<DonationKind, DonationTypeRequirements> _requirementsByKind = {
  DonationKind.monetary: DonationTypeRequirements(
    kind: DonationKind.monetary,
    requiresAmount: true,
    requiresBeneficiaryVerification: true,
  ),
  DonationKind.medicalService: DonationTypeRequirements(
    kind: DonationKind.medicalService,
    requiresAmount: false,
    requiresBeneficiaryVerification: true,
  ),
  DonationKind.inKindSupplies: DonationTypeRequirements(
    kind: DonationKind.inKindSupplies,
    requiresAmount: false,
    requiresBeneficiaryVerification: true,
  ),
  DonationKind.volunteering: DonationTypeRequirements(
    kind: DonationKind.volunteering,
    requiresAmount: false,
    requiresBeneficiaryVerification: false,
  ),
};

/// محرك أنواع التبرع.
class DonationTypeEngine {
  DonationTypeEngine();

  DonationTypeRequirements requirementsFor(DonationKind kind) =>
      _requirementsByKind[kind]!;

  bool isValidPledge({
    required DonationKind kind,
    double? amount,
  }) {
    final requirements = requirementsFor(kind);
    if (requirements.requiresAmount && (amount == null || amount <= 0)) {
      return false;
    }
    return true;
  }
}
