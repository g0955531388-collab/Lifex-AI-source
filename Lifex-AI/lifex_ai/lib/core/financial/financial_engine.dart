/// =============================================================
/// Lifex-AI — مالية
/// الملف: financial_engine.dart
/// فوترة وعمولات ودفتر. الحركة النقدية عبر مزود مرخّص فقط.
/// =============================================================
library lifex_ai.core.financial.financial_engine;

import '../financial_protection/financial_protection.dart';
import '../identity_trust/identity_trust_engine.dart';
import 'double_entry_ledger.dart';
import 'financial_types.dart';
import 'payment_provider.dart';

class LifexFinancialEngine {
  LifexFinancialEngine({
    PaymentProvider? provider,
    DoubleEntryLedger? ledger,
    FeePolicy? platformFee,
    FeePolicy? exchangeFee,
    FeePolicy? donationFee,
    this.pricingVersion = 'v1',
    this.trust,
    this.protection,
  })  : provider = provider ?? UnboundPaymentProvider(),
        ledger = ledger ?? DoubleEntryLedger(),
        platformFee = platformFee ??
            const FeePolicy(
              id: 'plat',
              transactionType: 'payment',
              version: 'v1',
              percentage: 2,
              fixedMinorAmount: 0,
            ),
        exchangeFee = exchangeFee ??
            const FeePolicy(
              id: 'fx',
              transactionType: 'exchange',
              version: 'v1',
              percentage: 1,
            ),
        donationFee = donationFee ??
            const FeePolicy(
              id: 'don',
              transactionType: 'donation',
              version: 'v1',
              percentage: 0,
              donationFeePermittedByPolicy: false,
            );

  final PaymentProvider provider;
  final DoubleEntryLedger ledger;
  final IdentityTrustEngine? trust;
  final FinancialProtectionEngine? protection;
  FeePolicy platformFee;
  FeePolicy exchangeFee;
  FeePolicy donationFee;
  String pricingVersion;

  final currencies = <String, Currency>{
    'USD': const Currency(code: 'USD', minorUnit: 2, symbol: r'$'),
    'SAR': const Currency(code: 'SAR', minorUnit: 2),
    'EUR': const Currency(code: 'EUR', minorUnit: 2),
    'TRY': const Currency(code: 'TRY', minorUnit: 2),
  };

  final _intents = <String, PaymentIntent>{};
  final _byIdempotency = <String, PaymentIntent>{};
  final policyHistory = <FeePolicy>[];

  bool publishFeePolicy(FeePolicy next, {String? actorId}) {
    if (trust != null) {
      if (actorId == null ||
          !trust!.canChangePlatformFee(actorId)) {
        return false;
      }
    }
    policyHistory.add(platformFee);
    platformFee = next;
    return true;
  }

  bool createPrice({required String actorId, required String planId}) {
    return trust?.canCreatePrice(actorId) ?? false;
  }

  Invoice createInvoice({
    required String customerId,
    required List<InvoiceItem> items,
    required String currency,
    int discountMinor = 0,
    String taxJurisdiction = '',
    int taxMinor = 0,
  }) {
    final sub = items.fold<int>(0, (a, i) => a + i.amountMinor);
    final afterDiscount = (sub - discountMinor).clamp(0, sub);
    final fee = platformFee.feeOn(afterDiscount);
    final total = afterDiscount + taxMinor;
    return Invoice(
      id: 'inv_${DateTime.now().microsecondsSinceEpoch}',
      customerId: customerId,
      currency: currency,
      items: items,
      subtotalMinor: sub,
      discountMinor: discountMinor,
      taxMinor: taxMinor,
      platformFeeMinor: fee,
      providerFeeMinor: 0,
      totalMinor: total,
      status: InvoiceStatus.issued,
      pricingVersion: pricingVersion,
      feePolicyVersion: platformFee.version,
      taxJurisdiction: taxJurisdiction,
    );
  }

  ConversionQuote quoteExchange({
    required String from,
    required String to,
    required int sourceAmountMinor,
    required double marketRate,
    required DateTime now,
  }) {
    final fee = exchangeFee.feeOn(sourceAmountMinor);
    final net = sourceAmountMinor - fee;
    final dest = (net * marketRate).round();
    return ConversionQuote(
      id: 'q_${now.microsecondsSinceEpoch}',
      fromCurrency: from,
      toCurrency: to,
      sourceAmountMinor: sourceAmountMinor,
      destinationAmountMinor: dest,
      exchangeRate: marketRate,
      exchangeFeeMinor: fee,
      expiresAt: now.add(const Duration(minutes: 2)),
      feePolicyVersion: exchangeFee.version,
    );
  }

