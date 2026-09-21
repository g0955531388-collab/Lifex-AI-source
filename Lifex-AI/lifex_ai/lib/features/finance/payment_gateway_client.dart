/// =============================================================
/// Lifex-AI — المعاملات المالية
/// الملف: payment_gateway_client.dart
/// المسار: lib/features/finance/payment_gateway_client.dart
/// الوصف: عقد مجرَّد لأي بوابة دفع مرخّصة خارجية (Stripe/PayPal).
///
/// ⚠️ حد فاصل مهم جداً بالنسبة لملكية المشروع: Lifex-AI **لا يلمس أي
/// أموال حقيقية مباشرة أبداً**. كل عملية دفع فعلية (بطاقة ائتمان، حساب
/// بنكي) تمر بالكامل عبر SDK البوابة المرخّصة نفسها (Stripe/PayPal)،
/// وتطبيقنا يستقبل فقط "تأكيد نجاح/فشل" من البوابة، ولا يخزّن أبداً أي
/// بيانات بطاقة ائتمان خام. هذا يبقينا خارج نطاق متطلبات PCI-DSS
/// المعقدة، وخارج نطاق الحاجة لترخيص مؤسسة تحويل أموال.
/// =============================================================

enum PaymentStatus {
  created,
  requiresPaymentMethod,
  requiresAuthentication,
  pending,
  processing,
  succeeded,
  failed,
  cancelled,
  refunded,
}

/// بيئة التنفيذ المالي — لا تخلط Sandbox بإنتاج حقيقي.
enum FinancialEnvironment {
  development,
  test,
  staging,
  sandbox,
  production,
}

class PaymentResult {
  final PaymentStatus status;
  final String? gatewayTransactionId;
  final String? errorMessageAr;
  final FinancialEnvironment environment;
  final int? feeInSmallestUnit;
  final int? totalDebitedInSmallestUnit;
  final bool isSandbox;

  const PaymentResult({
    required this.status,
    this.gatewayTransactionId,
    this.errorMessageAr,
    this.environment = FinancialEnvironment.sandbox,
    this.feeInSmallestUnit,
    this.totalDebitedInSmallestUnit,
    this.isSandbox = true,
  });
}

/// عقد أي بوابة دفع مرخّصة. التنفيذ الفعلي يُربط لاحقاً بـ SDK حقيقي
/// (flutter_stripe أو ما يعادله)، وهذا الملف يوفر البنية والواجهة فقط.
abstract class PaymentGatewayClient {
  String get gatewayName;

  /// بدء عملية دفع لشحن المحفظة أو دفع فاتورة مباشرة. المبلغ بأصغر
  /// وحدة عملة (قروش/سنتات) تجنباً لأخطاء الفاصلة العشرية.
  Future<PaymentResult> chargeAmount({
    required int amountInSmallestUnit,
    required String currencyCode,
    required String description,
    String? idempotencyKey,
  });

  /// استرجاع مبلغ مدفوع سابقاً (يتطلب معرّف معاملة البوابة الأصلي).
  Future<PaymentResult> refund({
    required String gatewayTransactionId,
    int? partialAmountInSmallestUnit,
  });
}

/// تنفيذ توضيحي لبوابة Stripe — هيكل فقط، يتطلب ربط SDK حقيقي
/// (flutter_stripe) واعتماد مفتاح API خاص بحساب Stripe فعلي للمشروع
/// قبل الاستخدام الحقيقي.
class StripePaymentGatewayClient implements PaymentGatewayClient {
  StripePaymentGatewayClient({required this.publishableKey});

  final String publishableKey;

  @override
  String get gatewayName => 'Stripe';

  bool get isConfigured =>
      publishableKey.trim().isNotEmpty &&
      !publishableKey.contains('placeholder') &&
      !publishableKey.startsWith('pk_test_placeholder');

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
            'Stripe غير موصول بمفتاح إنتاجي. استخدم مسار Sandbox للاختبار، '
            'أو اربط مزوداً مرخّصاً. لا حركة أموال حقيقية.',
      );
    }
    return const PaymentResult(
      status: PaymentStatus.failed,
      environment: FinancialEnvironment.production,
      isSandbox: false,
      errorMessageAr: 'SDK Stripe غير مربوط بعد في هذا البناء.',
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
      errorMessageAr: 'بوابة الدفع الإنتاجية غير مُفعَّلة بعد.',
    );
  }
}

