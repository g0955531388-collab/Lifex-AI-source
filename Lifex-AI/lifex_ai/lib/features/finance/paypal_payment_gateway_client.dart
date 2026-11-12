/// =============================================================
/// Lifex-AI — المعاملات المالية
/// الملف: paypal_payment_gateway_client.dart
/// المسار: lib/features/finance/paypal_payment_gateway_client.dart
/// الوصف: تنفيذ PaymentGatewayClient عبر PayPal — هذا هو مزوّد الدفع
/// المعتمد فعلياً في المنظومة حسب توجيه صريح، وليس بديلاً اختيارياً عن
/// Stripe؛ SubscriptionBillingManager يختار من بين البوابات المسجَّلة
/// (Stripe/PayPal/غيرها لاحقاً) حسب ما هو متاح فعلياً في بلد المستخدم.
/// هيكل فقط حتى الآن — يتطلب ربط SDK حقيقي (paypal_payment أو REST API
/// مباشر لـ PayPal Checkout/Orders v2) واعتماد حساب PayPal تجاري حقيقي
/// للمشروع قبل قبول أي دفعة فعلية.
/// =============================================================
library lifex_ai.features.finance.paypal_payment_gateway_client;

import 'payment_gateway_client.dart';

class PayPalPaymentGatewayClient implements PaymentGatewayClient {
  PayPalPaymentGatewayClient({required this.clientId});

  final String clientId;

  @override
  String get gatewayName => 'PayPal';

  bool get isConfigured {
    final id = clientId.trim();
    return id.isNotEmpty && !id.toLowerCase().contains('placeholder');
  }

  bool get isAvailable => isConfigured;

  @override
  Future<PaymentResult> chargeAmount({
    required int amountInSmallestUnit,
    required String currencyCode,
    required String description,
    String? idempotencyKey,
  }) async {
    if (!isConfigured) {
      return const PaymentResult(
        status: PaymentStatus.failed,
        environment: FinancialEnvironment.production,
        isSandbox: false,
        errorMessageAr:
            'PayPal غير موصول بمعرّف عميل صالح. لا حركة أموال حقيقية.',
      );
    }
    return const PaymentResult(
      status: PaymentStatus.failed,
      environment: FinancialEnvironment.production,
      isSandbox: false,
      errorMessageAr:
          'واجهة PayPal Orders غير مربوطة في هذا البناء. لا حركة أموال حقيقية.',
    );
  }

  @override
  Future<PaymentResult> refund({
    required String gatewayTransactionId,
    int? partialAmountInSmallestUnit,
  }) async {
    return const PaymentResult(
      status: PaymentStatus.failed,
      environment: FinancialEnvironment.production,
      isSandbox: false,
      errorMessageAr: 'بوابة PayPal غير مُفعَّلة بعد.',
    );
  }
}
