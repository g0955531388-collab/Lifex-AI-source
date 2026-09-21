/// =============================================================
/// Lifex-AI — المدير المركزي للمحفظة الرقمية
/// ينسّق بوابة الدفع + سجل المحفظة + دفتر القيد المزدوج (اختياري).
/// لا محفظة ثانية — امتداد WalletManager الموجود.
/// =============================================================
library lifex_ai.features.finance.wallet_manager;

import '../../core/financial/double_entry_ledger.dart';
import 'financial_receipt.dart';
import 'payment_gateway_client.dart';
import 'topup_session.dart';
import 'transaction_ledger.dart';
import 'wallet_account.dart';

class WalletOperationResult {
  final bool success;
  final String messageAr;
  final int? newBalance;
  final TopUpSession? session;
  final FinancialReceipt? receipt;
  final String? transactionId;

  const WalletOperationResult.success({
    required this.messageAr,
    this.newBalance,
    this.session,
    this.receipt,
    this.transactionId,
  }) : success = true;

  const WalletOperationResult.failure(
    this.messageAr, {
    this.session,
    this.transactionId,
  })  : success = false,
        newBalance = null,
        receipt = null;
}

/// المدير المركزي للمحفظة الرقمية.
class WalletManager {
  WalletManager({
    required this.gatewayClient,
    required this.ledger,
    DoubleEntryLedger? doubleEntryLedger,
    TopUpFeePolicy? topUpFeePolicy,
  })  : doubleEntryLedger = doubleEntryLedger ?? DoubleEntryLedger(),
        topUpFeePolicy = topUpFeePolicy ??
            const TopUpFeePolicy(fixedMinor: 200, percentageBps: 0);

  final PaymentGatewayClient gatewayClient;
  final TransactionLedger ledger;
  final DoubleEntryLedger doubleEntryLedger;
  final TopUpFeePolicy topUpFeePolicy;

  final _accounts = <String, WalletAccount>{};
  final _sessions = <String, TopUpSession>{};
  final _completedByIdempotency = <String, WalletOperationResult>{};
  final _audits = <String>[];
  int _sessionSeq = 0;
  int _receiptSeq = 0;

  String get gatewayName => gatewayClient.gatewayName;

  List<String> get auditTrail => List.unmodifiable(_audits);

  WalletAccount ensureAccount(String profileId, {String currency = 'USD'}) {
    return _accounts.putIfAbsent(
      profileId,
      () => WalletAccount(
        walletId: 'wal_$profileId',
        ownerIdentityId: profileId,
        accountId: 'acc_$profileId',
        currencyCode: currency,
      ),
    );
  }

  WalletBalances balancesFor(String profileId) {
    ensureAccount(profileId);
    return WalletBalances(
      availableMinor: ledger.currentBalanceFor(profileId),
      pendingMinor: ledger.pendingBalanceFor(profileId),
      reservedMinor: ledger.reservedBalanceFor(profileId),
      currencyCode: _accounts[profileId]?.currencyCode ?? 'USD',
    );
  }

  int balanceFor(String profileId) => ledger.currentBalanceFor(profileId);

  List<PaymentMethodOption> availablePaymentMethods() {
    final methods = <PaymentMethodOption>[
      const PaymentMethodOption(
        id: 'sandbox',
        labelAr: 'Sandbox — اختبار معزول',
        availability: PaymentMethodAvailability.sandbox,
      ),
    ];
    if (gatewayClient is StripePaymentGatewayClient) {
      final stripe = gatewayClient as StripePaymentGatewayClient;
      methods.add(
        PaymentMethodOption(
          id: 'stripe',
          labelAr: 'Stripe',
          availability: stripe.isConfigured
              ? PaymentMethodAvailability.available
              : PaymentMethodAvailability.notConfigured,
        ),
      );
    } else {
      methods.add(
        const PaymentMethodOption(
          id: 'stripe',
          labelAr: 'Stripe',
          availability: PaymentMethodAvailability.notConfigured,
        ),
      );
    }
    return methods;
  }

  TopUpSession beginTopUp({
    required String profileId,
    String? idempotencyKey,
  }) {
    ensureAccount(profileId);
    final key = idempotencyKey ??
        'topup_${profileId}_${DateTime.now().microsecondsSinceEpoch}';
    _sessionSeq++;
    final session = TopUpSession(
      sessionId: 'tu_$_sessionSeq',
      profileId: profileId,
      idempotencyKey: key,
    );
    _sessions[session.sessionId] = session;
    _audits.add('begin_topup|${session.sessionId}|$profileId');
    return session;
  }

  TopUpSession? sessionById(String sessionId) => _sessions[sessionId];

