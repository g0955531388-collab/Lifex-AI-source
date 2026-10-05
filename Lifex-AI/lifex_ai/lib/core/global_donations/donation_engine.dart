/// =============================================================
/// Lifex-AI — محرك التبرعات 66
/// الدفع عبر 51. المخاطر عبر 53. التبرع لا يفتح الملف الصحي.
/// =============================================================
library lifex_ai.core.global_donations.donation_engine;
import '../financial/financial_engine.dart';
import '../financial/financial_types.dart';
import '../financial_protection/financial_protection.dart';
import 'donation_providers.dart';
import 'donation_types.dart';

class FinancialDonationPaymentAdapter implements DonationPaymentAdapter {
  FinancialDonationPaymentAdapter(this.financial);
  final LifexFinancialEngine financial;

  @override
  Future<PaymentIntent> createPayment({
    required int amountMinor,
    required String currency,
    required String idempotencyKey,
    required String partyId,
  }) {
    return financial.createPayment(
      amountMinor: amountMinor,
      currency: currency,
      idempotencyKey: idempotencyKey,
      kind: MoneyKind.donation,
      partyId: partyId,
    );
  }

  @override
  PaymentStatus confirmWebhook({
    required String paymentId,
    required String payload,
    required String signature,
  }) {
    return financial.applyWebhook(
      paymentId: paymentId,
      claimed: PaymentStatus.succeeded,
      payload: payload,
      signature: signature,
    );
  }
}

class MemoryDonationRepository {
  final campaigns = <String, DonationCampaign>{};
  final donations = <String, CampaignDonationRecord>{};

  Future<void> saveCampaign(DonationCampaign campaign) async {
    campaigns[campaign.campaignId] = campaign;
  }

  Future<DonationCampaign?> getCampaign(String campaignId) async =>
      campaigns[campaignId];

  Future<void> saveDonation(CampaignDonationRecord donation) async {
    donations[donation.donationId] = donation;
  }
}

class LifexGlobalDonationsEngine {
  LifexGlobalDonationsEngine({
    LifexFinancialEngine? financial,
    FinancialProtectionEngine? protection,
  }) : protection = protection ?? FinancialProtectionEngine() {
    this.financial = financial ??
        LifexFinancialEngine(protection: this.protection);
    payments = FinancialDonationPaymentAdapter(this.financial);
  }

  late final LifexFinancialEngine financial;
  final FinancialProtectionEngine protection;
  late final DonationPaymentAdapter payments;
  final repository = MemoryDonationRepository();

  final campaigns = <String, DonationCampaign>{};
  final intents = <String, DonationIntentRecord>{};
  final donations = <String, CampaignDonationRecord>{};
  final byIdempotency = <String, String>{};
  final pledges = <String, PledgeRecord>{};
  final allocations = <String, DonationAllocation>{};
  final disbursements = <String, DonationDisbursement>{};
  final receipts = <String, DonationReceipt>{};
  final recurring = <String, RecurringDonationPlan>{};
  final inKind = <String, InKindDonationRecord>{};
  final matches = <String, MatchingDonationLink>{};
  final grants = <String, GrantApplication>{};
  final consents = <String, DonationConsent>{};
  final offlineQueue = <OfflineDonationQueueItem>[];
  final audits = <String>[];
  var _n = 0;

  bool get donationEqualsPayment => false;
  bool get paymentEqualsLedger => false;
  bool get disbursementEqualsExpenditure => false;
  bool get expenditureEqualsClinicalOutcome => false;
  bool get donationGrantsHealthRecord => false;
  bool get taxDeductibleByDefault => false;
  bool get riskSignalIsGuilt => false;
  bool get storesCardPan => false;
  bool get emergencySkipsApprovals => false;
  bool get aiMayApproveDisbursement => false;
  bool get fhirIsInternalModel => false;

  DonationCampaign createCampaign({
    required String organizerId,
    required String beneficiaryId,
    required String title,
    required int targetMinor,
    String currency = 'USD',
    DonationNeedCategory needCategory = DonationNeedCategory.other,
    String locationArea = '',
    DonationVisibility visibility = DonationVisibility.public,
  }) {
    _n++;
    final c = DonationCampaign(
      campaignId: 'cmp$_n',
      organizerId: organizerId,
      beneficiaryId: beneficiaryId,
      title: title,
      targetMinor: targetMinor,
      currency: currency,
      needCategory: needCategory,
      locationArea: locationArea,
      visibility: visibility,
    );
    campaigns[c.campaignId] = c;
    repository.saveCampaign(c);
    audits.add('campaign_created:${c.campaignId}');
    return c;
  }

