/// =============================================================
/// Lifex-AI — نقطة دخول Application الإلزامية قبل العمليات الحساسة
/// UI → AppContext → LioSensitiveActionEntry → ProductionLioGateway
/// → (ALLOW/EMERGENCY_LIMITED) → Application callback → Audit
///
/// LIO يحكم ويصرّح فقط — لا ينفّذ العملية ولا يلمس SQL/DB.
/// ممنوع إنشاء Gateway ثانٍ.
/// =============================================================
library lifex_ai.core.orchestrator.lio_sensitive_action_entry;

import '../../data/medical_database_manager.dart';
import '../../features/ai/ai_service_router.dart';
import '../../features/ai/unified_ai_hub_gateway.dart';
import '../../features/emergency/emergency_manager.dart';
import '../../features/emergency/emergency_message_manager.dart';
import '../../features/finance/payment_controller.dart';
import '../../features/finance/subscription_billing_manager.dart';
import '../../features/finance/topup_session.dart';
import '../../features/finance/transaction_ledger.dart';
import '../../features/finance/transaction_service.dart';
import '../../features/finance/wallet_account.dart';
import '../../features/finance/wallet_manager.dart';
import '../../features/outreach/encyclopedia_share_bridge.dart';
import '../../features/profile/health_profile.dart';
import '../agent/agent_confidence.dart';
import '../agent/agent_context.dart';
import '../agent/agent_core.dart';
import '../agent/agent_orchestrator.dart';
import '../agent/agent_result.dart';
import '../agent/agent_state.dart';
import '../lasting_search_index.dart';
import '../local_knowledge.dart';
import '../search_refresh_engine.dart';
import 'lio_gateway.dart';
import 'lio_gateway_contracts.dart';
import 'lio_sensitive_lifecycle_contracts.dart';

/// نتيجة عبور البوابة ثم التنفيذ (أو التوقف).
class LioSensitiveActionOutcome<T> {
  const LioSensitiveActionOutcome._({
    required this.decision,
    required this.executed,
    this.value,
  });

  factory LioSensitiveActionOutcome.blocked(LioGatewayDecision decision) {
    return LioSensitiveActionOutcome._(
      decision: decision,
      executed: false,
    );
  }

  factory LioSensitiveActionOutcome.completed({
    required LioGatewayDecision decision,
    required T value,
  }) {
    return LioSensitiveActionOutcome._(
      decision: decision,
      executed: true,
      value: value,
    );
  }

  final LioGatewayDecision decision;
  final bool executed;
  final T? value;

  bool get wasAllowedThroughLio => decision.mayProceedToMcp;
}

/// عقد Application: كل طلب حساس يمر عبر LIO قبل التنفيذ.
class LioSensitiveActionEntry {
  const LioSensitiveActionEntry({
    required this.lioGateway,
    required this.agentCore,
    required this.aiServiceRouter,
    required this.aiHubGateway,
    this.walletManager,
    this.transactionService,
    this.paymentController,
    this.subscriptionBillingManager,
    this.medicalDatabaseManager,
    this.localKnowledge,
    this.lastingSearchIndex,
    this.emergencyManager,
    this.encyclopediaShareBridge,
  });

  static const String entryId = 'LioSensitiveActionEntry';

  final ProductionLioGateway lioGateway;
  final AgentCoreBundle agentCore;
  final AiServiceRouter aiServiceRouter;
  final UnifiedAiHubGateway aiHubGateway;

  final WalletManager? walletManager;
  final TransactionService? transactionService;
  final PaymentController? paymentController;
  final SubscriptionBillingManager? subscriptionBillingManager;
  final MedicalDatabaseManager? medicalDatabaseManager;
  final LocalKnowledge? localKnowledge;
  final LastingSearchIndex? lastingSearchIndex;
  final EmergencyManager? emergencyManager;
  final EncyclopediaShareBridge? encyclopediaShareBridge;

