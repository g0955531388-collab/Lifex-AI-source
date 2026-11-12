/// =============================================================
/// Lifex-AI — إيصال مالي (بدون بيانات حساسة)
/// =============================================================
library lifex_ai.features.finance.financial_receipt;

class FinancialReceipt {
  const FinancialReceipt({
    required this.receiptId,
    required this.transactionId,
    required this.typeAr,
    required this.amountMinor,
    required this.feeMinor,
    required this.totalMinor,
    required this.currencyCode,
    required this.status,
    required this.createdAt,
    this.senderLabel = '',
    this.recipientLabel = '',
    this.providerReference = '',
    this.isSandbox = true,
    this.environmentTag = 'SANDBOX',
  });

  final String receiptId;
  final String transactionId;
  final String typeAr;
  final int amountMinor;
  final int feeMinor;
  final int totalMinor;
  final String currencyCode;
  final String status;
  final DateTime createdAt;
  final String senderLabel;
  final String recipientLabel;
  final String providerReference;
  final bool isSandbox;
  final String environmentTag;

  String summaryAr() {
    final env = isSandbox ? '[$environmentTag] ' : '';
    return '$env$typeAr — المبلغ ${(amountMinor / 100).toStringAsFixed(2)} '
        '$currencyCode — الرسوم ${(feeMinor / 100).toStringAsFixed(2)} — '
        'الإجمالي ${(totalMinor / 100).toStringAsFixed(2)} — الحالة $status'
        '${providerReference.isEmpty ? '' : ' — مرجع $providerReference'}';
  }
}
