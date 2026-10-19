/// =============================================================
/// Lifex-AI — تبرعات 66
/// الحملة ≠ التبرع ≠ الدفع ≠ القيد ≠ الصرف ≠ الاستخدام الطبي.
/// =============================================================
library lifex_ai.core.global_donations.donation_types;
enum CampaignStatus {
  draft,
  underReview,
  verified,
  published,
  active,
  paused,
  targetReached,
  cancelled,
  suspended,
  completed,
}

enum DonorVisibility { publicName, anonymous, alias, organizationName }

enum DonationKind66 {
  oneTime,
  recurring,
  pledge,
  anonymous,
  designated,
  unrestricted,
  inKind,
  medical,
}

enum DonationRecordStatus {
  intent,
  paymentPending,
  confirmed,
  failed,
  refunded,
  cancelled,
}

enum DisbursementStatus {
  requested,
  underReview,
  approved,
  processing,
  completed,
  rejected,
  held,
}

enum AllocationPurpose { medicine, device, hospital, unrestricted, emergency }

class DonationCampaign {
  DonationCampaign({
    required this.campaignId,
    required this.organizerId,
    required this.beneficiaryId,
    required this.title,
    required this.targetMinor,
    required this.currency,
    this.status = CampaignStatus.draft,
    this.verified = false,
    this.exposesFullHealthRecord = false,
    this.needCategory = DonationNeedCategory.other,
    this.locationArea = '',
    this.visibility = DonationVisibility.public,
  });

  final String campaignId;
  final String organizerId;
  final String beneficiaryId;
  final String title;
  final int targetMinor;
  final String currency;
  CampaignStatus status;
  bool verified;
  final bool exposesFullHealthRecord;
  final DonationNeedCategory needCategory;
  final String locationArea;
  final DonationVisibility visibility;
  int raisedMinor = 0;
  int disbursedMinor = 0;
}

class DonationIntentRecord {
  const DonationIntentRecord({
    required this.intentId,
    required this.donorId,
    required this.campaignId,
    required this.amountMinor,
    required this.currency,
    required this.idempotencyKey,
    required this.visibility,
    this.designation = AllocationPurpose.unrestricted,
    this.status = DonationRecordStatus.intent,
  });

  final String intentId;
  final String donorId;
  final String campaignId;
  final int amountMinor;
  final String currency;
  final String idempotencyKey;
  final DonorVisibility visibility;
  final AllocationPurpose designation;
  final DonationRecordStatus status;
}

class CampaignDonationRecord {
  const CampaignDonationRecord({
    required this.donationId,
    required this.intentId,
    required this.donorId,
    required this.campaignId,
    required this.amountMinor,
    required this.currency,
    required this.visibility,
    required this.status,
    this.paymentIntentId,
    this.financialDonationId,
    this.kind = DonationKind66.oneTime,
  });

  final String donationId;
  final String intentId;
  final String donorId;
  final String campaignId;
  final int amountMinor;
  final String currency;
  final DonorVisibility visibility;
  final DonationRecordStatus status;
  final String? paymentIntentId;
  final String? financialDonationId;
  final DonationKind66 kind;
}

class PledgeRecord {
  const PledgeRecord({
    required this.pledgeId,
    required this.donorId,
    required this.campaignId,
    required this.amountMinor,
    this.fulfilled = false,
  });

  final String pledgeId;
  final String donorId;
  final String campaignId;
  final int amountMinor;
  final bool fulfilled;
}

class DonationAllocation {
  const DonationAllocation({
    required this.allocationId,
    required this.donationId,
    required this.purpose,
    required this.amountMinor,
  });

  final String allocationId;
  final String donationId;
  final AllocationPurpose purpose;
  final int amountMinor;
}

class DonationDisbursement {
  DonationDisbursement({
    required this.disbursementId,
    required this.campaignId,
    required this.amountMinor,
    required this.requesterId,
    this.status = DisbursementStatus.requested,
    this.approverId,
    this.paymentConfirmed = false,
  });

  final String disbursementId;
  final String campaignId;
  final int amountMinor;
  final String requesterId;
  DisbursementStatus status;
  String? approverId;
  bool paymentConfirmed;
}

class DonationReceipt {
  const DonationReceipt({
    required this.receiptId,
    required this.donationId,
    required this.amountMinor,
    required this.currency,
    required this.issuedAt,
    this.taxDeductibleAssumed = false,
  });

  final String receiptId;
  final String donationId;
  final int amountMinor;
  final String currency;
  final DateTime issuedAt;
  final bool taxDeductibleAssumed;
}

class CampaignTransparency {
  const CampaignTransparency({
    required this.targetMinor,
    required this.raisedMinor,
    required this.disbursedMinor,
    required this.donationCount,
    required this.verified,
  });

  final int targetMinor;
  final int raisedMinor;
  final int disbursedMinor;
  final int donationCount;
  final bool verified;
}

enum MedicalShareScope {
  none,
  minimumVerification,
  selectedDocuments,
  authorizedSummary,
}

enum RecurrencePeriod { weekly, monthly, quarterly, yearly }

enum InKindCategory {
  medicalDevice,
  wheelchair,
  prosthesis,
  orthosis,
  medicine,
  supplies,
  food,
  assistiveTechnology,
  other,
}

