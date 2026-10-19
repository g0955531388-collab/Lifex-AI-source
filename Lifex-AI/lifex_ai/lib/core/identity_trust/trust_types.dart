/// =============================================================
/// Lifex-AI — هوية وثقة
/// الملف: trust_types.dart
/// الدور ليس دليلاً قانونياً. KYC من مزود مرخّص وليس اختراعاً داخلياً.
/// =============================================================
library lifex_ai.core.identity_trust.trust_types;

enum PartyKind {
  user,
  organization,
  beneficiary,
  merchant,
  physician,
  laboratory,
  hospital,
  financialAdmin,
}

enum KycLevel {
  none,
  pending,
  basic,
  enhanced,
  rejected,
}

enum TrustPermission {
  pay,
  receivePayout,
  donate,
  createPrice,
  changePlatformFee,
  signOrganization,
  manageLinkedAccounts,
}

class TrustParty {
  TrustParty({
    required this.id,
    required this.kind,
    this.displayName = '',
    this.kycLevel = KycLevel.none,
    this.kycProviderBound = false,
    this.permissions = const {},
    this.organizationId,
    this.linkedAccountIds = const [],
  });

  final String id;
  final PartyKind kind;
  final String displayName;
  KycLevel kycLevel;
  bool kycProviderBound;
  Set<TrustPermission> permissions;
  String? organizationId;
  List<String> linkedAccountIds;
}

class SignatureGrant {
  const SignatureGrant({
    required this.partyId,
    required this.organizationId,
    required this.permission,
  });

  final String partyId;
  final String organizationId;
  final TrustPermission permission;
}
