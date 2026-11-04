/// =============================================================
/// Lifex-AI — المعاملات المالية
/// الملف: wallet_manager.dart
/// المسار: lib/features/finance/wallet_manager.dart
/// الوصف: المدير المركزي للمحفظة الرقمية — ينسّق بين بوابة الدفع
/// المرخّصة الخارجية (PaymentGatewayClient) وسجل المعاملات
/// (TransactionLedger)، ويربط الرصيد بدفع فواتير المستشفى أو التبرعات.
/// =============================================================

import 'payment_gateway_client.dart';
import 'transaction_ledger.dart';

class WalletOperationResult {
  final bool success;
  final String messageAr;
  final int? newBalance;

  const WalletOperationResult.success({
    required this.messageAr,
    this.newBalance,
  }) : success = true;

  const WalletOperationResult.failure(this.messageAr)
      : success = false,
        newBalance = null;
}

/// المدير المركزي للمحفظة الرقمية.
class WalletManager {
  WalletManager({
    required this.gatewayClient,
    required this.ledger,
  });

  final PaymentGatewayClient gatewayClient;
  final TransactionLedger ledger;

  /// شحن المحفظة عبر بوابة الدفع المرخّصة — لا يلمس أي بيانات بطاقة
  /// خام؛ البوابة نفسها تتولى كل تفاصيل الدفع الحساسة.
  Future<WalletOperationResult> topUp({
    required String profileId,
    required int amountInSmallestUnit,
    required String currencyCode,
  }) async {
    if (profileId.trim().isEmpty || amountInSmallestUnit <= 0 ||
        currencyCode.trim().isEmpty) {
      return const WalletOperationResult.failure('بيانات الشحن غير صالحة.');
    }
    final result = await gatewayClient.chargeAmount(
      amountInSmallestUnit: amountInSmallestUnit,
      currencyCode: currencyCode,
      description: 'شحن محفظة Lifex-AI',
    );

    if (result.status != PaymentStatus.succeeded) {
      return WalletOperationResult.failure(
        result.errorMessageAr ?? 'فشلت عملية الشحن. حاول مرة أخرى.',
      );
    }

    ledger.record(
      profileId: profileId,
      type: TransactionType.topUp,
      amountInSmallestUnit: amountInSmallestUnit,
      currencyCode: currencyCode,
      relatedGatewayTransactionId: result.gatewayTransactionId,
    );

    return WalletOperationResult.success(
      messageAr: 'تم شحن محفظتك بنجاح.',
      newBalance: ledger.currentBalanceFor(
        profileId,
        currencyCode: currencyCode,
      ),
    );
  }

  /// الدفع من رصيد المحفظة الحالي (وليس مباشرة من البطاقة) — لدفع
  /// فاتورة مستشفى أو تبرع، مع التأكد من كفاية الرصيد أولاً.
  WalletOperationResult payFromBalance({
    required String profileId,
    required int amountInSmallestUnit,
    required String currencyCode,
    required TransactionType type,
    String? relatedEntityId,
  }) {
    if (type == TransactionType.topUp || type == TransactionType.refund) {
      return const WalletOperationResult.failure(
        'نوع المعاملة غير صالح للدفع من الرصيد.',
      );
    }

    if (profileId.trim().isEmpty || amountInSmallestUnit <= 0 ||
        currencyCode.trim().isEmpty) {
      return const WalletOperationResult.failure('بيانات الدفع غير صالحة.');
    }
    final currentBalance = ledger.currentBalanceFor(
      profileId,
      currencyCode: currencyCode,
    );
    if (currentBalance < amountInSmallestUnit) {
      return const WalletOperationResult.failure(
        'الرصيد الحالي في محفظتك غير كافٍ لإتمام هذه العملية. يُرجى '
        'شحن المحفظة أولاً.',
      );
    }

    ledger.record(
      profileId: profileId,
      type: type,
      amountInSmallestUnit: amountInSmallestUnit,
      currencyCode: currencyCode,
      relatedEntityId: relatedEntityId,
    );

    return WalletOperationResult.success(
      messageAr: 'تمت عملية الدفع بنجاح.',
      newBalance: ledger.currentBalanceFor(
        profileId,
        currencyCode: currencyCode,
      ),
    );
  }

  int balanceFor(String profileId, {String currencyCode = 'USD'}) =>
      ledger.currentBalanceFor(profileId, currencyCode: currencyCode);
}
