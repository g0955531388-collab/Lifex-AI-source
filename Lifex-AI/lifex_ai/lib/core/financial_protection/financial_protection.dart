/// =============================================================
/// Lifex-AI — حماية مالية
/// الملف: financial_protection.dart
/// المراجعة ≠ إدانة. الحظر قبل المزود والدفتر. KYC/AML عبر مزود مرخّص.
/// =============================================================
library lifex_ai.core.financial_protection.financial_protection;

import '../financial/financial_types.dart';
import '../identity_trust/identity_trust_engine.dart';
import '../identity_trust/trust_types.dart';

enum ProtectionDecision {
  allow,
  stepUpAuthentication,
  reviewRequired,
  hold,
  block,
}

enum AccountSecurityStatus {
  active,
  restricted,
  stepUpRequired,
  underReview,
  frozen,
  closed,
}

enum SanctionsOutcome {
  clear,
  possibleMatch,
  confirmedMatch,
  requiresReview,
  providerUnavailable,
}

class ProtectionResult {
  const ProtectionResult({
    required this.decision,
    required this.reason,
    this.guilty = false,
  });

  final ProtectionDecision decision;
  final String reason;
  final bool guilty;
}

class VelocityWindow {
  const VelocityWindow({
    this.maxAttempts = 5,
    this.maxAmountMinor = 1000000,
    this.window = const Duration(hours: 24),
  });

  final int maxAttempts;
  final int maxAmountMinor;
  final Duration window;
}

class FinancialProtectionEngine {
  FinancialProtectionEngine({
    IdentityTrustEngine? trust,
    this.velocity = const VelocityWindow(),
    this.largeAmountMinor = 500000,
    this.sanctionsPartyIds = const {},
    this.amlProviderBound = false,
  }) : trust = trust ?? IdentityTrustEngine();

  final IdentityTrustEngine trust;
  final VelocityWindow velocity;
  final int largeAmountMinor;
  final Set<String> sanctionsPartyIds;
  final bool amlProviderBound;
  final _attempts = <String, List<DateTime>>{};
  final _failed = <String, int>{};
  final frozen = <String>{};
  final freezeReasons = <String, String>{};

  bool freeze(String accountId, String reason) {
    if (accountId.isEmpty || reason.isEmpty) return false;
    frozen.add(accountId);
    freezeReasons[accountId] = reason;
    return true;
  }

  bool unfreeze(String accountId, String authorizationId) {
    if (authorizationId.isEmpty) return false;
    frozen.remove(accountId);
    freezeReasons.remove(accountId);
    return true;
  }

  AccountSecurityStatus statusOf(String partyId) {
    if (frozen.contains(partyId)) return AccountSecurityStatus.frozen;
    return AccountSecurityStatus.active;
  }

  /// مزود العقوبات غير مربوط ≠ clear.
  SanctionsOutcome screenSanctions(String partyId, {required bool providerBound}) {
    if (!providerBound) return SanctionsOutcome.providerUnavailable;
    if (sanctionsPartyIds.contains(partyId)) {
      return SanctionsOutcome.confirmedMatch;
    }
    return SanctionsOutcome.clear;
  }

  ProtectionResult screen({
    required String partyId,
    required int amountMinor,
    required MoneyKind kind,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    if (frozen.contains(partyId)) {
      return const ProtectionResult(
        decision: ProtectionDecision.block,
        reason: 'account_frozen',
        guilty: false,
      );
    }
    if (!amlProviderBound) {
      final sanctions = screenSanctions(partyId, providerBound: false);
      if (sanctions == SanctionsOutcome.providerUnavailable &&
          amountMinor >= largeAmountMinor) {
        return const ProtectionResult(
          decision: ProtectionDecision.reviewRequired,
          reason: 'sanctions_provider_unavailable',
          guilty: false,
        );
      }
    }
    if (sanctionsPartyIds.contains(partyId)) {
      return const ProtectionResult(
        decision: ProtectionDecision.block,
        reason: 'sanctions_policy_hit',
        guilty: false,
      );
    }
    final party = trust.parties[partyId];
    if (party == null) {
      return const ProtectionResult(
        decision: ProtectionDecision.reviewRequired,
        reason: 'unknown_party',
        guilty: false,
      );
    }
    if (kind == MoneyKind.payout && !trust.canReceivePayout(partyId)) {
      return const ProtectionResult(
        decision: ProtectionDecision.block,
        reason: 'payout_kyc_or_permission_missing',
        guilty: false,
      );
    }
    if (!amlProviderBound &&
        party.kycLevel == KycLevel.none &&
        amountMinor >= largeAmountMinor) {
      return const ProtectionResult(
        decision: ProtectionDecision.reviewRequired,
        reason: 'aml_provider_unbound_large_amount',
        guilty: false,
      );
    }
    if (party.kycLevel == KycLevel.none && amountMinor >= largeAmountMinor) {
      return const ProtectionResult(
        decision: ProtectionDecision.reviewRequired,
        reason: 'new_or_unverified_large_amount',
        guilty: false,
      );
    }
    final stamps = (_attempts[partyId] ?? [])
        .where((d) => t.difference(d) < velocity.window)
        .toList();
    if (stamps.length >= velocity.maxAttempts) {
      return const ProtectionResult(
        decision: ProtectionDecision.block,
        reason: 'velocity_attempts_exceeded',
        guilty: false,
      );
    }
    _attempts[partyId] = [...stamps, t];
    if ((_failed[partyId] ?? 0) >= 3 && amountMinor >= largeAmountMinor) {
      return const ProtectionResult(
        decision: ProtectionDecision.reviewRequired,
        reason: 'repeated_failures_plus_large_amount',
        guilty: false,
      );
    }
    return const ProtectionResult(
      decision: ProtectionDecision.allow,
      reason: 'passed_gates',
      guilty: false,
    );
  }

  void noteFailure(String partyId) {
    _failed[partyId] = (_failed[partyId] ?? 0) + 1;
  }
}