  /// استئناف جلسة معلّقة بعد إغلاق التطبيق.
  TopUpSession? resumeTopUp(String sessionId) {
    final s = _sessions[sessionId];
    if (s == null) return null;
    _audits.add('resume_topup|$sessionId|${s.phase.name}');
    return s;
  }

  TopUpFeePreview quoteTopUp(int amountMinor) {
    final fee = topUpFeePolicy.feeOn(amountMinor);
    final total = amountMinor + (topUpFeePolicy.payerPaysFee ? fee : 0);
    return TopUpFeePreview(
      amountMinor: amountMinor,
      feeMinor: fee,
      totalDebitedMinor: total,
      payerPaysFee: topUpFeePolicy.payerPaysFee,
      policyId: 'topup_${topUpFeePolicy.fixedMinor}_${topUpFeePolicy.percentageBps}',
    );
  }

  /// دورة شحن كاملة من جلسة مؤكَّدة — لا نجاح بلا مزود/سجل.
  Future<WalletOperationResult> executeTopUpSession(TopUpSession session) async {
    final prior = _completedByIdempotency[session.idempotencyKey];
    if (prior != null) {
      _audits.add('idempotent_hit|${session.idempotencyKey}');
      return prior;
    }

    final account = ensureAccount(session.profileId);
    if (!account.canTransact) {
      session.markFailed('المحفظة ${account.status.name} — العملية مرفوضة.');
      return WalletOperationResult.failure(
        session.failureReasonAr!,
        session: session,
      );
    }

    if (session.phase != TopUpPhase.requiresAuthentication &&
        session.phase != TopUpPhase.authorized) {
      return WalletOperationResult.failure(
        'الجلسة ليست جاهزة للتنفيذ (الحالة: ${session.phase.name}).',
        session: session,
      );
    }

    if (session.paymentMethodId == 'stripe') {
      session.markFailed(
        'Stripe غير موصول في هذا البناء. استخدم Sandbox — لا حركة أموال حقيقية.',
      );
      return WalletOperationResult.failure(
        session.failureReasonAr!,
        session: session,
      );
    }

    session.markAuthorized();
    session.markProcessing();
    // الحالة PROCESSING في الجلسة = رصيد معلّق منطقي حتى نتيجة المزود.
    // لا يُرحَّل إلى available إلا بعد succeeded + webhook (Sandbox).

    final result = await gatewayClient.chargeAmount(
      amountInSmallestUnit: session.amountMinor,
      currencyCode: session.currencyCode,
      description: 'شحن محفظة Lifex-AI',
      idempotencyKey: session.idempotencyKey,
    );

    if (result.status != PaymentStatus.succeeded) {
      session.markFailed(
        result.errorMessageAr ??
            'فشلت عملية الشحن (${result.status.name}). لا تغيير على الرصيد المتاح.',
      );
      final fail = WalletOperationResult.failure(
        session.failureReasonAr!,
        session: session,
      );
      return fail;
    }

    // محاكاة webhook Sandbox قبل الترحيل النهائي.
    if (result.isSandbox && gatewayClient is SandboxPaymentGatewayClient) {
      final sbx = gatewayClient as SandboxPaymentGatewayClient;
      final wh = sbx.simulateWebhook(
        gatewayTransactionId: result.gatewayTransactionId!,
        claimedSuccess: true,
      );
      if (!wh.accepted) {
        session.markFailed(wh.messageAr);
        return WalletOperationResult.failure(wh.messageAr, session: session);
      }
    }

    final posted = ledger.record(
      profileId: session.profileId,
      type: TransactionType.topUp,
      amountInSmallestUnit: session.amountMinor,
      currencyCode: session.currencyCode,
      relatedGatewayTransactionId: result.gatewayTransactionId,
      status: WalletTxStatus.posted,
      feeInSmallestUnit: result.feeInSmallestUnit ?? session.feeMinor,
      idempotencyKey: session.idempotencyKey,
      isSandbox: result.isSandbox,
    );

    doubleEntryLedger.postBalanced(
      transactionId: posted.transactionId,
      currency: session.currencyCode,
      amountMinor: session.amountMinor,
      platformFeeMinor: result.feeInSmallestUnit ?? session.feeMinor,
      clearingAccount: 'PaymentProviderClearing',
      payableAccount: 'WalletLiability_${session.profileId}',
      revenueAccount: 'LIFEX_PLATFORM_REVENUE',
    );

    _receiptSeq++;
    final receipt = FinancialReceipt(
      receiptId: 'rcpt_$_receiptSeq',
      transactionId: posted.transactionId,
      typeAr: 'شحن رصيد',
      amountMinor: session.amountMinor,
      feeMinor: result.feeInSmallestUnit ?? session.feeMinor,
      totalMinor:
          result.totalDebitedInSmallestUnit ?? session.totalDebitedMinor,
      currencyCode: session.currencyCode,
      status: 'COMPLETED',
      createdAt: DateTime.now(),
      senderLabel: 'payer',
      recipientLabel: session.profileId,
      providerReference: result.gatewayTransactionId ?? '',
      isSandbox: result.isSandbox,
      environmentTag: result.isSandbox ? 'SANDBOX' : 'LIVE',
    );

    session.markCompleted(
      gatewayTransactionId: result.gatewayTransactionId ?? '',
      receiptId: receipt.receiptId,
    );

    final ok = WalletOperationResult.success(
      messageAr: session.spokenStatusAr(),
      newBalance: ledger.currentBalanceFor(session.profileId),
      session: session,
      receipt: receipt,
      transactionId: posted.transactionId,
    );
    _completedByIdempotency[session.idempotencyKey] = ok;
    _audits.add(
      'topup_completed|${posted.transactionId}|${session.amountMinor}|'
      '${result.isSandbox ? 'SANDBOX' : 'LIVE'}',
    );
    return ok;
  }

