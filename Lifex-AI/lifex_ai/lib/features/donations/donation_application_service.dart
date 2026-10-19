/// =============================================================
/// Lifex-AI — تطبيق التبرعات (يربط المحرك 66 + المحفظة + الرسوم)
/// الملف: donation_application_service.dart
/// =============================================================
library lifex_ai.features.donations.donation_application_service;

import '../../core/financial/financial_types.dart';
import '../../core/global_donations/donation_engine.dart';
import '../../core/global_donations/donation_types.dart';
import '../finance/transaction_ledger.dart';
import '../finance/wallet_manager.dart';
import '../trusted_person/trusted_person_models.dart';
import 'donation_beneficiary_directory.dart';

class DonationOutcome {
  const DonationOutcome({
    required this.ok,
    required this.messageAr,
    this.donationId,
    this.receipt,
    this.quote,
  });

  final bool ok;
  final String messageAr;
  final String? donationId;
  final DonationReceipt? receipt;
  final DonationFeeQuote? quote;
}

class DonationPartySelection {
  const DonationPartySelection({
    required this.partyId,
    required this.displayName,
    required this.source,
    this.phone,
    this.identityId,
  });

  final String partyId;
  final String displayName;
  final DonationPartySource source;
  final String? phone;
  final String? identityId;
}

class LifexDonationApplicationService {
  LifexDonationApplicationService({
    LifexGlobalDonationsEngine? engine,
    DonationBeneficiaryDirectory? directory,
    WalletManager? wallet,
    FeePolicy? transferFeePolicy,
    DonationIntentParser? intentParser,
  })  : engine = engine ?? LifexGlobalDonationsEngine(),
        directory = directory ?? DonationBeneficiaryDirectory(),
        wallet = wallet,
        transferFeePolicy = transferFeePolicy ??
            const FeePolicy(
              id: 'donation_transfer',
              transactionType: 'donation_transfer',
              version: 'v1',
              percentage: 0,
              fixedMinorAmount: 200,
              donationFeePermittedByPolicy: true,
              enabled: true,
            ),
        intentParser = intentParser ?? const DonationIntentParser();

  final LifexGlobalDonationsEngine engine;
  final DonationBeneficiaryDirectory directory;
  final WalletManager? wallet;
  final FeePolicy transferFeePolicy;
  final DonationIntentParser intentParser;
  final audits = <String>[];

  DonationFeeQuote quoteFinancial({
    required int donationAmountMinor,
    String currency = 'USD',
    bool feeOnDonor = true,
  }) {
    final feeAllowed = transferFeePolicy.enabled &&
        transferFeePolicy.donationFeePermittedByPolicy;
    final fee = feeAllowed ? transferFeePolicy.feeOn(donationAmountMinor) : 0;
    final total = feeOnDonor ? donationAmountMinor + fee : donationAmountMinor;
    final net = feeOnDonor
        ? donationAmountMinor
        : (donationAmountMinor - fee).clamp(0, donationAmountMinor);
    return DonationFeeQuote(
      donationAmountMinor: donationAmountMinor,
      feeMinor: fee,
      totalChargedMinor: total,
      netToRecipientMinor: net,
      currency: currency,
      feeOnDonor: feeOnDonor,
      feePolicyId: transferFeePolicy.id,
      feePolicyVersion: transferFeePolicy.version,
      disclosed: true,
    );
  }

  List<DonationBeneficiaryProfile> searchByVoiceOrText(String raw) {
    final need = intentParser.parseNeedCategory(raw);
    String? location;
    final locMatch = RegExp(r'في\s+(\S+)').firstMatch(raw);
    if (locMatch != null) location = locMatch.group(1);
    return directory.search(
      DonationSearchQuery(
        needCategory: need,
        locationContains: location,
        nameContains: need == null ? raw : null,
        verifiedOnly: true,
      ),
    );
  }

  DonationPartySelection donorFromSelf(String profileId, String name) {
    return DonationPartySelection(
      partyId: profileId,
      displayName: name,
      source: DonationPartySource.selfAccount,
    );
  }

  DonationPartySelection partyFromPhoneContact({
    required PersonSelectionCandidate candidate,
  }) {
    return DonationPartySelection(
      partyId: 'phone_${candidate.phoneNumber ?? candidate.displayName}',
      displayName: candidate.displayName,
      source: DonationPartySource.phoneContact,
      phone: candidate.phoneNumber,
      identityId: candidate.identityId,
    );
  }