  /// يربط عمليات Application الحساسة دون إنشاء Gateway/Entry ثانٍ.
  LioSensitiveActionEntry bindApplicationOps({
    WalletManager? walletManager,
    TransactionService? transactionService,
    PaymentController? paymentController,
    SubscriptionBillingManager? subscriptionBillingManager,
    MedicalDatabaseManager? medicalDatabaseManager,
    LocalKnowledge? localKnowledge,
    LastingSearchIndex? lastingSearchIndex,
    EmergencyManager? emergencyManager,
    EncyclopediaShareBridge? encyclopediaShareBridge,
  }) {
    return LioSensitiveActionEntry(
      lioGateway: lioGateway,
      agentCore: agentCore,
      aiServiceRouter: aiServiceRouter,
      aiHubGateway: aiHubGateway,
      walletManager: walletManager ?? this.walletManager,
      transactionService: transactionService ?? this.transactionService,
      paymentController: paymentController ?? this.paymentController,
      subscriptionBillingManager:
          subscriptionBillingManager ?? this.subscriptionBillingManager,
      medicalDatabaseManager:
          medicalDatabaseManager ?? this.medicalDatabaseManager,
      localKnowledge: localKnowledge ?? this.localKnowledge,
      lastingSearchIndex: lastingSearchIndex ?? this.lastingSearchIndex,
      emergencyManager: emergencyManager ?? this.emergencyManager,
      encyclopediaShareBridge:
          encyclopediaShareBridge ?? this.encyclopediaShareBridge,
    );
  }

  /// يقيّم عبر LIO ثم ينفّذ [run] فقط عند ALLOW / EMERGENCY_LIMITED.
  Future<LioSensitiveActionOutcome<T>> authorizeThenRun<T>({
    required LioGatewayRequest request,
    required Future<T> Function() run,
  }) async {
    final decision = lioGateway.evaluate(request);
    if (!lioGateway.mayHandOffToMcp(decision)) {
      return LioSensitiveActionOutcome.blocked(decision);
    }
    final value = await run();
    return LioSensitiveActionOutcome.completed(
      decision: decision,
      value: value,
    );
  }

  // —— AI / Agent (موجود) ——

  Future<LioSensitiveActionOutcome<AgentResult>> runAgentRequest({
    required LioGatewayRequest gatewayRequest,
    required AgentContext agentContext,
    required String sessionId,
    AgentTaskProgressListener? onProgress,
    Map<String, dynamic>? emergencyTriggerContext,
  }) {
    return authorizeThenRun<AgentResult>(
      request: gatewayRequest,
      run: () => agentCore.coordinator.handleUserRequest(
        context: agentContext,
        sessionId: sessionId,
        emergencyTriggerContext: emergencyTriggerContext,
        onProgress: onProgress,
      ),
    );
  }

  Future<LioSensitiveActionOutcome<ExternalAiResponse>> runAiChatQuery({
    required LioGatewayRequest gatewayRequest,
    required String profileId,
    required String userQuery,
  }) {
    return authorizeThenRun<ExternalAiResponse>(
      request: gatewayRequest,
      run: () => aiServiceRouter.query(
        profileId: profileId,
        userQuery: userQuery,
      ),
    );
  }

  Future<LioSensitiveActionOutcome<bool>> connectExternalAiAccount({
    required LioGatewayRequest gatewayRequest,
    required String profileId,
    required ExternalAiProvider provider,
    required String accountLabel,
    required String apiKeyOrToken,
  }) {
    return authorizeThenRun<bool>(
      request: gatewayRequest,
      run: () => aiHubGateway.connectAccount(
        profileId: profileId,
        provider: provider,
        accountLabel: accountLabel,
        apiKeyOrToken: apiKeyOrToken,
      ),
    );
  }

  Future<LioSensitiveActionOutcome<void>> disconnectExternalAiAccount({
    required LioGatewayRequest gatewayRequest,
    required String profileId,
    required ExternalAiProvider provider,
  }) {
    return authorizeThenRun<void>(
      request: gatewayRequest,
      run: () => aiHubGateway.disconnectAccount(
        profileId: profileId,
        provider: provider,
      ),
    );
  }