  /// مسار مختصر متوافق مع الواجهات القديمة — يمر عبر آلة الحالات.
  Future<WalletOperationResult> topUp({
    required String profileId,
    required int amountInSmallestUnit,
    required String currencyCode,
    String? idempotencyKey,
    String paymentMethodId = 'sandbox',
  }) async {
    final priorKey = idempotencyKey;
    if (priorKey != null && _completedByIdempotency.containsKey(priorKey)) {
      return _completedByIdempotency[priorKey]!;
    }

    final session = beginTopUp(
      profileId: profileId,
      idempotencyKey: idempotencyKey,
    );
    if (!session.advanceFromDraft(
      amountMinor: amountInSmallestUnit,
      currency: currencyCode,
    )) {
      return const WalletOperationResult.failure('مبلغ الشحن غير صالح.');
    }

    final methods = availablePaymentMethods();
    final method = methods.firstWhere(
      (m) => m.id == paymentMethodId,
      orElse: () => methods.first,
    );
    if (!session.selectPaymentMethod(method)) {
      return WalletOperationResult.failure(
        session.failureReasonAr ?? 'وسيلة الدفع مرفوضة.',
        session: session,
      );
    }

    final quote = quoteTopUp(amountInSmallestUnit);
    session.applyFeePreview(
      feeMinor: quote.feeMinor,
      totalDebitedMinor: quote.totalDebitedMinor,
    );
    return executeTopUpSession(session);
  }

  WalletOperationResult payFromBalance({
    required String profileId,
    required int amountInSmallestUnit,
    required String currencyCode,
    required TransactionType type,
    String? relatedEntityId,
    String? idempotencyKey,
  }) {
    if (type == TransactionType.topUp ||
        type == TransactionType.refund ||
        type == TransactionType.transferIn) {
      return const WalletOperationResult.failure(
        'نوع المعاملة غير صالح للدفع من الرصيد.',
      );
    }

    final account = ensureAccount(profileId);
    if (!account.canTransact) {
      return WalletOperationResult.failure(
        'المحفظة ${account.status.name} — الدفع مرفوض.',
      );
    }

    final currentBalance = ledger.currentBalanceFor(profileId);
    if (currentBalance < amountInSmallestUnit) {
      return const WalletOperationResult.failure(
        'الرصيد الحالي في محفظتك غير كافٍ لإتمام هذه العملية. يُرجى '
        'شحن المحفظة أولاً.',
      );
    }

    final tx = ledger.record(
      profileId: profileId,
      type: type,
      amountInSmallestUnit: amountInSmallestUnit,
      currencyCode: currencyCode,
      relatedEntityId: relatedEntityId,
      idempotencyKey: idempotencyKey,
    );

    return WalletOperationResult.success(
      messageAr: 'تمت عملية الدفع بنجاح.',
      newBalance: ledger.currentBalanceFor(profileId),
      transactionId: tx.transactionId,
    );
  }

