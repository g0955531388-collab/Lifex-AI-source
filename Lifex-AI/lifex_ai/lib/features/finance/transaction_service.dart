/// =============================================================
/// Lifex-AI — المعاملات المالية
/// الملف: transaction_service.dart
/// المسار: lib/features/finance/transaction_service.dart
/// الوصف: خدمة استعلام رقيقة فوق TransactionLedger — توفر تجميعات
/// وتقارير جاهزة للواجهة (كشف حساب، ملخص شهري) دون تعديل السجل نفسه،
/// حفاظاً على مبدأ "سجل للإضافة فقط" (Append-only Ledger).
/// =============================================================

import 'transaction_ledger.dart';

class MonthlyTransactionSummary {
  final int year;
  final int month;
  final int totalTopUps;
  final int totalPayments;
  final int netChange;

  const MonthlyTransactionSummary({
    required this.year,
    required this.month,
    required this.totalTopUps,
    required this.totalPayments,
    required this.netChange,
  });
}

/// خدمة المعاملات — طبقة استعلام وتقارير فوق السجل الأساسي.
class TransactionService {
  TransactionService({required this.ledger});

  final TransactionLedger ledger;

  /// كشف حساب كامل لمستخدم معيّن، مرتَّب من الأحدث للأقدم.
  List<WalletTransaction> statementFor(String profileId) {
    final history = ledger.historyFor(profileId);
    return List<WalletTransaction>.from(history)
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
  }

  /// ملخص شهري لحركة محفظة مستخدم معيّن.
  MonthlyTransactionSummary monthlySummaryFor({
    required String profileId,
    required int year,
    required int month,
  }) {
    final relevant = ledger.historyFor(profileId).where(
          (t) => t.recordedAt.year == year && t.recordedAt.month == month,
        );

    int totalTopUps = 0;
    int totalPayments = 0;

    for (final t in relevant) {
      switch (t.type) {
        case TransactionType.topUp:
        case TransactionType.refund:
        case TransactionType.transferIn:
          totalTopUps += t.amountInSmallestUnit;
          break;
        case TransactionType.hospitalPayment:
        case TransactionType.donationPayment:
        case TransactionType.subscriptionPayment:
        case TransactionType.appStoreSale:
        case TransactionType.platformFee:
        case TransactionType.extraService:
        case TransactionType.transferOut:
        case TransactionType.withdrawal:
          totalPayments += t.amountInSmallestUnit;
          break;
      }
    }

    return MonthlyTransactionSummary(
      year: year,
      month: month,
      totalTopUps: totalTopUps,
      totalPayments: totalPayments,
      netChange: totalTopUps - totalPayments,
    );
  }

  /// كل المعاملات المرتبطة بكيان معيّن (مثلاً كل الدفعات لفاتورة مستشفى
  /// واحدة بعينها عبر relatedEntityId)، بغض النظر عن صاحب المحفظة.
  List<WalletTransaction> transactionsForEntity(String relatedEntityId) {
    return ledger.allTransactions
        .where((t) => t.relatedEntityId == relatedEntityId)
        .toList();
  }
}
