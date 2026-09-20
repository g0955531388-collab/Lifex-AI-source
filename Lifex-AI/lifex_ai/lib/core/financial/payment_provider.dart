/// =============================================================
/// Lifex-AI — مالية
/// الملف: payment_provider.dart
/// مزود غير مربوط لا يؤكد نجاحاً. لا بطاقة خام.
/// =============================================================
library lifex_ai.core.financial.payment_provider;

import 'financial_types.dart';

abstract class PaymentProvider {
  String get providerId;
  bool get licensedBound;

  Future<PaymentIntent> createPayment(PaymentIntent draft);

  Future<PaymentStatus> getPaymentStatus(String paymentId);

  bool verifyWebhook({required String payload, required String signature});
}

class UnboundPaymentProvider implements PaymentProvider {
  @override
  String get providerId => 'unbound';

  @override
  bool get licensedBound => false;

  @override
  Future<PaymentIntent> createPayment(PaymentIntent draft) async {
    return PaymentIntent(
      id: draft.id,
      amountMinor: draft.amountMinor,
      currency: draft.currency,
      status: PaymentStatus.requiresAction,
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
    return false;
  }
}
