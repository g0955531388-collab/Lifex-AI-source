/// =============================================================
/// Lifex-AI — مركز المحفظة
/// كل عملية مالية حساسة تمر عبر LioSensitiveActionEntry → LIO.
/// =============================================================
library lifex_ai.screens.wallet_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';
import '../core/trial_manager.dart';
import '../features/finance/billing_exemption_policy.dart';
import '../features/finance/subscription_catalog.dart';
import '../features/finance/topup_session.dart';
import '../features/finance/transaction_ledger.dart';
import '../features/finance/wallet_account.dart';
import '../features/finance/wallet_manager.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/profile/health_profile.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, required this.profileId});

  final String profileId;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _isProcessing = false;
  String? _statusMessageAr;
  String? _lastSessionId;
  WalletBalances? _balances;
  List<WalletTransaction> _statement = const [];
  String _gatewayName = '';
  String? _feePreviewHintAr;

  LioSensitiveActionEntry get _entry =>
      Provider.of<LioSensitiveActionEntry>(context, listen: false);

  LioGatewayRequest _req({
    required String action,
    LioActionRisk risk = LioActionRisk.medium,
    bool humanConfirmed = false,
  }) {
    return LioGatewayRequest(
      requestId:
          'wallet_${action}_${widget.profileId}_${DateTime.now().millisecondsSinceEpoch}',
      correlationId: 'wallet_${widget.profileId}',
      identityAccountId: widget.profileId,
      purpose: 'wallet_ops',
      requestedAction: action,
      dataScope: 'wallet_balance_view',
      sensitivity: LioDataSensitivity.personal,
      consent: const LioConsentContext(
        consentGranted: true,
        purposeAligned: true,
      ),
      riskLevel: risk,
      timestamp: DateTime.now().toUtc(),
      authenticated: true,
      authorized: true,
      humanConfirmed: humanConfirmed,
      minimumNecessarySatisfied: true,
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshWalletView());
  }

  Future<void> _refreshWalletView() async {
    final entry = _entry;
    final bal = await entry.readWalletBalances(
      gatewayRequest: _req(action: 'read_wallet_balances', risk: LioActionRisk.low),
      profileId: widget.profileId,
    );
    final stmt = await entry.readWalletStatement(
      gatewayRequest: _req(action: 'read_wallet_statement', risk: LioActionRisk.low),
      profileId: widget.profileId,
    );
    final gw = await entry.readWalletGatewayName(
      gatewayRequest: _req(action: 'read_wallet_gateway', risk: LioActionRisk.low),
    );
    final fee = await entry.previewWalletTopUpFee(
      gatewayRequest: _req(action: 'preview_topup_fee', risk: LioActionRisk.low),
      amountInSmallestUnit: 10000,
    );
    if (!mounted) return;
    setState(() {
      if (bal.executed) _balances = bal.value;
      if (stmt.executed) _statement = stmt.value ?? const [];
      if (gw.executed) _gatewayName = gw.value ?? '';
      if (fee.executed) _feePreviewHintAr = fee.value?.summaryAr();
    });
  }

  Future<void> _showTopUpWizard({int? initialDollars}) async {
    final entry = _entry;
    final methodsOutcome = await entry.listWalletPaymentMethods(
      gatewayRequest: _req(action: 'list_payment_methods', risk: LioActionRisk.low),
    );
    if (!mounted) return;
    final methods = methodsOutcome.executed
        ? (methodsOutcome.value ?? const <PaymentMethodOption>[])
        : const <PaymentMethodOption>[];
    if (methods.isEmpty) {
      setState(() => _statusMessageAr = 'توقفت قائمة وسائل الدفع عند LIO.');
      return;
    }

    final amountController = TextEditingController(
      text: initialDollars != null && initialDollars > 0
          ? '$initialDollars'
          : '',
    );
    var step = 0;
    var methodId = 'sandbox';
    TopUpSession? session;
    TopUpFeePreview? preview;
    var resultMessage = '';

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            Widget body;
            switch (step) {
              case 0:
                body = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'الخطوة 1/3 — المبلغ (دولار صحيح، وحدات صغرى داخل النظام).',
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: false,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ (دولار)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setLocal(() {}),
                    ),
                  ],
                );
              case 1:
                body = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('الخطوة 2/3 — وسيلة الدفع'),
                    const SizedBox(height: 12),
                    ...methods.map(
                      (m) => RadioListTile<String>(
                        title: Text(
                          '${m.labelAr} (${m.availability.name})',
                        ),
                        value: m.id,
                        groupValue: methodId,
                        onChanged: m.canCharge
                            ? (v) => setLocal(() => methodId = v ?? 'sandbox')
                            : null,
                      ),
                    ),
                    if (!methods.any((m) => m.id == methodId && m.canCharge))
                      const Text(
                        'الوسيلة المختارة غير متاحة. اختر Sandbox.',
                        style: TextStyle(color: Colors.orange),
                      ),
                  ],
                );
              case 2:
                body = Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('الخطوة 3/3 — الرسوم والتأكيد'),
                    const SizedBox(height: 12),
                    Text(preview?.summaryAr() ?? 'لا معاينة رسوم'),
                    const SizedBox(height: 8),
                    Text(
                      session?.spokenStatusAr() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Text(
                      'الرسوم من Fee Policy. Sandbox ≠ أموال حقيقية.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                );
              default:
                body = Text(resultMessage);
            }

            return AlertDialog(
              title: const Text('شحن الرصيد'),
              content: SingleChildScrollView(child: body),
              actions: [
                TextButton(
                  onPressed: () {
                    session?.cancel();
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(step >= 3 ? 'إغلاق' : 'إلغاء'),
                ),
                if (step > 0 && step < 3)
                  TextButton(
                    onPressed: () => setLocal(() => step -= 1),
                    child: const Text('رجوع'),
                  ),
                if (step == 0)
                  FilledButton(
                    onPressed: () async {
                      final dollars =
                          int.tryParse(amountController.text.trim());
                      if (dollars == null || dollars <= 0) return;
                      final begin = await entry.beginWalletTopUp(
                        gatewayRequest: _req(
                          action: 'begin_wallet_topup',
                          risk: LioActionRisk.medium,
                        ),
                        profileId: widget.profileId,
                      );
                      if (!begin.executed || begin.value == null) {
                        setLocal(() {
                          resultMessage =
                              'توقف الشحن عند LIO (${begin.decision.wireDecision}).';
                          step = 3;
                        });
                        return;
                      }
                      session = begin.value;
                      session!.advanceFromDraft(
                        amountMinor: dollars * 100,
                        currency: 'USD',
                      );
                      _lastSessionId = session!.sessionId;
                      setLocal(() => step = 1);
                    },
                    child: const Text('التالي — وسيلة الدفع'),
                  ),
                if (step == 1)
                  FilledButton(
                    onPressed: () async {
                      final method = methods.firstWhere(
                        (m) => m.id == methodId,
                        orElse: () => methods.first,
                      );
                      if (session == null) return;
                      if (!session!.selectPaymentMethod(method)) {
                        setLocal(() {
                          resultMessage =
                              session!.failureReasonAr ?? 'وسيلة مرفوضة';
                          step = 3;
                        });
                        return;
                      }
                      final fee = await entry.previewWalletTopUpFee(
                        gatewayRequest: _req(
                          action: 'preview_topup_fee',
                          risk: LioActionRisk.low,
                        ),
                        amountInSmallestUnit: session!.amountMinor,
                      );
                      if (!fee.executed || fee.value == null) {
                        setLocal(() {
                          resultMessage = 'توقفت معاينة الرسوم عند LIO.';
                          step = 3;
                        });
                        return;
                      }
                      preview = fee.value;
                      session!.applyFeePreview(
                        feeMinor: preview!.feeMinor,
                        totalDebitedMinor: preview!.totalDebitedMinor,
                      );
                      setLocal(() => step = 2);
                    },
                    child: const Text('التالي — الرسوم'),
                  ),
                if (step == 2)
                  FilledButton(
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            if (session == null) return;
                            setState(() {
                              _isProcessing = true;
                              _statusMessageAr = 'PROCESSING…';
                            });
                            final result = await entry.confirmWalletTopUp(
                              gatewayRequest: _req(
                                action: 'confirm_wallet_topup',
                                risk: LioActionRisk.high,
                                humanConfirmed: true,
                              ),
                              session: session!,
                            );
                            if (!mounted) return;
                            if (!result.executed) {
                              setState(() {
                                _isProcessing = false;
                                _statusMessageAr =
                                    'توقف التأكيد عند LIO (${result.decision.wireDecision}).';
                              });
                              setLocal(() {
                                resultMessage = _statusMessageAr!;
                                step = 3;
                              });
                              return;
                            }
                            final r = result.value!;
                            setState(() {
                              _isProcessing = false;
                              _statusMessageAr = r.success
                                  ? 'COMPLETED — ${r.messageAr}'
                                  : 'FAILED — ${r.messageAr}';
                            });
                            setLocal(() {
                              resultMessage =
                                  r.receipt?.summaryAr() ?? r.messageAr;
                              step = 3;
                            });
                            await _refreshWalletView();
                          },
                    child: const Text('تأكيد الشحن'),
                  ),
              ],
            );
          },
        );
      },
    );
    amountController.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _quickSandboxTopUp(int dollars) async {
    await _showTopUpWizard(initialDollars: dollars);
  }

  Future<void> _showTransferDialog() async {
    final toController = TextEditingController();
    final amountController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحويل داخلي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: toController,
              decoration: const InputDecoration(
                labelText: 'معرّف مستلم Lifex (profileId)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ (دولار)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Contact ≠ Financial Account. التحويل لمحفظة Lifex فقط.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('مراجعة وتأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final dollars = int.tryParse(amountController.text.trim());
    final toId = toController.text.trim();
    if (dollars == null || dollars <= 0 || toId.isEmpty) {
      setState(() => _statusMessageAr = 'بيانات التحويل غير صالحة.');
      return;
    }
    final feePreview = await _entry.previewWalletTopUpFee(
      gatewayRequest: _req(action: 'preview_topup_fee', risk: LioActionRisk.low),
      amountInSmallestUnit: dollars * 100,
    );
    final policyId = feePreview.value?.policyId ?? 'n/a';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد التحويل'),
        content: Text(
          'إلى: $toId\n'
          'المبلغ: ${dollars.toStringAsFixed(2)}\n'
          'رسوم التحويل: 0.00 (لا سياسة تحويل منشورة غير الصفر)\n'
          'ملاحظة معاينة شحن منفصلة: $policyId',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final result = await _entry.transferWalletFunds(
      gatewayRequest: _req(
        action: 'transfer_wallet_funds',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
      fromProfileId: widget.profileId,
      toProfileId: toId,
      amountMinor: dollars * 100,
      currencyCode: 'USD',
      feeMinor: 0,
    );
    setState(() {
      if (!result.executed) {
        _statusMessageAr =
            'توقف التحويل عند LIO (${result.decision.wireDecision}).';
      } else {
        final r = result.value!;
        _statusMessageAr = r.success
            ? 'COMPLETED — ${r.messageAr}'
            : 'FAILED — ${r.messageAr}';
      }
    });
    await _refreshWalletView();
  }

  Future<void> _chargeAnnual(HealthProfile profile) async {
    setState(() {
      _isProcessing = true;
      _statusMessageAr = null;
    });
    final entry = _entry;
    final gateways = await entry.listBillingGateways(
      gatewayRequest: _req(action: 'list_billing_gateways', risk: LioActionRisk.low),
      countryCode:
          profile.accountCountry.trim().isEmpty ? 'US' : profile.accountCountry,
    );
    if (!gateways.executed || (gateways.value?.isEmpty ?? true)) {
      setState(() {
        _isProcessing = false;
        _statusMessageAr =
            'REQUIRES_EXTERNAL_SETUP — الاشتراك السنوي معروف لكن بوابة '
            'الدفع غير مربوطة. لا تحصيل وهمي.';
      });
      return;
    }
    final outcome = await entry.chargeAnnualSubscription(
      gatewayRequest: _req(
        action: 'charge_annual_subscription',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
      profile: profile,
      gatewayName: gateways.value!.first,
    );
    if (!mounted) return;
    if (outcome.executed && (outcome.value?.success ?? false)) {
      context.read<TrialManager>().activatePaidYear();
    }
    setState(() {
      _isProcessing = false;
      _statusMessageAr = outcome.executed
          ? outcome.value!.messageAr
          : 'توقف الاشتراك عند LIO (${outcome.decision.wireDecision}).';
    });
  }

  Future<void> _withdraw() async {
    final r = await _entry.withdrawWallet(
      gatewayRequest: _req(
        action: 'withdraw_wallet',
        risk: LioActionRisk.high,
        humanConfirmed: true,
      ),
      profileId: widget.profileId,
      amountMinor: 100,
      currencyCode: 'USD',
    );
    setState(() {
      _statusMessageAr = r.executed
          ? r.value!.messageAr
          : 'توقف السحب عند LIO (${r.decision.wireDecision}).';
    });
  }

  Future<void> _resumeLastSession() async {
    if (_lastSessionId == null) return;
    final s = await _entry.resumeWalletTopUp(
      gatewayRequest: _req(action: 'resume_wallet_topup', risk: LioActionRisk.low),
      sessionId: _lastSessionId!,
    );
    setState(() {
      _statusMessageAr = !s.executed
          ? 'توقف الاستئناف عند LIO.'
          : (s.value == null
              ? 'لا جلسة لاستئنافها.'
              : 'استئناف: ${s.value!.spokenStatusAr()}');
    });
  }

  void _openTxDetail(WalletTransaction tx) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_transactionLabelAr(tx.type),
                style: Theme.of(ctx).textTheme.titleMedium),
            Text('الحالة: ${tx.status.name}'),
            Text(
              'المبلغ: \$${(tx.amountInSmallestUnit / 100).toStringAsFixed(2)}',
            ),
            if (tx.relatedGatewayTransactionId != null)
              Text('مرجع المزود: ${tx.relatedGatewayTransactionId}'),
            if (tx.counterpartyProfileId != null)
              Text('الطرف المقابل: ${tx.counterpartyProfileId}'),
            Text(tx.isSandbox ? 'البيئة: SANDBOX' : 'البيئة: LIVE'),
            Text('الوقت: ${tx.recordedAt.toIso8601String()}'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ActiveProfileController>().activeProfile;
    final catalog = const SubscriptionCatalog();
    final seat = catalog.parseSeat(profile?.billingSeat ?? 'individual');
    final plan = catalog.planFor(seat);
    final exemption = profile == null
        ? const BillingExemptionResult.notExempt()
        : const BillingExemptionPolicy().evaluate(profile);

    final balances = _balances ??
        const WalletBalances(
          availableMinor: 0,
          pendingMinor: 0,
          reservedMinor: 0,
          currencyCode: 'USD',
        );
    final statement = _statement;

    return Scaffold(
      appBar: AppBar(
        title: const Text('محفظتي'),
        actions: [
          if (_lastSessionId != null)
            IconButton(
              tooltip: 'استئناف آخر جلسة شحن',
              onPressed: _resumeLastSession,
              icon: const Icon(Icons.restore),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        liveRegion: true,
                        label:
                            'الرصيد المتاح ${(balances.availableMinor / 100).toStringAsFixed(2)} '
                            'معلق ${(balances.pendingMinor / 100).toStringAsFixed(2)}',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('الرصيد المتاح',
                                style: TextStyle(fontSize: 14)),
                            Text(
                              '\$${(balances.availableMinor / 100).toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            Text(
                              'معلّق: \$${(balances.pendingMinor / 100).toStringAsFixed(2)} — '
                              'محجوز: \$${(balances.reservedMinor / 100).toStringAsFixed(2)} — '
                              '${balances.currencyCode}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'المزوّد: $_gatewayName',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Text(plan.titleAr,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('\$${plan.usd} / سنة — ${plan.includesAr}'),
                      Text(
                        exemption.isExempt
                            ? (exemption.reasonAr ?? 'معفى: لا أجور ولا رسوم.')
                            : 'تحويل الأموال والخدمات الخاصة: رسوم حسب سياسة المنصة.',
                        style: const TextStyle(fontSize: 12),
                      ),
                      if (profile != null)
                        DropdownButton<BillingSeat>(
                          value: seat,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: BillingSeat.individual,
                              child: Text('فرد — 100 دولار سنوياً'),
                            ),
                            DropdownMenuItem(
                              value: BillingSeat.healthUnit,
                              child: Text('وحدة صحية — 300 دولار سنوياً'),
                            ),
                            DropdownMenuItem(
                              value: BillingSeat.hospital,
                              child: Text('مستشفى — 600 دولار سنوياً'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            profile.billingSeat = value.name;
                            context
                                .read<ActiveProfileController>()
                                .saveActiveProfileChanges();
                            setState(() {});
                          },
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                _isProcessing ? null : _showTopUpWizard,
                            icon: const Icon(Icons.add),
                            label: const Text('شحن الرصيد'),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                _isProcessing ? null : _showTransferDialog,
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('تحويل'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isProcessing ? null : _withdraw,
                            icon: const Icon(Icons.account_balance),
                            label: const Text('سحب'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: (_isProcessing || profile == null)
                                ? null
                                : () => _chargeAnnual(profile),
                            icon: const Icon(Icons.event_available_outlined),
                            label: Text(
                              exemption.isExempt
                                  ? 'تفعيل بلا رسوم'
                                  : 'اشتراك \$${plan.usd}',
                            ),
                          ),
                        ],
                      ),
                      if (_statusMessageAr != null) ...[
                        const SizedBox(height: 8),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _statusMessageAr!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'كشف الحساب / المعاملات',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            Expanded(
              child: statement.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      children: [
                        Semantics(
                          liveRegion: true,
                          label:
                              'المحفظة جاهزة بلا حركات. الرصيد صفر حتى شحن Sandbox.',
                          child: const Text(
                            'EMPTY — لا حركات بعد.\n'
                            'هذا ليس عطلاً وليس حظراً بالاشتراك.\n'
                            'الخطوة التالية: شحن Sandbox (اختبار معزول، ليس مالاً حقيقياً).',
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'شحن سريع للاختبار:',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            for (final d in [10, 50, 100])
                              FilledButton.tonal(
                                onPressed: _isProcessing
                                    ? null
                                    : () => _quickSandboxTopUp(d),
                                child: Text('\$$d'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed:
                              _isProcessing ? null : _showTopUpWizard,
                          icon: const Icon(Icons.add_card),
                          label: const Text(
                              'بدء شحن كامل — مبلغ ثم وسيلة ثم رسوم'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _feePreviewHintAr ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: statement.length,
                      itemBuilder: (context, index) {
                        final tx = statement[index];
                        final isCredit = tx.type == TransactionType.topUp ||
                            tx.type == TransactionType.refund ||
                            tx.type == TransactionType.transferIn;
                        return ListTile(
                          onTap: () => _openTxDetail(tx),
                          leading: Icon(
                            isCredit
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isCredit ? Colors.green : Colors.red,
                          ),
                          title: Text(_transactionLabelAr(tx.type)),
                          subtitle: Text(
                            '${tx.status.name} — ${tx.recordedAt.year}/'
                            '${tx.recordedAt.month}/${tx.recordedAt.day}'
                            '${tx.isSandbox ? ' — SANDBOX' : ''}',
                          ),
                          trailing: Text(
                            '${isCredit ? '+' : '-'}\$'
                            '${(tx.amountInSmallestUnit / 100).toStringAsFixed(2)}',
                            style: TextStyle(
                              color: isCredit ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _transactionLabelAr(TransactionType type) {
    switch (type) {
      case TransactionType.topUp:
        return 'شحن رصيد';
      case TransactionType.hospitalPayment:
        return 'دفع فاتورة مستشفى';
      case TransactionType.donationPayment:
        return 'تبرع';
      case TransactionType.refund:
        return 'استرجاع مبلغ';
      case TransactionType.subscriptionPayment:
        return 'دفع اشتراك';
      case TransactionType.appStoreSale:
        return 'مبيعات المتجر';
      case TransactionType.platformFee:
        return 'رسوم منصة على تحويل أو خدمة';
      case TransactionType.extraService:
        return 'خدمة إضافية خارج الاشتراك';
      case TransactionType.transferOut:
        return 'تحويل صادر';
      case TransactionType.transferIn:
        return 'تحويل وارد';
      case TransactionType.withdrawal:
        return 'سحب';
    }
  }
}