  void verifyAndPublish(String campaignId) {
    final c = campaigns[campaignId];
    if (c == null) return;
    c.verified = true;
    c.status = CampaignStatus.active;
    audits.add('campaign_published:$campaignId');
  }

  PledgeRecord pledge({
    required String donorId,
    required String campaignId,
    required int amountMinor,
  }) {
    _n++;
    final p = PledgeRecord(
      pledgeId: 'pl$_n',
      donorId: donorId,
      campaignId: campaignId,
      amountMinor: amountMinor,
    );
    pledges[p.pledgeId] = p;
    return p;
  }

  DonationIntentRecord createIntent({
    required String donorId,
    required String campaignId,
    required int amountMinor,
    required String idempotencyKey,
    DonorVisibility visibility = DonorVisibility.anonymous,
    AllocationPurpose designation = AllocationPurpose.unrestricted,
    String currency = 'USD',
  }) {
    if (byIdempotency.containsKey(idempotencyKey)) {
      return intents[byIdempotency[idempotencyKey]]!;
    }
    _n++;
    final intent = DonationIntentRecord(
      intentId: 'di$_n',
      donorId: donorId,
      campaignId: campaignId,
      amountMinor: amountMinor,
      currency: currency,
      idempotencyKey: idempotencyKey,
      visibility: visibility,
      designation: designation,
    );
    intents[intent.intentId] = intent;
    byIdempotency[idempotencyKey] = intent.intentId;
    return intent;
  }

  Future<CampaignDonationRecord> processDonation(String intentId) async {
    final intent = intents[intentId]!;
    final existing = donations.values.where((d) => d.intentId == intentId);
    if (existing.isNotEmpty) return existing.first;

    final pay = await payments.createPayment(
      amountMinor: intent.amountMinor,
      currency: intent.currency,
      idempotencyKey: intent.idempotencyKey,
      partyId: intent.donorId,
    );
    final fin = financial.createDonation(
      campaignId: intent.campaignId,
      amountMinor: intent.amountMinor,
      currency: intent.currency,
      feeDisclosedToDonor: true,
    );
    _n++;
    final rec = CampaignDonationRecord(
      donationId: 'dn$_n',
      intentId: intentId,
      donorId: intent.donorId,
      campaignId: intent.campaignId,
      amountMinor: intent.amountMinor,
      currency: intent.currency,
      visibility: intent.visibility,
      status: pay.status == PaymentStatus.succeeded
          ? DonationRecordStatus.confirmed
          : DonationRecordStatus.paymentPending,
      paymentIntentId: pay.id,
      financialDonationId: fin.id,
      kind: intent.visibility == DonorVisibility.anonymous
          ? DonationKind66.anonymous
          : DonationKind66.oneTime,
    );
    _storeDonation(rec);
    return rec;
  }

  CampaignDonationRecord confirmDonation({
    required String donationId,
    required String payload,
    required String signature,
  }) {
    final current = donations[donationId]!;
    final payId = current.paymentIntentId;
    if (payId == null) return current;
    final status = payments.confirmWebhook(
      paymentId: payId,
      payload: payload,
      signature: signature,
    );
    if (status != PaymentStatus.succeeded) return current;
    final alreadyConfirmed = current.status == DonationRecordStatus.confirmed;
    final confirmed = CampaignDonationRecord(
      donationId: current.donationId,
      intentId: current.intentId,
      donorId: current.donorId,
      campaignId: current.campaignId,
      amountMinor: current.amountMinor,
      currency: current.currency,
      visibility: current.visibility,
      status: DonationRecordStatus.confirmed,
      paymentIntentId: current.paymentIntentId,
      financialDonationId: current.financialDonationId,
      kind: current.kind,
    );
    _storeDonation(confirmed);
    final campaign = campaigns[confirmed.campaignId];
    if (campaign != null && !alreadyConfirmed) {
      campaign.raisedMinor += confirmed.amountMinor;
    }
    final intent = intents[confirmed.intentId];
    allocations[confirmed.donationId] = DonationAllocation(
      allocationId: 'al${confirmed.donationId}',
      donationId: confirmed.donationId,
      purpose: intent?.designation ?? AllocationPurpose.unrestricted,
      amountMinor: confirmed.amountMinor,
    );
    receipts[confirmed.donationId] = DonationReceipt(
      receiptId: 'rc${confirmed.donationId}',
      donationId: confirmed.donationId,
      amountMinor: confirmed.amountMinor,
      currency: confirmed.currency,
      issuedAt: DateTime.now().toUtc(),
    );
    audits.add('donation_confirmed:$donationId');
    return confirmed;
  }