  Future<LioSensitiveActionOutcome<List<ConnectedAiAccount>>>
      listConnectedAiAccounts({
    required LioGatewayRequest gatewayRequest,
    required String profileId,
  }) {
    return authorizeThenRun<List<ConnectedAiAccount>>(
      request: gatewayRequest,
      run: () async => aiHubGateway.connectedAccountsFor(profileId),
    );
  }

  void cancelAgentTask(String taskId) {
    agentCore.coordinator.cancelTask(taskId);
  }

  AgentResult blockedAgentResult({
    required String taskId,
    required LioGatewayDecision decision,
  }) {
    return AgentResult(
      taskId: taskId,
      finalState: AgentTaskState.blocked,
      summaryAr: 'توقف الطلب عند بوابة LIO: ${decision.wireDecision}',
      confidence: AgentConfidence.unknown,
      disclaimerAr: kAgentDefaultDisclaimerAr,
      errorMessageAr: decision.reasonAr,
    );
  }

  // —— READ_MEDICAL / DOWNLOAD ——

  Future<LioSensitiveActionOutcome<Map<String, dynamic>>> readMedicalBundle({
    required LioGatewayRequest gatewayRequest,
    required String fileName,
  }) {
    final db = medicalDatabaseManager;
    if (db == null) {
      return authorizeThenRun(
        request: gatewayRequest,
        run: () async => throw StateError('medicalDatabaseManager unbound'),
      );
    }
    return authorizeThenRun(
      request: gatewayRequest,
      run: () => db.readBundleFile(fileName),
    );
  }

  Future<LioSensitiveActionOutcome<String?>> checkMedicalDbVersion({
    required LioGatewayRequest gatewayRequest,
  }) {
    final db = medicalDatabaseManager;
    if (db == null) {
      return authorizeThenRun(
        request: gatewayRequest,
        run: () async => throw StateError('medicalDatabaseManager unbound'),
      );
    }
    return authorizeThenRun(
      request: gatewayRequest,
      run: () => db.checkForNewerVersion(),
    );
  }

  Future<LioSensitiveActionOutcome<SearchRefreshReport>> refreshMedicalKnowledge({
    required LioGatewayRequest gatewayRequest,
  }) {
    final db = medicalDatabaseManager;
    final knowledge = localKnowledge;
    final lasting = lastingSearchIndex;
    if (db == null || knowledge == null || lasting == null) {
      return authorizeThenRun(
        request: gatewayRequest,
        run: () async => throw StateError('medical refresh deps unbound'),
      );
    }
    return authorizeThenRun(
      request: gatewayRequest,
      run: () => const SearchRefreshEngine().refresh(
            knowledge: knowledge,
            lasting: lasting,
            database: db,
          ),
    );
  }

  // —— FINANCIAL / WALLET ——