  Future<PaymentIntent> createPayment({
    required int amountMinor,
    required String currency,
    required String idempotencyKey,
    required MoneyKind kind,
    String paymentMethodToken = '',
    RiskReview review = RiskReview.none,
    String? partyId,
  }) async {
    if (amountMinor <= 0) {
      return PaymentIntent(
        id: 'bad',
        amountMinor: amountMinor,
        currency: currency,
        status: PaymentStatus.failed,
        idempotencyKey: idempotencyKey,
        kind: kind,
      );
    }
    if (paymentMethodToken.contains('cvv') ||
        paymentMethodToken.replaceAll(' ', '').length == 16) {
      return PaymentIntent(
        id: 'pci',
        amountMinor: amountMinor,
        currency: currency,
        status: PaymentStatus.failed,
        idempotencyKey: idempotencyKey,
        kind: kind,
      );
    }
    final existing = _byIdempotency[idempotencyKey];
    if (existing != null) return existing;
    if (protection != null && partyId != null) {
      final gate = protection!.screen(
        partyId: partyId,
        amountMinor: amountMinor,
        kind: kind,
      );
      if (gate.decision == ProtectionDecision.block) {
        return PaymentIntent(
          id: 'blocked_$idempotencyKey',
          amountMinor: amountMinor,
          currency: currency,
          status: PaymentStatus.failed,
          idempotencyKey: idempotencyKey,
          kind: kind,
        );
      }
      if (gate.decision == ProtectionDecision.reviewRequired ||
          gate.decision == ProtectionDecision.stepUpAuthentication ||
          gate.decision == ProtectionDecision.hold) {
        review = RiskReview.reviewRequired;
      }
    }
    if (review == RiskReview.reviewRequired) {
      final blocked = PaymentIntent(
        id: 'rev_$idempotencyKey',
        amountMinor: amountMinor,
        currency: currency,
        status: PaymentStatus.created,
        idempotencyKey: idempotencyKey,
        kind: kind,
        providerId: provider.providerId,
      );
      _byIdempotency[idempotencyKey] = blocked;
      return blocked;
    }
    final draft = PaymentIntent(
      id: 'pi_$idempotencyKey',
      amountMinor: amountMinor,
      currency: currency,
      status: PaymentStatus.created,
      idempotencyKey: idempotencyKey,
      kind: kind,
      paymentMethodToken: paymentMethodToken,
    );
    final created = await provider.createPayment(draft);
    _intents[created.id] = created;
    _byIdempotency[idempotencyKey] = created;
    return created;
  }

  PaymentStatus applyWebhook({
    required String paymentId,
    required PaymentStatus claimed,
    required String payload,
    required String signature,
  }) {
    if (!provider.verifyWebhook(payload: payload, signature: signature)) {
      return PaymentStatus.failed;
    }
    final current = _intents[paymentId];
    if (current == null) return PaymentStatus.failed;
    if (claimed == PaymentStatus.succeeded && provider.licensedBound) {
      final fee = platformFee.feeOn(current.amountMinor);
      ledger.postBalanced(
        transactionId: paymentId,
        currency: current.currency,
        amountMinor: current.amountMinor,
        platformFeeMinor: fee,
        clearingAccount: 'PaymentClearing',
        payableAccount: 'MerchantPayable',
        revenueAccount: 'LIFEX_PLATFORM_REVENUE',
      );
      _intents[paymentId] = PaymentIntent(
        id: current.id,
        amountMinor: current.amountMinor,
        currency: current.currency,
        status: PaymentStatus.succeeded,
        idempotencyKey: current.idempotencyKey,
        kind: current.kind,
        providerId: current.providerId,
        providerReference: current.providerReference,
      );
      return PaymentStatus.succeeded;
    }
    return current.status;
  }

  Donation createDonation({
    required String campaignId,
    required int amountMinor,
    required String currency,
    required bool feeDisclosedToDonor,
  }) {
    final allowed = donationFee.enabled &&
        donationFee.donationFeePermittedByPolicy &&
        feeDisclosedToDonor;
    final fee = allowed ? donationFee.feeOn(amountMinor) : 0;
    return Donation(
      id: 'don_$campaignId',
      campaignId: campaignId,
      amountMinor: amountMinor,
      currency: currency,
      platformFeeMinor: fee,
      beneficiaryMinor: amountMinor - fee,
      feeDisclosed: feeDisclosedToDonor,
      feeAllowed: allowed,
    );
  }

  bool appClaimsSuccessWithoutProvider(PaymentIntent intent) {
    return intent.status == PaymentStatus.succeeded && !provider.licensedBound;
  }
}
