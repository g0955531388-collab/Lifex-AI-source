/// =============================================================
/// Lifex-AI — جلسة شحن (state machine)
/// الزر Continu يغيّر حالة معروفة — لا ينتهي المسار بلا نتيجة.
/// =============================================================
library lifex_ai.features.finance.topup_session;

/// حالات عملية الشحن — BUTTON CLICK ≠ PAYMENT SUCCESS.
enum TopUpPhase {
  draft,
  created,
  requiresPaymentMethod,
  requiresAuthentication,
  pending,
  authorized,
  processing,
  completed,
  failed,
  cancelled,
  expired,
  refunded,
  partiallyRefunded,
  chargeback,
  underReview,
}

enum PaymentMethodAvailability {
  available,
  notConfigured,
  sandbox,
}

class PaymentMethodOption {
  const PaymentMethodOption({
    required this.id,
    required this.labelAr,
    required this.availability,
  });

  final String id;
  final String labelAr;
  final PaymentMethodAvailability availability;

  bool get canCharge =>
      availability == PaymentMethodAvailability.available ||
      availability == PaymentMethodAvailability.sandbox;
}

class TopUpSession {
  TopUpSession({
    required this.sessionId,
    required this.profileId,
    required this.idempotencyKey,
    this.currencyCode = 'USD',
  });

  final String sessionId;
  final String profileId;
  final String idempotencyKey;
  String currencyCode;
  TopUpPhase phase = TopUpPhase.draft;
  int amountMinor = 0;
  int feeMinor = 0;
  int totalDebitedMinor = 0;
  String? paymentMethodId;
  String? gatewayTransactionId;
  String? failureReasonAr;
  String? receiptId;
  bool isSandbox = true;
  final audits = <String>[];

  void _audit(String event) {
    audits.add('${DateTime.now().toIso8601String()}|$event|${phase.name}');
  }

  /// التالي من المسودة → اختيار وسيلة (أو المبلغ إن ناقص).
  bool advanceFromDraft({required int amountMinor, required String currency}) {
    if (phase != TopUpPhase.draft && phase != TopUpPhase.requiresPaymentMethod) {
      return false;
    }
    if (amountMinor <= 0) return false;
    this.amountMinor = amountMinor;
    currencyCode = currency;
    phase = TopUpPhase.requiresPaymentMethod;
    _audit('amount_set:$amountMinor');
    return true;
  }

  bool selectPaymentMethod(PaymentMethodOption method) {
    if (phase != TopUpPhase.requiresPaymentMethod &&
        phase != TopUpPhase.created) {
      return false;
    }
    if (!method.canCharge) {
      failureReasonAr =
          '${method.labelAr}: ${method.availability.name} — غير قابل للشحن.';
      phase = TopUpPhase.failed;
      _audit('method_rejected:${method.id}');
      return false;
    }
    paymentMethodId = method.id;
    isSandbox = method.availability == PaymentMethodAvailability.sandbox;
    phase = TopUpPhase.created;
    _audit('method:${method.id}');
    return true;
  }

  bool applyFeePreview({
    required int feeMinor,
    required int totalDebitedMinor,
  }) {
    if (phase != TopUpPhase.created &&
        phase != TopUpPhase.requiresAuthentication) {
      return false;
    }
    this.feeMinor = feeMinor;
    this.totalDebitedMinor = totalDebitedMinor;
    phase = TopUpPhase.requiresAuthentication;
    _audit('fee_preview:$feeMinor');
    return true;
  }

  bool markAuthorized() {
    if (phase != TopUpPhase.requiresAuthentication) return false;
    phase = TopUpPhase.authorized;
    _audit('authorized');
    return true;
  }

  bool markProcessing() {
    if (phase != TopUpPhase.authorized && phase != TopUpPhase.pending) {
      return false;
    }
    phase = TopUpPhase.processing;
    _audit('processing');
    return true;
  }

  bool markCompleted({
    required String gatewayTransactionId,
    required String receiptId,
  }) {
    if (phase != TopUpPhase.processing && phase != TopUpPhase.pending) {
      return false;
    }
    this.gatewayTransactionId = gatewayTransactionId;
    this.receiptId = receiptId;
    phase = TopUpPhase.completed;
    _audit('completed');
    return true;
  }

  bool markFailed(String reasonAr) {
    failureReasonAr = reasonAr;
    phase = TopUpPhase.failed;
    _audit('failed');
    return true;
  }

  bool cancel() {
    if (phase == TopUpPhase.completed || phase == TopUpPhase.refunded) {
      return false;
    }
    phase = TopUpPhase.cancelled;
    _audit('cancelled');
    return true;
  }

  String spokenStatusAr() {
    switch (phase) {
      case TopUpPhase.draft:
        return 'أدخل مبلغ الشحن.';
      case TopUpPhase.requiresPaymentMethod:
        return 'اختر وسيلة الدفع.';
      case TopUpPhase.created:
        return 'راجع الرسوم قبل التأكيد.';
      case TopUpPhase.requiresAuthentication:
        return 'المبلغ ${(amountMinor / 100).toStringAsFixed(2)}، '
            'الرسوم ${(feeMinor / 100).toStringAsFixed(2)}، '
            'الإجمالي ${(totalDebitedMinor / 100).toStringAsFixed(2)}. هل تؤكد؟';
      case TopUpPhase.processing:
      case TopUpPhase.pending:
      case TopUpPhase.authorized:
        return 'جارٍ معالجة الشحن. الحالة: ${phase.name}.';
      case TopUpPhase.completed:
        return isSandbox
            ? 'COMPLETED [SANDBOX] اكتمل شحن اختباري. الرصيد محدَّث. ليست أموالاً حقيقية.'
            : 'COMPLETED اكتمل الشحن بنجاح.';
      case TopUpPhase.failed:
        return 'فشل الشحن: ${failureReasonAr ?? phase.name}. لا تغيير على الرصيد.';
      case TopUpPhase.cancelled:
        return 'أُلغيت عملية الشحن.';
      default:
        return 'حالة الشحن: ${phase.name}.';
    }
  }
}