  /// تحويل داخلي Wallet → Wallet — النجاح فقط بعد قيد الطرفين.
  WalletOperationResult transferInternal({
    required String fromProfileId,
    required String toProfileId,
    required int amountMinor,
    required String currencyCode,
    String? idempotencyKey,
    int feeMinor = 0,
  }) {
    if (fromProfileId == toProfileId) {
      return const WalletOperationResult.failure(
        'لا يمكن التحويل إلى نفس المحفظة.',
      );
    }
    if (amountMinor <= 0) {
      return const WalletOperationResult.failure('مبلغ التحويل غير صالح.');
    }

    final key = idempotencyKey ??
        'xfer_${fromProfileId}_${toProfileId}_$amountMinor';
    if (_completedByIdempotency.containsKey(key)) {
      return _completedByIdempotency[key]!;
    }

    final from = ensureAccount(fromProfileId);
    final to = ensureAccount(toProfileId, currency: currencyCode);
    if (!from.canTransact || !to.canTransact) {
      return const WalletOperationResult.failure(
        'إحدى المحفظتين غير قابلة للتحويل (مجمّدة أو مغلقة).',
      );
    }
    if (from.currencyCode != to.currencyCode) {
      return const WalletOperationResult.failure(
        'العملات مختلفة — يتطلب مسار FX منفصل. لا تحويل مباشر.',
      );
    }

    final totalDebit = amountMinor + feeMinor;
    if (ledger.currentBalanceFor(fromProfileId) < totalDebit) {
      return const WalletOperationResult.failure('رصيد غير كافٍ للتحويل.');
    }

    final out = ledger.record(
      profileId: fromProfileId,
      type: TransactionType.transferOut,
      amountInSmallestUnit: amountMinor,
      currencyCode: currencyCode,
      counterpartyProfileId: toProfileId,
      feeInSmallestUnit: feeMinor,
      idempotencyKey: '${key}_out',
      isSandbox: gatewayClient is SandboxPaymentGatewayClient,
    );
    if (feeMinor > 0) {
      ledger.record(
        profileId: fromProfileId,
        type: TransactionType.platformFee,
        amountInSmallestUnit: feeMinor,
        currencyCode: currencyCode,
        relatedEntityId: out.transactionId,
        idempotencyKey: '${key}_fee',
      );
    }
    final incoming = ledger.record(
      profileId: toProfileId,
      type: TransactionType.transferIn,
      amountInSmallestUnit: amountMinor,
      currencyCode: currencyCode,
      counterpartyProfileId: fromProfileId,
      relatedEntityId: out.transactionId,
      idempotencyKey: '${key}_in',
      isSandbox: gatewayClient is SandboxPaymentGatewayClient,
    );

    doubleEntryLedger.postBalanced(
      transactionId: out.transactionId,
      currency: currencyCode,
      amountMinor: amountMinor,
      platformFeeMinor: feeMinor,
      clearingAccount: 'WalletTransferClearing',
      payableAccount: 'WalletLiability_$toProfileId',
      revenueAccount: 'LIFEX_PLATFORM_REVENUE',
    );

    _receiptSeq++;
    final receipt = FinancialReceipt(
      receiptId: 'rcpt_$_receiptSeq',
      transactionId: out.transactionId,
      typeAr: 'تحويل داخلي',
      amountMinor: amountMinor,
      feeMinor: feeMinor,
      totalMinor: totalDebit,
      currencyCode: currencyCode,
      status: 'COMPLETED',
      createdAt: DateTime.now(),
      senderLabel: fromProfileId,
      recipientLabel: toProfileId,
      providerReference: incoming.transactionId,
      isSandbox: gatewayClient is SandboxPaymentGatewayClient,
    );

    final ok = WalletOperationResult.success(
      messageAr:
          'اكتمل التحويل. المبلغ $amountMinor، الرسوم $feeMinor (أصغر وحدة). '
          'المستلم: $toProfileId.',
      newBalance: ledger.currentBalanceFor(fromProfileId),
      receipt: receipt,
      transactionId: out.transactionId,
    );
    _completedByIdempotency[key] = ok;
    _audits.add('transfer|$fromProfileId->$toProfileId|$amountMinor');
    return ok;
  }

  /// سحب — غير متاح بلا مزود مرخّص؛ يفشل بصراحة.
  Future<WalletOperationResult> withdraw({
    required String profileId,
    required int amountMinor,
    required String currencyCode,
  }) async {
    return const WalletOperationResult.failure(
      'السحب الخارجي غير موصول بمزود مرخّص في هذا البناء. '
      'لا تحويل بنكي وهمي.',
    );
  }
}

class TopUpFeePreview {
  const TopUpFeePreview({
    required this.amountMinor,
    required this.feeMinor,
    required this.totalDebitedMinor,
    required this.payerPaysFee,
    required this.policyId,
  });

  final int amountMinor;
  final int feeMinor;
  final int totalDebitedMinor;
  final bool payerPaysFee;
  final String policyId;

  String summaryAr() =>
      'المبلغ: ${(amountMinor / 100).toStringAsFixed(2)} — '
      'الرسوم: ${(feeMinor / 100).toStringAsFixed(2)} — '
      'الإجمالي: ${(totalDebitedMinor / 100).toStringAsFixed(2)} '
      '(سياسة: $policyId)'
      '${payerPaysFee ? ' — الرسوم على الشاحن' : ' — الرسوم من المبلغ'}';
}