  Future<LioSensitiveActionOutcome<WalletBalances>> readWalletBalances({
    required LioGatewayRequest gatewayRequest,
    required String profileId,
  }) {
    final wallet = walletManager;
    if (wallet == null) {
      return authorizeThenRun(
        request: gatewayRequest,
        run: () async => throw StateError('walletManager unbound'),
      );
    }
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => wallet.balancesFor(profileId),
    );
  }

  Future<LioSensitiveActionOutcome<List<WalletTransaction>>>
      readWalletStatement({
    required LioGatewayRequest gatewayRequest,
    required String profileId,
  }) {
    final txs = transactionService;
    if (txs == null) {
      return authorizeThenRun(
        request: gatewayRequest,
        run: () async => throw StateError('transactionService unbound'),
      );
    }
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => txs.statementFor(profileId),
    );
  }

  Future<LioSensitiveActionOutcome<String>> readWalletGatewayName({
    required LioGatewayRequest gatewayRequest,
  }) {
    final wallet = walletManager;
    if (wallet == null) {
      return authorizeThenRun(
        request: gatewayRequest,
        run: () async => throw StateError('walletManager unbound'),
      );
    }
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => wallet.gatewayName,
    );
  }

  Future<LioSensitiveActionOutcome<List<PaymentMethodOption>>>
      listWalletPaymentMethods({
    required LioGatewayRequest gatewayRequest,
  }) {
    final wallet = walletManager;
    if (wallet == null) {
      return authorizeThenRun(
        request: gatewayRequest,
        run: () async => throw StateError('walletManager unbound'),
      );
    }
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => wallet.availablePaymentMethods(),
    );
  }

  Future<LioSensitiveActionOutcome<TopUpSession?>> resumeWalletTopUp({
    required LioGatewayRequest gatewayRequest,
    required String sessionId,
  }) {
    final wallet = walletManager;
    if (wallet == null) {
      return authorizeThenRun(
        request: gatewayRequest,
        run: () async => throw StateError('walletManager unbound'),
      );
    }
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => wallet.resumeTopUp(sessionId),
    );
  }

  Future<LioSensitiveActionOutcome<TopUpSession>> beginWalletTopUp({
    required LioGatewayRequest gatewayRequest,
    required String profileId,
    String? idempotencyKey,
  }) {
    final payment = paymentController;
    if (payment == null) {
      return authorizeThenRun(
        request: gatewayRequest,
        run: () async => throw StateError('paymentController unbound'),
      );
    }
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => payment.beginTopUp(
            profileId: profileId,
            idempotencyKey: idempotencyKey,
          ),
    );
  }

  Future<LioSensitiveActionOutcome<TopUpFeePreview>> previewWalletTopUpFee({
    required LioGatewayRequest gatewayRequest,
    required int amountInSmallestUnit,
  }) {
    final payment = paymentController;
    if (payment == null) {
      return authorizeThenRun(
        request: gatewayRequest,
        run: () async => throw StateError('paymentController unbound'),
      );
    }
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => payment.previewTopUpFee(
            amountInSmallestUnit: amountInSmallestUnit,
          ),
    );
  }

  Future<LioSensitiveActionOutcome<WalletOperationResult>> confirmWalletTopUp({
    required LioGatewayRequest gatewayRequest,
    required TopUpSession session,
  }) {
    final payment = paymentController;
    if (payment == null) {
      return authorizeThenRun(
        request: gatewayRequest,
        run: () async => throw StateError('paymentController unbound'),
      );
    }
    return authorizeThenRun(
      request: gatewayRequest,
      run: () => payment.confirmTopUpSession(session),
    );
  }

  Future<LioSensitiveActionOutcome<WalletOperationResult>> transferWalletFunds({
    required LioGatewayRequest gatewayRequest,
    required String fromProfileId,
    required String toProfileId,
    required int amountMinor,
    required String currencyCode,
    int feeMinor = 0,
  }) {
    final payment = paymentController;
    if (payment == null) {
      return authorizeThenRun(
        request: gatewayRequest,
        run: () async => throw StateError('paymentController unbound'),
      );
    }
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => payment.handleTransfer(
            fromProfileId: fromProfileId,
            toProfileId: toProfileId,
            amountMinor: amountMinor,
            currencyCode: currencyCode,
            feeMinor: feeMinor,
          ),
    );
  }

  Future<LioSensitiveActionOutcome<WalletOperationResult>> withdrawWallet({
    required LioGatewayRequest gatewayRequest,
    required String profileId,
    required int amountMinor,
    required String currencyCode,
  }) {
    final wallet = walletManager;
    if (wallet == null) {
      return authorizeThenRun(
        request: gatewayRequest,
        run: () async => throw StateError('walletManager unbound'),
      );
    }
    return authorizeThenRun(
      request: gatewayRequest,
      run: () => wallet.withdraw(
            profileId: profileId,
            amountMinor: amountMinor,
            currencyCode: currencyCode,
          ),
    );
  }

  Future<LioSensitiveActionOutcome<BillingOutcome>> chargeAnnualSubscription({
    required LioGatewayRequest gatewayRequest,
    required HealthProfile profile,
    required String gatewayName,
  }) {
    final billing = subscriptionBillingManager;
    if (billing == null) {
      return authorizeThenRun(
        request: gatewayRequest,
        run: () async => throw StateError('subscriptionBillingManager unbound'),
      );
    }
    return authorizeThenRun(
      request: gatewayRequest,
      run: () => billing.chargeAnnualSubscription(
            profile: profile,
            gatewayName: gatewayName,
          ),
    );
  }

  Future<LioSensitiveActionOutcome<List<String>>> listBillingGateways({
    required LioGatewayRequest gatewayRequest,
    required String countryCode,
  }) {
    final billing = subscriptionBillingManager;
    if (billing == null) {
      return authorizeThenRun(
        request: gatewayRequest,
        run: () async => throw StateError('subscriptionBillingManager unbound'),
      );
    }
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => billing.availableGatewaysForCountry(countryCode),
    );
  }

  // —— SHARE ——

  Future<LioSensitiveActionOutcome<EncyclopediaShareResult>>
      sharePublicEncyclopedia({
    required LioGatewayRequest gatewayRequest,
  }) {
    final bridge = encyclopediaShareBridge ?? EncyclopediaShareBridge();
    return authorizeThenRun(
      request: gatewayRequest,
      run: () => bridge.shareEncyclopedia(),
    );
  }

  // —— EMERGENCY_ACCESS ——

  Future<LioSensitiveActionOutcome<EmergencyDispatchOutcome>>
      triggerEmergencyLimited({
    required LioGatewayRequest gatewayRequest,
    required String profileId,
    required String reasonAr,
    Map<String, dynamic>? context,
  }) {
    final emergency = emergencyManager;
    if (emergency == null) {
      return authorizeThenRun(
        request: gatewayRequest,
        run: () async => throw StateError('emergencyManager unbound'),
      );
    }
    return authorizeThenRun(
      request: gatewayRequest,
      run: () => emergency.triggerEmergency(
            profileId: profileId,
            reasonAr: reasonAr,
            context: context,
          ),
    );
  }

  // —— دورة حياة البيانات: عقود صريحة بلا نجاح وهمي ——

  /// DELETE حسّاس — منفصل عن ARCHIVE. لا محرك حذف آمن بعد.
  Future<LioSensitiveActionOutcome<LioLifecycleResult>> requestSensitiveDelete({
    required LioGatewayRequest gatewayRequest,
    LioSensitiveDataDomain domain = LioSensitiveDataDomain.patientPhr,
  }) {
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => LioLifecycleResult.notImplemented(
            opKind: LioLifecycleOpKind.delete,
            domain: domain,
            messageAr:
                'DELETE غير منفَّذ: لا طبقة حذف آمنة لبيانات المريض/PHR في هذا البناء. '
                'DELETE ≠ ARCHIVE.',
          ),
    );
  }

  /// ARCHIVE حسّاس — منفصل عن DELETE. لا مخزن أرشفة بعد.
  Future<LioSensitiveActionOutcome<LioLifecycleResult>> requestSensitiveArchive({
    required LioGatewayRequest gatewayRequest,
    LioSensitiveDataDomain domain = LioSensitiveDataDomain.patientPhr,
  }) {
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => LioLifecycleResult.notImplemented(
            opKind: LioLifecycleOpKind.archive,
            domain: domain,
            messageAr:
                'ARCHIVE غير منفَّذ: لا مخزن أرشفة آمن بعد. '
                'ARCHIVE ≠ DELETE.',
          ),
    );
  }

  /// EXPORT سريري/PHR — ليس SHARE عاماً. بلا نجاح وهمي.
  Future<LioSensitiveActionOutcome<LioLifecycleResult>>
      requestClinicalPhrExport({
    required LioGatewayRequest gatewayRequest,
  }) {
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => LioLifecycleResult.notImplemented(
            opKind: LioLifecycleOpKind.export,
            domain: LioSensitiveDataDomain.patientPhr,
            messageAr:
                'EXPORT Clinical/PHR غير منفَّذ: لا مسار تصدير آمن بعد. '
                'EXPORT ≠ SHARE العام. لا نجاح وهمي.',
          ),
    );
  }

  /// SHARE لبيانات سريرية/خاصة — منفصل عن الموسوعة العامة.
  Future<LioSensitiveActionOutcome<LioLifecycleResult>>
      requestClinicalOrPrivateShare({
    required LioGatewayRequest gatewayRequest,
    LioSensitiveDataDomain domain = LioSensitiveDataDomain.clinical,
  }) {
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => LioLifecycleResult.notImplemented(
            opKind: LioLifecycleOpKind.share,
            domain: domain,
            messageAr:
                'SHARE لبيانات سريرية/خاصة غير منفَّذ. '
                'المشاركة العامة للموسوعة مسار منفصل فقط.',
          ),
    );
  }

  /// PRINT حسّاس — لا مسار طباعة آمن.
  Future<LioSensitiveActionOutcome<LioLifecycleResult>> requestSensitivePrint({
    required LioGatewayRequest gatewayRequest,
    LioSensitiveDataDomain domain = LioSensitiveDataDomain.medicalDocument,
  }) {
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => LioLifecycleResult.unsupported(
            opKind: LioLifecycleOpKind.printOp,
            domain: domain,
            messageAr:
                'PRINT غير مدعوم في هذا البناء (UNSUPPORTED_OPERATION). '
                'لا مسار طباعة آمن لبيانات حساسة.',
          ),
    );
  }

  /// CONTROL جهاز — عقد/سياسة فقط، بلا تنفيذ سائق.
  Future<LioSensitiveActionOutcome<LioLifecycleResult>> requestDeviceControl({
    required LioGatewayRequest gatewayRequest,
  }) {
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => LioLifecycleResult.unsupported(
            opKind: LioLifecycleOpKind.control,
            domain: LioSensitiveDataDomain.deviceControl,
            messageAr:
                'Device CONTROL غير منفَّذ: سياسة/عقد فقط بلا تشغيل سائق حقيقي. '
                'DISCOVERED ≠ CONTROLABLE.',
          ),
    );
  }

  /// READ_HEALTH عبر بوابة — بلا وصول UI→Repository مباشر.
  Future<LioSensitiveActionOutcome<LioLifecycleResult>> requestHealthRead({
    required LioGatewayRequest gatewayRequest,
  }) {
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => LioLifecycleResult.notImplemented(
            opKind: LioLifecycleOpKind.readHealth,
            domain: LioSensitiveDataDomain.healthObservation,
            messageAr:
                'READ_HEALTH عبر Repository غير موصول بواجهة آمنة بعد. '
                'لا تجاوز LIO إلى HealthRepository من UI.',
          ),
    );
  }

  /// WRITE حسّاس عام — عقد حتى تُربط طبقة الكتابة الآمنة.
  Future<LioSensitiveActionOutcome<LioLifecycleResult>> requestSensitiveWrite({
    required LioGatewayRequest gatewayRequest,
    LioSensitiveDataDomain domain = LioSensitiveDataDomain.healthObservation,
  }) {
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => LioLifecycleResult.notImplemented(
            opKind: LioLifecycleOpKind.write,
            domain: domain,
            messageAr:
                'WRITE الحساس غير موصول بمسار Repository آمن بعد لهذا النطاق. '
                'لا نجاح وهمي.',
          ),
    );
  }

  /// UPDATE حسّاس عام — منفصل عن WRITE في الجرد.
  Future<LioSensitiveActionOutcome<LioLifecycleResult>> requestSensitiveUpdate({
    required LioGatewayRequest gatewayRequest,
    LioSensitiveDataDomain domain = LioSensitiveDataDomain.medicationRecord,
  }) {
    return authorizeThenRun(
      request: gatewayRequest,
      run: () async => LioLifecycleResult.notImplemented(
            opKind: LioLifecycleOpKind.update,
            domain: domain,
            messageAr:
                'UPDATE الحساس غير موصول بمسار آمن بعد لهذا النطاق. '
                'لا نجاح وهمي.',
          ),
    );
  }
}
