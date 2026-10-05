/// =============================================================
/// Lifex-AI — مالية
/// الملف: double_entry_ledger.dart
/// قيود صحيحة بوحدات صغرى صحيحة. ليس رصيداً وهمياً في التطبيق.
/// =============================================================
library lifex_ai.core.financial.double_entry_ledger;

import 'financial_types.dart';

class DoubleEntryLedger {
  final entries = <LedgerEntry>[];

  bool postBalanced({
    required String transactionId,
    required String currency,
    required int amountMinor,
    required int platformFeeMinor,
    required String clearingAccount,
    required String payableAccount,
    required String revenueAccount,
  }) {
    if (amountMinor <= 0) return false;
    if (platformFeeMinor < 0 || platformFeeMinor > amountMinor) return false;
    final payable = amountMinor - platformFeeMinor;
    final ts = DateTime.now();
    entries.addAll([
      LedgerEntry(
        id: '${transactionId}_d',
        transactionId: transactionId,
        accountId: clearingAccount,
        debitMinor: amountMinor,
        creditMinor: 0,
        currency: currency,
        timestamp: ts,
        description: 'clearing',
      ),
      LedgerEntry(
        id: '${transactionId}_c_pay',
        transactionId: transactionId,
        accountId: payableAccount,
        debitMinor: 0,
        creditMinor: payable,
        currency: currency,
        timestamp: ts,
        description: 'merchant_payable',
      ),
      LedgerEntry(
        id: '${transactionId}_c_rev',
        transactionId: transactionId,
        accountId: revenueAccount,
        debitMinor: 0,
        creditMinor: platformFeeMinor,
        currency: currency,
        timestamp: ts,
        description: 'LIFEX_PLATFORM_REVENUE',
      ),
    ]);
    return isBalanced(transactionId);
  }

  bool isBalanced(String transactionId) {
    var d = 0;
    var c = 0;
    for (final e in entries.where((e) => e.transactionId == transactionId)) {
      d += e.debitMinor;
      c += e.creditMinor;
    }
    return d == c && d > 0;
  }

  int accountNet(String accountId) {
    var n = 0;
    for (final e in entries.where((e) => e.accountId == accountId)) {
      n += e.debitMinor - e.creditMinor;
    }
    return n;
  }
}
