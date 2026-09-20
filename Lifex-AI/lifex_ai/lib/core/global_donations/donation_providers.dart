/// =============================================================
/// Lifex-AI — مزود دفع افتراضي للتبرعات (اختبار)
/// ليس مصرفاً. لا بطاقة. النجاح فقط إن كان المزود مرخّصاً وWebhook صحيحاً.
/// =============================================================
library lifex_ai.core.global_donations.donation_providers;
import '../financial/financial_types.dart';
import '../financial/payment_provider.dart';

class VirtualLicensedDonationProvider implements PaymentProvider {
  @override
  String get providerId => 'virtual_donation';

  @override
  bool get licensedBound => true;

  @override
  Future<PaymentIntent> createPayment(PaymentIntent draft) async {
    return PaymentIntent(
      id: draft.id,
      amountMinor: draft.amountMinor,
      currency: draft.currency,
      status: PaymentStatus.processing,
      idempotencyKey: draft.idempotencyKey,
      kind: draft.kind,
      providerId: providerId,
      paymentMethodToken: draft.paymentMethodToken,
      holdsFundsInLifex: false,
    );
  }

  @override
  Future<PaymentStatus> getPaymentStatus(String paymentId) async {
    return PaymentStatus.processing;
  }

  @override
  bool verifyWebhook({required String payload, required String signature}) {
    return signature == 'virt-ok';
  }
}

abstract class DonationPaymentAdapter {
  Future<PaymentIntent> createPayment({
    required int amountMinor,
    required String currency,
    required String idempotencyKey,
    required String partyId,
  });

  PaymentStatus confirmWebhook({
    required String paymentId,
    required String payload,
    required String signature,
  });
}
