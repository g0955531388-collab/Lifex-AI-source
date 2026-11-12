/// =============================================================
/// Lifex-AI — متحكم الدفع (واجهة رقيقة فوق WalletManager)
/// =============================================================
library lifex_ai.features.finance.payment_controller;

import 'payment_gateway_client.dart';
import 'topup_session.dart';
import 'transaction_ledger.dart';
import 'wallet_manager.dart';

export 'wallet_manager.dart' show TopUpFeePreview, WalletOperationResult;

/// نتيجة التحقق من صحة طلب دفع قبل إرساله لأي بوابة خارجية.
class PaymentRequestValidation {
  final bool isValid;
  final String? errorMessageAr;

  const PaymentRequestValidation.valid()
      : isValid = true,
        errorMessageAr = null;

  const PaymentRequestValidation.invalid(this.errorMessageAr) : isValid = false;
}

/// متحكم الدفع — نقطة الدخول الموحدة من الواجهة لكل عمليات الدفع.
class PaymentController {
  PaymentController({required this.walletManager});

  final WalletManager walletManager;

  PaymentRequestValidation validateTopUpRequest({
    required int amountInSmallestUnit,
    required String currencyCode,
  }) {
    if (amountInSmallestUnit <= 0) {
      return const PaymentRequestValidation.invalid(
        'قيمة الشحن يجب أن تكون أكبر من صفر.',
      );
    }
    if (currencyCode.trim().isEmpty) {
      return const PaymentRequestValidation.invalid(
        'يجب تحديد عملة صالحة لعملية الدفع.',
      );
    }
    return const PaymentRequestValidation.valid();
  }

  TopUpSession beginTopUp({
    required String profileId,
    String? idempotencyKey,
  }) {
    return walletManager.beginTopUp(
      profileId: profileId,
      idempotencyKey: idempotencyKey,
    );
  }

  TopUpFeePreview previewTopUpFee({
    required int amountInSmallestUnit,
    TopUpFeePolicy? policy,
  }) {
    if (policy != null) {
      final fee = policy.feeOn(amountInSmallestUnit);
      final total = amountInSmallestUnit + (policy.payerPaysFee ? fee : 0);
      return TopUpFeePreview(
        amountMinor: amountInSmallestUnit,
        feeMinor: fee,
        totalDebitedMinor: total,
        payerPaysFee: policy.payerPaysFee,
        policyId: 'preview_${policy.fixedMinor}',
      );
    }
    return walletManager.quoteTopUp(amountInSmallestUnit);
  }

  /// معالجة طلب شحن: تحقق → آلة حالات → بوابة → رصيد عند النجاح فقط.
  Future<WalletOperationResult> handleTopUpRequest({
    required String profileId,
    required int amountInSmallestUnit,
    required String currencyCode,
    String paymentMethodId = 'sandbox',
    String? idempotencyKey,
  }) async {
    final validation = validateTopUpRequest(
      amountInSmallestUnit: amountInSmallestUnit,
      currencyCode: currencyCode,
    );

    if (!validation.isValid) {
      return WalletOperationResult.failure(
        validation.errorMessageAr ?? 'طلب دفع غير صالح.',
      );
    }

    return walletManager.topUp(
      profileId: profileId,
      amountInSmallestUnit: amountInSmallestUnit,
      currencyCode: currencyCode,
      paymentMethodId: paymentMethodId,
      idempotencyKey: idempotencyKey,
    );
  }

  Future<WalletOperationResult> confirmTopUpSession(TopUpSession session) {
    return walletManager.executeTopUpSession(session);
  }

  WalletOperationResult handleBalancePaymentRequest({
    required String profileId,
    required int amountInSmallestUnit,
    required String currencyCode,
    required TransactionType type,
    String? relatedEntityId,
  }) {
    if (amountInSmallestUnit <= 0) {
      return const WalletOperationResult.failure(
        'قيمة الدفع يجب أن تكون أكبر من صفر.',
      );
    }

    return walletManager.payFromBalance(
      profileId: profileId,
      amountInSmallestUnit: amountInSmallestUnit,
      currencyCode: currencyCode,
      type: type,
      relatedEntityId: relatedEntityId,
    );
  }

  WalletOperationResult handleTransfer({
    required String fromProfileId,
    required String toProfileId,
    required int amountMinor,
    required String currencyCode,
    String? idempotencyKey,
    int feeMinor = 0,
  }) {
    return walletManager.transferInternal(
      fromProfileId: fromProfileId,
      toProfileId: toProfileId,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      idempotencyKey: idempotencyKey,
      feeMinor: feeMinor,
    );
  }
}