  void _storeDonation(CampaignDonationRecord rec) {
    donations[rec.donationId] = rec;
    repository.saveDonation(rec);
    audits.add('donation:${rec.donationId}:${rec.status.name}');
  }

  String publicDonorLabel(CampaignDonationRecord d) {
    if (d.visibility == DonorVisibility.anonymous) return 'فاعل خير';
    return d.donorId;
  }

  bool mayRevealDonorToBeneficiary(CampaignDonationRecord d) =>
      d.visibility == DonorVisibility.publicName;

  bool mayOpenPatientRecordFromDonation(String donationId) => false;

  RecurringDonationPlan? startRecurring({
    required String donorId,
    required String campaignId,
    required int amountMinor,
    required String paymentMethodToken,
    RecurrencePeriod period = RecurrencePeriod.monthly,
  }) {
    if (paymentMethodToken.contains('cvv') ||
        RegExp(r'^\d{13,19}$').hasMatch(paymentMethodToken.replaceAll(' ', ''))) {
      return null;
    }
    _n++;
    final p = RecurringDonationPlan(
      planId: 'rd$_n',
      donorId: donorId,
      campaignId: campaignId,
      amountMinor: amountMinor,
      period: period,
      paymentMethodToken: paymentMethodToken,
    );
    recurring[p.planId] = p;
    return p;
  }

  void failRecurringPayment(String planId) {
    recurring[planId]?.suspended = true;
    audits.add('recurring_payment_failed:$planId');
  }

  InKindDonationRecord acceptInKind({
    required String donorId,
    required String beneficiaryId,
    required InKindCategory category,
    required String description,
  }) {
    _n++;
    final d = InKindDonationRecord(
      donationId: 'ik$_n',
      donorId: donorId,
      beneficiaryId: beneficiaryId,
      category: category,
      description: description,
    );
    inKind[d.donationId] = d;
    return d;
  }

  MatchingDonationLink recordMatch({
    required String originalDonationId,
    required String matchingSourceId,
    int ratio = 1,
    required int maxMatchMinor,
  }) {
    final link = MatchingDonationLink(
      originalDonationId: originalDonationId,
      matchingSourceId: matchingSourceId,
      ratio: ratio,
      maxMatchMinor: maxMatchMinor,
    );
    matches[originalDonationId] = link;
    return link;
  }

  GrantApplication applyGrant({
    required String organizationId,
    required int amountMinor,
  }) {
    _n++;
    final g = GrantApplication(
      grantId: 'gr$_n',
      organizationId: organizationId,
      amountMinor: amountMinor,
    );
    grants[g.grantId] = g;
    return g;
  }

  DonationDisbursement requestDisbursement({
    required String campaignId,
    required int amountMinor,
    required String requesterId,
  }) {
    _n++;
    final d = DonationDisbursement(
      disbursementId: 'ds$_n',
      campaignId: campaignId,
      amountMinor: amountMinor,
      requesterId: requesterId,
    );
    disbursements[d.disbursementId] = d;
    audits.add('disbursement_requested:${d.disbursementId}');
    return d;
  }

  bool approveDisbursement({
    required String disbursementId,
    required String approverId,
    bool emergency = false,
  }) {
    final d = disbursements[disbursementId];
    if (d == null) return false;
    if (d.requesterId == approverId) return false;
    if (emergency && emergencySkipsApprovals) return false;
    d.approverId = approverId;
    d.status = DisbursementStatus.approved;
    audits.add('disbursement_approved:$disbursementId');
    return true;
  }

