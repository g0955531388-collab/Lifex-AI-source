/// =============================================================
/// Lifex-AI — مالية
/// الملف: financial_types.dart
/// Lifex منطق فوترة وسجلات. لا يمسك أموالاً ولا يخزّن بطاقة/CVV.
/// =============================================================
library lifex_ai.core.financial.financial_types;

enum MoneyKind { invoice, purchase, transfer, donation, payout, refund }

enum InvoiceStatus {
  draft,
  issued,
  paid,
  voided,
  overdue,
}

enum SubscriptionStatus {
  trial,
  active,
  pastDue,
  paused,
  cancelled,
  expired,
}

enum PaymentStatus {
  created,
  requiresAction,
  authorized,
  processing,
  succeeded,
  failed,
  cancelled,
  refunded,
  disputed,
}

enum TransactionPhase {
  created,
  validating,
  complianceCheck,
  priced,
  authorized,
  processing,
  providerConfirmed,
  ledgerPosted,
  settled,
  failed,
  cancelled,
  refunded,
  disputed,
  blocked,
  requiresReview,
}

enum RiskReview { none, reviewRequired }

class Currency {
  const Currency({
    required this.code,
    this.numericCode = '',
    this.minorUnit = 2,
    this.symbol = '',
    this.enabled = true,
  });

  final String code;
  final String numericCode;
  final int minorUnit;
  final String symbol;
  final bool enabled;
}

class FeePolicy {
  const FeePolicy({
    required this.id,
    required this.transactionType,
    required this.version,
    this.percentage = 0,
    this.fixedMinorAmount = 0,
    this.minimumFeeMinor,
    this.maximumFeeMinor,
    this.enabled = true,
    this.donationFeePermittedByPolicy = false,
    this.effectiveFrom,
  });

  final String id;
  final String transactionType;
  final String version;
  final double percentage;
  final int fixedMinorAmount;
  final int? minimumFeeMinor;
  final int? maximumFeeMinor;
  final bool enabled;
  final bool donationFeePermittedByPolicy;
  final DateTime? effectiveFrom;

  int feeOn(int amountMinor) {
    if (!enabled) return 0;
    var fee = (amountMinor * percentage / 100).round() + fixedMinorAmount;
    if (minimumFeeMinor != null && fee < minimumFeeMinor!) fee = minimumFeeMinor!;
    if (maximumFeeMinor != null && fee > maximumFeeMinor!) fee = maximumFeeMinor!;
    return fee;
  }
}

class ConversionQuote {
  const ConversionQuote({
    required this.id,
    required this.fromCurrency,
    required this.toCurrency,
    required this.sourceAmountMinor,
    required this.destinationAmountMinor,
    required this.exchangeRate,
    required this.exchangeFeeMinor,
    required this.expiresAt,
    required this.feePolicyVersion,
  });

  final String id;
  final String fromCurrency;
  final String toCurrency;
  final int sourceAmountMinor;
  final int destinationAmountMinor;
  final double exchangeRate;
  final int exchangeFeeMinor;
  final DateTime expiresAt;
  final String feePolicyVersion;
}

class InvoiceItem {
  const InvoiceItem({
    required this.description,
    required this.amountMinor,
  });

  final String description;
  final int amountMinor;
}

class Invoice {
  const Invoice({
    required this.id,
    required this.customerId,
    required this.currency,
    required this.items,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.platformFeeMinor,
    required this.providerFeeMinor,
    required this.totalMinor,
    required this.status,
    required this.pricingVersion,
    required this.feePolicyVersion,
    this.taxJurisdiction = '',
  });

  final String id;
  final String customerId;
  final String currency;
  final List<InvoiceItem> items;
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int platformFeeMinor;
  final int providerFeeMinor;
  final int totalMinor;
  final InvoiceStatus status;
  final String pricingVersion;
  final String feePolicyVersion;
  final String taxJurisdiction;
}

class PaymentIntent {
  const PaymentIntent({
    required this.id,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.idempotencyKey,
    required this.kind,
    this.providerId = '',
    this.paymentMethodToken = '',
    this.providerReference = '',
    this.holdsFundsInLifex = false,
  });

  final String id;
  final int amountMinor;
  final String currency;
  final PaymentStatus status;
  final String idempotencyKey;
  final MoneyKind kind;
  final String providerId;
  final String paymentMethodToken;
  final String providerReference;
  final bool holdsFundsInLifex;
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.transactionId,
    required this.accountId,
    required this.debitMinor,
    required this.creditMinor,
    required this.currency,
    required this.timestamp,
    required this.description,
  });

  final String id;
  final String transactionId;
  final String accountId;
  final int debitMinor;
  final int creditMinor;
  final String currency;
  final DateTime timestamp;
  final String description;
}

class Donation {
  const Donation({
    required this.id,
    required this.campaignId,
    required this.amountMinor,
    required this.currency,
    required this.platformFeeMinor,
    required this.beneficiaryMinor,
    required this.feeDisclosed,
    required this.feeAllowed,
  });

  final String id;
  final String campaignId;
  final int amountMinor;
  final String currency;
  final int platformFeeMinor;
  final int beneficiaryMinor;
  final bool feeDisclosed;
  final bool feeAllowed;
}