/// رسوم معاينة — من سياسة وليست نسبة ثابتة مخفية في Widget.
class TopUpFeePolicy {
  const TopUpFeePolicy({
    this.fixedMinor = 0,
    this.percentageBps = 0,
    this.payerPaysFee = true,
  });

  /// رسوم ثابتة بأصغر وحدة.
  final int fixedMinor;

  /// نقاط أساس (100 = 1%).
  final int percentageBps;
  final bool payerPaysFee;

  int feeOn(int amountMinor) {
    final pct = (amountMinor * percentageBps) ~/ 10000;
    return fixedMinor + pct;
  }
}

/// بوابة Sandbox معزولة — حركات واضحة كـ SANDBOX وليست أموالاً حقيقية.
class SandboxPaymentGatewayClient implements PaymentGatewayClient {
  SandboxPaymentGatewayClient({
    this.feePolicy = const TopUpFeePolicy(fixedMinor: 200, percentageBps: 0),
    this.shouldFail = false,
  });

  final TopUpFeePolicy feePolicy;
  final bool shouldFail;
  int _seq = 0;
  final _charges = <String, PaymentResult>{};
  final _webhooksSeen = <String>{};

  @override
  String get gatewayName => 'Lifex-Sandbox';

  @override
  Future<PaymentResult> chargeAmount({
    required int amountInSmallestUnit,
    required String currencyCode,
    required String description,
    String? idempotencyKey,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (idempotencyKey != null && _charges.containsKey(idempotencyKey)) {
      return _charges[idempotencyKey]!;
    }
    if (shouldFail) {
      return const PaymentResult(
        status: PaymentStatus.failed,
        environment: FinancialEnvironment.sandbox,
        isSandbox: true,
        errorMessageAr: 'SANDBOX: فُشل دفع اختباري مقصود.',
      );
    }
    _seq++;
    final fee = feePolicy.feeOn(amountInSmallestUnit);
    final total = amountInSmallestUnit + (feePolicy.payerPaysFee ? fee : 0);
    final result = PaymentResult(
      status: PaymentStatus.succeeded,
      gatewayTransactionId:
          'sbx_${DateTime.now().millisecondsSinceEpoch}_$_seq',
      environment: FinancialEnvironment.sandbox,
      isSandbox: true,
      feeInSmallestUnit: fee,
      totalDebitedInSmallestUnit: total,
      errorMessageAr: null,
    );
    if (idempotencyKey != null) {
      _charges[idempotencyKey] = result;
    }
    return result;
  }

  /// Webhook موقَّع اختبارياً — التوقيع = "sbx|" + id.
  SandboxWebhookResult simulateWebhook({
    required String gatewayTransactionId,
    required bool claimedSuccess,
    String? signature,
  }) {
    final expected = 'sbx|$gatewayTransactionId';
    final sig = signature ?? expected;
    if (sig != expected) {
      return const SandboxWebhookResult(
        accepted: false,
        messageAr: 'SANDBOX webhook: توقيع غير صالح.',
      );
    }
    if (_webhooksSeen.contains(gatewayTransactionId)) {
      return SandboxWebhookResult(
        accepted: true,
        duplicate: true,
        messageAr: 'SANDBOX webhook مكرر — لا قيد مزدوج.',
        gatewayTransactionId: gatewayTransactionId,
      );
    }
    _webhooksSeen.add(gatewayTransactionId);
    return SandboxWebhookResult(
      accepted: claimedSuccess,
      messageAr: claimedSuccess
          ? 'SANDBOX webhook مقبول.'
          : 'SANDBOX webhook: فشل معلن.',
      gatewayTransactionId: gatewayTransactionId,
    );
  }

  @override
  Future<PaymentResult> refund({
    required String gatewayTransactionId,
    int? partialAmountInSmallestUnit,
  }) async {
    return PaymentResult(
      status: PaymentStatus.refunded,
      gatewayTransactionId: 'sbx_rf_$gatewayTransactionId',
      environment: FinancialEnvironment.sandbox,
      isSandbox: true,
    );
  }
}

class SandboxWebhookResult {
  const SandboxWebhookResult({
    required this.accepted,
    required this.messageAr,
    this.duplicate = false,
    this.gatewayTransactionId,
  });

  final bool accepted;
  final String messageAr;
  final bool duplicate;
  final String? gatewayTransactionId;
}