  Future<DonationOutcome> donateFinancialFromWallet({
    required String donorProfileId,
    required String beneficiaryId,
    required int donationAmountMinor,
    required String idempotencyKey,
    String currency = 'USD',
    bool userConfirmedQuote = false,
    DonationNeedCategory? needCategory,
  }) async {
    if (donationAmountMinor <= 0) {
      return const DonationOutcome(
        ok: false,
        messageAr: 'قيمة التبرع غير صالحة.',
      );
    }
    if (wallet == null) {
      return const DonationOutcome(
        ok: false,
        messageAr: 'المحفظة غير مربوطة. لا يمكن خصم رصيد.',
      );
    }
    final quote = quoteFinancial(
      donationAmountMinor: donationAmountMinor,
      currency: currency,
    );
    if (!userConfirmedQuote) {
      return DonationOutcome(
        ok: false,
        messageAr: 'يلزم تأكيد الرسوم أولاً. ${quote.spokenAr()}',
        quote: quote,
      );
    }

    final ben = directory.byId(beneficiaryId);
    if (ben == null || !ben.isSearchablePublic) {
      return const DonationOutcome(
        ok: false,
        messageAr:
            'المستفيد غير ظاهر للتبرع العام. يلزم موافقة/برنامج مصرّح.',
      );
    }

    final pay = wallet!.payFromBalance(
      profileId: donorProfileId,
      amountInSmallestUnit: quote.totalChargedMinor,
      currencyCode: currency,
      type: TransactionType.donationPayment,
      relatedEntityId: beneficiaryId,
    );
    if (!pay.success) {
      return DonationOutcome(ok: false, messageAr: pay.messageAr, quote: quote);
    }

    final campaign = engine.createCampaign(
      organizerId: donorProfileId,
      beneficiaryId: beneficiaryId,
      title: ben.alias ?? ben.displayName,
      targetMinor: ben.requestedAmountMinor ?? donationAmountMinor,
      currency: currency,
      needCategory: needCategory ?? ben.needCategory,
      locationArea: ben.locationArea,
      visibility: ben.visibility,
    );
    engine.verifyAndPublish(campaign.campaignId);

    final intent = engine.createIntent(
      donorId: donorProfileId,
      campaignId: campaign.campaignId,
      amountMinor: quote.netToRecipientMinor,
      idempotencyKey: idempotencyKey,
      currency: currency,
    );

    final rec = await engine.processDonation(intent.intentId);
    // مسار المحفظة: الإيصال بعد خصم الرصيد — لا ادعاء مزود بطاقة.
    final receipt = DonationReceipt(
      receiptId: 'rc_wallet_${rec.donationId}',
      donationId: rec.donationId,
      amountMinor: quote.netToRecipientMinor,
      currency: currency,
      issuedAt: DateTime.now().toUtc(),
    );
    engine.receipts[rec.donationId] = receipt;
    engine.allocations[rec.donationId] = DonationAllocation(
      allocationId: 'al_${rec.donationId}',
      donationId: rec.donationId,
      purpose: AllocationPurpose.unrestricted,
      amountMinor: quote.netToRecipientMinor,
    );
    campaign.raisedMinor += quote.netToRecipientMinor;
    audits.add('wallet_donation:${rec.donationId}:fee=${quote.feeMinor}');

    return DonationOutcome(
      ok: true,
      messageAr:
          'تم تنفيذ التبرع من المحفظة. ${quote.spokenAr()} '
          'رقم الإيصال ${receipt.receiptId}.',
      donationId: rec.donationId,
      receipt: receipt,
      quote: quote,
    );
  }

  Future<DonationOutcome> acceptInKindDevice({
    required String donorId,
    required String beneficiaryId,
    required InKindCategory category,
    required String description,
    String condition = 'unknown',
  }) async {
    final ben = directory.byId(beneficiaryId);
    if (ben == null || !ben.isSearchablePublic) {
      return const DonationOutcome(
        ok: false,
        messageAr: 'المستفيد غير متاح للتبرع العيني العام.',
      );
    }
    if (category == InKindCategory.medicine) {
      return const DonationOutcome(
        ok: false,
        messageAr:
            'التبرع بالدواء يخضع لمسار قانوني/تنظيمي منفصل. لم يُنفَّذ تلقائياً.',
      );
    }
    final rec = engine.acceptInKind(
      donorId: donorId,
      beneficiaryId: beneficiaryId,
      category: category,
      description: description,
    );
    audits.add('inkind:${rec.donationId}');
    return DonationOutcome(
      ok: true,
      messageAr:
          'سُجّل تبرع عيني (${category.name}). الملاءمة الطبية ليست قرار AI. '
          'الحالة: $condition.',
      donationId: rec.donationId,
    );
  }
}