  Future<bool> executeDisbursement(String disbursementId) async {
    final d = disbursements[disbursementId];
    if (d == null || d.status != DisbursementStatus.approved) return false;
    if (aiMayApproveDisbursement) return false;
    final pay = await payments.createPayment(
      amountMinor: d.amountMinor,
      currency: 'USD',
      idempotencyKey: 'disb_$disbursementId',
      partyId: d.requesterId,
    );
    d.paymentConfirmed = pay.status == PaymentStatus.succeeded;
    if (!d.paymentConfirmed) {
      d.status = DisbursementStatus.processing;
      return false;
    }
    d.status = DisbursementStatus.completed;
    campaigns[d.campaignId]?.disbursedMinor += d.amountMinor;
    return true;
  }

  void suspendCampaign(String campaignId, String reason) {
    final c = campaigns[campaignId];
    if (c == null) return;
    c.status = CampaignStatus.suspended;
    for (final d in disbursements.values.where((x) => x.campaignId == campaignId)) {
      if (d.status != DisbursementStatus.completed) {
        d.status = DisbursementStatus.held;
      }
    }
    audits.add('campaign_suspended:$campaignId:$reason');
  }

  ProtectionResult screenDonor(String donorId, int amountMinor) {
    return protection.screen(
      partyId: donorId,
      amountMinor: amountMinor,
      kind: MoneyKind.donation,
    );
  }

  CampaignTransparency transparency(String campaignId) {
    final c = campaigns[campaignId]!;
    final count = donations.values
        .where((d) =>
            d.campaignId == campaignId &&
            d.status == DonationRecordStatus.confirmed)
        .length;
    return CampaignTransparency(
      targetMinor: c.targetMinor,
      raisedMinor: c.raisedMinor,
      disbursedMinor: c.disbursedMinor,
      donationCount: count,
      verified: c.verified,
    );
  }

  bool designatedMayBeUsedFor(
    AllocationPurpose allowed,
    AllocationPurpose requested,
  ) {
    if (allowed == AllocationPurpose.unrestricted) return true;
    return allowed == requested;
  }

  void grantConsent(DonationConsent consent) {
    consents[consent.subjectId] = consent;
  }

  MedicalShareScope medicalShareFor(String subjectId) {
    return consents[subjectId]?.scope ?? MedicalShareScope.none;
  }

  AiCampaignSummary aiSummary(String campaignId) {
    return AiCampaignSummary(
      campaignId: campaignId,
      text: 'ملخص آلي غير سريري',
      modelVersion: 'test-1',
      generatedAt: DateTime.now().toUtc(),
    );
  }

  void enqueueOffline(OfflineDonationQueueItem item) {
    offlineQueue.add(item);
  }

  bool get offlineQueueCompletesPayment => false;

  List<DonationCampaign> search({
    bool verifiedOnly = false,
    DonationNeedCategory? needCategory,
    String? locationContains,
  }) {
    var rows = campaigns.values.toList();
    if (verifiedOnly) {
      rows = rows.where((c) => c.verified).toList();
    }
    if (needCategory != null) {
      rows = rows.where((c) => c.needCategory == needCategory).toList();
    }
    if (locationContains != null && locationContains.trim().isNotEmpty) {
      final q = locationContains.trim().toLowerCase();
      rows = rows
          .where((c) => c.locationArea.toLowerCase().contains(q))
          .toList();
    }
    return rows;
  }
}

class LifexDonationNetwork {
  LifexDonationNetwork({LifexGlobalDonationsEngine? engine})
      : engine = engine ?? LifexGlobalDonationsEngine();

  final LifexGlobalDonationsEngine engine;

  Future<DonationCampaign> createCampaign({
    required String organizerId,
    required String beneficiaryId,
    required String title,
    required int targetMinor,
  }) async {
    return engine.createCampaign(
      organizerId: organizerId,
      beneficiaryId: beneficiaryId,
      title: title,
      targetMinor: targetMinor,
    );
  }

  Future<DonationIntentRecord> createDonation(DonationIntentRecord request) async {
    return engine.createIntent(
      donorId: request.donorId,
      campaignId: request.campaignId,
      amountMinor: request.amountMinor,
      idempotencyKey: request.idempotencyKey,
      visibility: request.visibility,
      designation: request.designation,
      currency: request.currency,
    );
  }
}
