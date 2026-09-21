/// =============================================================
/// Lifex-AI — هوية وثقة
/// الملف: identity_trust_engine.dart
/// الحساب المسجَّل ≠ هوية موثّقة. تغيير نسبة Lifex يحتاج توقيعاً مصرّحاً.
/// =============================================================
library lifex_ai.core.identity_trust.identity_trust_engine;

import 'trust_types.dart';

class IdentityTrustEngine {
  final parties = <String, TrustParty>{};
  final grants = <SignatureGrant>[];

  void register(TrustParty party) => parties[party.id] = party;

  /// KYC لا يُرفع إلى enhanced إلا إذا كان المزود مربوطاً وأبلغ المستوى.
  bool applyKycFromProvider({
    required String partyId,
    required KycLevel level,
    required bool providerBound,
  }) {
    final p = parties[partyId];
    if (p == null) return false;
    if (!providerBound) {
      p.kycLevel = KycLevel.pending;
      p.kycProviderBound = false;
      return false;
    }
    p.kycProviderBound = true;
    p.kycLevel = level;
    return true;
  }

  void grant(SignatureGrant grant) => grants.add(grant);

  bool hasPermission(String partyId, TrustPermission permission) {
    final p = parties[partyId];
    if (p == null) return false;
    if (p.permissions.contains(permission)) return true;
    return grants.any(
      (g) => g.partyId == partyId && g.permission == permission,
    );
  }

  bool canCreatePrice(String partyId) =>
      hasPermission(partyId, TrustPermission.createPrice);

  bool canChangePlatformFee(String partyId) {
    return hasPermission(partyId, TrustPermission.changePlatformFee);
  }

  bool canReceivePayout(String partyId) {
    final p = parties[partyId];
    if (p == null) return false;
    if (!p.kycProviderBound || p.kycLevel == KycLevel.none) return false;
    return hasPermission(partyId, TrustPermission.receivePayout);
  }

  bool ssoLoginProvesIdentity(String partyId) => false;
}