/// فئة احتياج للتبرع — ليست تشخيصاً من PatientCondition.
enum DonationNeedCategory {
  cancer,
  cardiovascular,
  children,
  rareDisease,
  disability,
  assistiveDevices,
  wheelchair,
  prosthetics,
  rehabilitation,
  medicine,
  medicalSupplies,
  homeCare,
  palliative,
  elderly,
  emergencyAccident,
  research,
  laboratories,
  hospitals,
  healthCenters,
  blood,
  therapeuticFood,
  healthEducation,
  community,
  other,
}

enum DonationVisibility {
  public,
  authorizedProgram,
  consentedPublic,
  private,
}

enum DonationPartySource {
  selfAccount,
  phoneContact,
  callLog,
  sms,
  lifexDirectory,
  campaign,
  organization,
  manual,
}

class DonationBeneficiaryProfile {
  const DonationBeneficiaryProfile({
    required this.beneficiaryId,
    required this.displayName,
    required this.needCategory,
    required this.visibility,
    required this.supportedDonationTypes,
    this.personId,
    this.identityId,
    this.alias,
    this.campaignId,
    this.needDescription = '',
    this.locationArea = '',
    this.urgency = 'normal',
    this.requestedAmountMinor,
    this.requestedItems = const [],
    this.verificationStatus = 'unverified',
    this.consentGranted = false,
    this.expiresAt,
    this.provenance = DonationPartySource.lifexDirectory,
  });

  final String beneficiaryId;
  final String? personId;
  final String? identityId;
  final String displayName;
  final String? alias;
  final String? campaignId;
  final DonationNeedCategory needCategory;
  final String needDescription;
  final String locationArea;
  final String urgency;
  final int? requestedAmountMinor;
  final List<String> requestedItems;
  final List<String> supportedDonationTypes;
  final String verificationStatus;
  final DonationVisibility visibility;
  final bool consentGranted;
  final DateTime? expiresAt;
  final DonationPartySource provenance;

  bool get isSearchablePublic =>
      consentGranted &&
      (visibility == DonationVisibility.public ||
          visibility == DonationVisibility.consentedPublic ||
          visibility == DonationVisibility.authorizedProgram);

  String spokenAr() {
    final a = alias ?? displayName;
    return '$a. فئة ${needCategory.name}. '
        '${locationArea.isEmpty ? '' : 'المنطقة $locationArea. '}'
        'الاستعجال $urgency.';
  }
}

class DonationFeeQuote {
  const DonationFeeQuote({
    required this.donationAmountMinor,
    required this.feeMinor,
    required this.totalChargedMinor,
    required this.netToRecipientMinor,
    required this.currency,
    required this.feeOnDonor,
    required this.feePolicyId,
    required this.feePolicyVersion,
    required this.disclosed,
  });

  final int donationAmountMinor;
  final int feeMinor;
  final int totalChargedMinor;
  final int netToRecipientMinor;
  final String currency;
  final bool feeOnDonor;
  final String feePolicyId;
  final String feePolicyVersion;
  final bool disclosed;

  String spokenAr() =>
      'التبرع $donationAmountMinor، الرسوم $feeMinor، '
      'الإجمالي $totalChargedMinor، صافي للمستفيد $netToRecipientMinor '
      '($currency، أصغر وحدة).';
}

class RecurringDonationPlan {
  RecurringDonationPlan({
    required this.planId,
    required this.donorId,
    required this.campaignId,
    required this.amountMinor,
    required this.period,
    required this.paymentMethodToken,
    this.suspended = false,
  });

  final String planId;
  final String donorId;
  final String campaignId;
  final int amountMinor;
  final RecurrencePeriod period;
  final String paymentMethodToken;
  bool suspended;
}

class InKindDonationRecord {
  const InKindDonationRecord({
    required this.donationId,
    required this.donorId,
    required this.beneficiaryId,
    required this.category,
    required this.description,
    this.condition = 'unknown',
    this.medicallyCleared = false,
  });

  final String donationId;
  final String donorId;
  final String beneficiaryId;
  final InKindCategory category;
  final String description;
  final String condition;
  /// AI لا يقرر الملاءمة الطبية نهائياً.
  final bool medicallyCleared;
}

class MatchingDonationLink {
  const MatchingDonationLink({
    required this.originalDonationId,
    required this.matchingSourceId,
    required this.ratio,
    required this.maxMatchMinor,
  });

  final String originalDonationId;
  final String matchingSourceId;
  final int ratio;
  final int maxMatchMinor;
}

class GrantApplication {
  GrantApplication({
    required this.grantId,
    required this.organizationId,
    required this.amountMinor,
    this.approved = false,
  });

  final String grantId;
  final String organizationId;
  final int amountMinor;
  bool approved;
}

class DonationConsent {
  const DonationConsent({
    required this.consentId,
    required this.subjectId,
    required this.scope,
    required this.granted,
  });

  final String consentId;
  final String subjectId;
  final MedicalShareScope scope;
  final bool granted;
}

class AiCampaignSummary {
  const AiCampaignSummary({
    required this.campaignId,
    required this.text,
    required this.modelVersion,
    required this.generatedAt,
    this.generatedBy = 'AI',
    this.humanReviewStatus = 'pending',
    this.isClinicalReport = false,
  });

  final String campaignId;
  final String text;
  final String modelVersion;
  final DateTime generatedAt;
  final String generatedBy;
  final String humanReviewStatus;
  final bool isClinicalReport;
}

class OfflineDonationQueueItem {
  const OfflineDonationQueueItem({
    required this.idempotencyKey,
    required this.donorId,
    required this.campaignId,
    required this.amountMinor,
  });

  final String idempotencyKey;
  final String donorId;
  final String campaignId;
  final int amountMinor;
}
