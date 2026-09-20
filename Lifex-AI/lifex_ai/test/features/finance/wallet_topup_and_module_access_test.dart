import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/trial_manager.dart';
import 'package:lifex_ai/features/finance/payment_controller.dart';
import 'package:lifex_ai/features/finance/payment_gateway_client.dart';
import 'package:lifex_ai/features/finance/topup_session.dart';
import 'package:lifex_ai/features/finance/transaction_ledger.dart';
import 'package:lifex_ai/features/finance/wallet_account.dart';
import 'package:lifex_ai/features/finance/wallet_manager.dart';
import 'package:lifex_ai/features/voice/command_parser.dart';

void main() {
  group('SessionAccessPolicy — Module Access ≠ Entitlement', () {
    const policy = SessionAccessPolicy();

    test('SubscriptionDoesNotBlockCoreModule — doctors تفتح بعد انتهاء التجربة', () {
      expect(
        policy.canOpenUnit(
          'doctors',
          phase: TrialPhase.residual,
          feeExempt: false,
        ),
        isTrue,
      );
    });
  });

  group('Wallet Top-Up Sandbox End-to-End', () {
    WalletManager buildWallet({bool fail = false}) {
      final ledger = TransactionLedger();
      final gateway = SandboxPaymentGatewayClient(
        feePolicy: const TopUpFeePolicy(fixedMinor: 200),
        shouldFail: fail,
      );
      return WalletManager(
        gatewayClient: gateway,
        ledger: ledger,
        topUpFeePolicy: const TopUpFeePolicy(fixedMinor: 200),
      );
    }

    test('TopUpFlowTest — معاينة رسوم ثم نجاح Sandbox يحدّث الرصيد', () async {
      final wallet = buildWallet();
      final controller = PaymentController(walletManager: wallet);

      final preview = controller.previewTopUpFee(amountInSmallestUnit: 10000);
      expect(preview.amountMinor, 10000);
      expect(preview.feeMinor, 200);
      expect(preview.totalDebitedMinor, 10200);

      final result = await controller.handleTopUpRequest(
        profileId: 'p1',
        amountInSmallestUnit: 10000,
        currencyCode: 'USD',
        idempotencyKey: 'idem-1',
      );
      expect(result.success, isTrue);
      expect(result.messageAr.contains('SANDBOX'), isTrue);
      expect(result.receipt, isNotNull);
      expect(wallet.balanceFor('p1'), 10000);
      expect(
        wallet.doubleEntryLedger.isBalanced(result.transactionId!),
        isTrue,
      );
    });

    test('TopUpFailureTest — فشل البوابة لا يغيّر الرصيد المتاح', () async {
      final wallet = buildWallet(fail: true);
      final result = await wallet.topUp(
        profileId: 'p2',
        amountInSmallestUnit: 5000,
        currencyCode: 'USD',
      );
      expect(result.success, isFalse);
      expect(wallet.balanceFor('p2'), 0);
    });

    test('TopUpIdempotencyTest — إعادة نفس المفتاح لا تشحن مرتين', () async {
      final wallet = buildWallet();
      final a = await wallet.topUp(
        profileId: 'p3',
        amountInSmallestUnit: 3000,
        currencyCode: 'USD',
        idempotencyKey: 'same-key',
      );
      final b = await wallet.topUp(
        profileId: 'p3',
        amountInSmallestUnit: 3000,
        currencyCode: 'USD',
        idempotencyKey: 'same-key',
      );
      expect(a.success, isTrue);
      expect(b.success, isTrue);
      expect(wallet.balanceFor('p3'), 3000);
    });

    test('TopUpPaymentMethodTest — Stripe غير الموصول لا يدّعي نجاحاً', () async {
      final client = StripePaymentGatewayClient(
        publishableKey: 'pk_test_placeholder',
      );
      final r = await client.chargeAmount(
        amountInSmallestUnit: 100,
        currencyCode: 'USD',
        description: 'x',
      );
      expect(r.status, PaymentStatus.failed);
      expect(r.isSandbox, isFalse);

      final wallet = buildWallet();
      final bad = await wallet.topUp(
        profileId: 'p4',
        amountInSmallestUnit: 1000,
        currencyCode: 'USD',
        paymentMethodId: 'stripe',
      );
      expect(bad.success, isFalse);
      expect(wallet.balanceFor('p4'), 0);
    });

    test('TopUpSession state machine — لا قفز من draft إلى completed', () {
      final s = TopUpSession(
        sessionId: 's1',
        profileId: 'p',
        idempotencyKey: 'k',
      );
      expect(s.markCompleted(gatewayTransactionId: 'x', receiptId: 'r'), isFalse);
      expect(s.phase, TopUpPhase.draft);
      expect(s.advanceFromDraft(amountMinor: 100, currency: 'USD'), isTrue);
      expect(s.phase, TopUpPhase.requiresPaymentMethod);
    });

    test('TopUpWebhookTest — توقيع غير صالح يُرفض', () {
      final sbx = SandboxPaymentGatewayClient();
      final bad = sbx.simulateWebhook(
        gatewayTransactionId: 'sbx_1',
        claimedSuccess: true,
        signature: 'wrong',
      );
      expect(bad.accepted, isFalse);
      final ok = sbx.simulateWebhook(
        gatewayTransactionId: 'sbx_1',
        claimedSuccess: true,
      );
      expect(ok.accepted, isTrue);
      final dup = sbx.simulateWebhook(
        gatewayTransactionId: 'sbx_1',
        claimedSuccess: true,
      );
      expect(dup.duplicate, isTrue);
    });

    test('AvailableBalanceTest / PendingBalanceTest', () async {
      final wallet = buildWallet();
      expect(wallet.balancesFor('p5').availableMinor, 0);
      await wallet.topUp(
        profileId: 'p5',
        amountInSmallestUnit: 2000,
        currencyCode: 'USD',
        idempotencyKey: 'p5-1',
      );
      final bal = wallet.balancesFor('p5');
      expect(bal.availableMinor, 2000);
      expect(bal.currencyCode, 'USD');
    });

    test('InternalTransferTest + TransferIdempotencyTest', () async {
      final wallet = buildWallet();
      await wallet.topUp(
        profileId: 'alice',
        amountInSmallestUnit: 10000,
        currencyCode: 'USD',
        idempotencyKey: 'alice-top',
      );
      final t1 = wallet.transferInternal(
        fromProfileId: 'alice',
        toProfileId: 'bob',
        amountMinor: 2500,
        currencyCode: 'USD',
        idempotencyKey: 'xfer-1',
        feeMinor: 0,
      );
      expect(t1.success, isTrue);
      expect(wallet.balanceFor('alice'), 7500);
      expect(wallet.balanceFor('bob'), 2500);
      final t2 = wallet.transferInternal(
        fromProfileId: 'alice',
        toProfileId: 'bob',
        amountMinor: 2500,
        currencyCode: 'USD',
        idempotencyKey: 'xfer-1',
      );
      expect(wallet.balanceFor('alice'), 7500);
      expect(t2.transactionId, t1.transactionId);
    });

    test('TransferFailureTest — رصيد غير كافٍ', () {
      final wallet = buildWallet();
      final r = wallet.transferInternal(
        fromProfileId: 'empty',
        toProfileId: 'bob',
        amountMinor: 100,
        currencyCode: 'USD',
      );
      expect(r.success, isFalse);
    });

    test('WithdrawalTest — غير موصول يفشل بصراحة', () async {
      final wallet = buildWallet();
      final r = await wallet.withdraw(
        profileId: 'p',
        amountMinor: 100,
        currencyCode: 'USD',
      );
      expect(r.success, isFalse);
      expect(r.messageAr.contains('غير موصول'), isTrue);
    });

    test('LedgerDoubleEntryTest — قيد متوازن بعد الشحن', () async {
      final wallet = buildWallet();
      final r = await wallet.topUp(
        profileId: 'led',
        amountInSmallestUnit: 5000,
        currencyCode: 'USD',
        idempotencyKey: 'led-1',
      );
      expect(r.success, isTrue);
      expect(wallet.doubleEntryLedger.isBalanced(r.transactionId!), isTrue);
    });

    test('ProductionNoFakeTransactionTest — Stripe placeholder لا ينجح', () async {
      final stripe = StripePaymentGatewayClient(
        publishableKey: 'pk_test_placeholder',
      );
      expect(stripe.isConfigured, isFalse);
      final r = await stripe.chargeAmount(
        amountInSmallestUnit: 999,
        currencyCode: 'USD',
        description: 'live claim',
      );
      expect(r.status, PaymentStatus.failed);
    });

    test('VoiceWalletTest — أوامر المحفظة', () {
      final p = CommandParser();
      expect(p.parse('افتح محفظتي').intent, VoiceCommandIntent.openWallet);
      expect(p.parse('كم رصيدي').intent, VoiceCommandIntent.walletBalance);
      expect(p.parse('شحن الرصيد').intent, VoiceCommandIntent.walletTopUp);
    });

    test('Resume session بعد الإلغاء يبقى معلوماً', () {
      final wallet = buildWallet();
      final s = wallet.beginTopUp(profileId: 'r1');
      s.advanceFromDraft(amountMinor: 1000, currency: 'USD');
      s.cancel();
      final resumed = wallet.resumeTopUp(s.sessionId);
      expect(resumed?.phase, TopUpPhase.cancelled);
    });

    test('Frozen wallet يرفض الشحن', () async {
      final wallet = buildWallet();
      final acc = wallet.ensureAccount('frozen');
      acc.status = WalletStatus.frozen;
      final r = await wallet.topUp(
        profileId: 'frozen',
        amountInSmallestUnit: 1000,
        currencyCode: 'USD',
        idempotencyKey: 'fr-1',
      );
      expect(r.success, isFalse);
    });
  });
}
