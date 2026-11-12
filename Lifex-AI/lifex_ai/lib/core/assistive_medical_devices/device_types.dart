/// =============================================================
/// Lifex-AI — أجهزة مساعدة 69
/// الجهاز ≠ الملكية ≠ التبرع ≠ الحاجة ≠ الملاءمة ≠ التسليم ≠ السجل الصحي.
/// =============================================================
library lifex_ai.core.assistive_medical_devices.device_types;

enum DeviceAvailabilityStatus {
  registered,
  pendingInspection,
  underInspection,
  available,
  reserved,
  assigned,
  loaned,
  donated,
  recalled,
  quarantined,
  retired,
  returned,
}

enum DeviceCondition { unknown, notInspected, inspected, requiresRepair, approvedForReuse, notApprovedForReuse }

enum DeviceSafetyStatus { unknown, notInspected, safetyVerified, recalled, restrictedUse }

enum DeviceOwnershipType {
  privateOwned,
  organizationOwned,
  charityOwned,
  lifexCustody,
  loaned,
  donated,
  unknown,
}

enum Compatibility { compatible, partiallyCompatible, requiresFitting, notCompatible, unknown }

enum DonationKind69 { device, accessory, repairSupport, transportSupport, financialSupport }

enum DeviceDonationStatus {
  submitted,
  awaitingInspection,
  approved,
  matched,
  delivered,
  completed,
  rejected,
}

enum UrgencyLevel { routine, soon, urgent }

class AssistiveMedicalDevice {
  AssistiveMedicalDevice({
    required this.deviceId,
    required this.categoryId,
    required this.name,
    required this.countryCode,
    required this.ownershipType,
    this.knowledgeDeviceId,
    this.serialNumber,
    this.classifiedAssistive = true,
    this.availabilityStatus = DeviceAvailabilityStatus.registered,
    this.condition = DeviceCondition.notInspected,
    this.safetyStatus = DeviceSafetyStatus.notInspected,
    this.supportedNeeds = const [],
    this.used = false,
  });

  final String deviceId;
  final String? knowledgeDeviceId;
  final String categoryId;
  final String name;
  final String countryCode;
  DeviceOwnershipType ownershipType;
  final String? serialNumber;
  final bool classifiedAssistive;
  DeviceAvailabilityStatus availabilityStatus;
  DeviceCondition condition;
  DeviceSafetyStatus safetyStatus;
  final List<String> supportedNeeds;
  final bool used;
}

class AssistiveDeviceDonation {
  AssistiveDeviceDonation({
    required this.donationId,
    required this.donorId,
    required this.deviceId,
    required this.type,
    this.status = DeviceDonationStatus.submitted,
    this.donorWantsAnonymity = false,
    this.campaignId,
  });

  final String donationId;
  final String donorId;
  final String deviceId;
  final DonationKind69 type;
  DeviceDonationStatus status;
  final bool donorWantsAnonymity;
  final String? campaignId;
}

class AssistiveDeviceRequest {
  const AssistiveDeviceRequest({
    required this.requestId,
    required this.beneficiaryId,
    required this.requiredCategories,
    required this.functionalNeeds,
    required this.countryCode,
    this.urgency = UrgencyLevel.routine,
    this.requiresProfessionalAssessment = false,
    this.diseaseNameHint,
  });

  final String requestId;
  final String beneficiaryId;
  final List<String> requiredCategories;
  final List<String> functionalNeeds;
  final String countryCode;
  final UrgencyLevel urgency;
  final bool requiresProfessionalAssessment;
  final String? diseaseNameHint;
}

class DeviceMatchingResult {
  const DeviceMatchingResult({
    required this.deviceId,
    required this.compatibility,
    this.isDiagnosis = false,
    this.medicallySuitableFromDiseaseName = false,
  });

  final String? deviceId;
  final Compatibility compatibility;
  final bool isDiagnosis;
  final bool medicallySuitableFromDiseaseName;
}

class DeviceLoan {
  DeviceLoan({
    required this.loanId,
    required this.deviceId,
    required this.beneficiaryId,
    required this.dueAt,
    this.returned = false,
  });

  final String loanId;
  final String deviceId;
  final String beneficiaryId;
  final DateTime dueAt;
  bool returned;
}

class LocalAssistiveCareCard {
  const LocalAssistiveCareCard({
    required this.cardId,
    required this.memberId,
    required this.countryCode,
    required this.cardNumber,
    this.showsDiagnoses = false,
    this.governmentIdentity = false,
  });

  final String cardId;
  final String memberId;
  final String countryCode;
  final String cardNumber;
  final bool showsDiagnoses;
  final bool governmentIdentity;
}
