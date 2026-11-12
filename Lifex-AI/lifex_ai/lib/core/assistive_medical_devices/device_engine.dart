/// =============================================================
/// Lifex-AI — محرك الأجهزة المساعدة 69
/// المستعمل لا يُوزَّع قبل الفحص. المطابقة ليست تشخيصاً. المال عبر 51.
/// =============================================================
library lifex_ai.core.assistive_medical_devices.device_engine;

import '../financial/financial_engine.dart';
import '../financial/financial_types.dart';
import '../personal_family_health/personal_health_types.dart';
import 'device_types.dart';

class LifexAssistiveMedicalDeviceEngine {
  LifexAssistiveMedicalDeviceEngine({LifexFinancialEngine? financial})
      : financial = financial ?? LifexFinancialEngine();

  final LifexFinancialEngine financial;
  final devices = <String, AssistiveMedicalDevice>{};
  final donations = <String, AssistiveDeviceDonation>{};
  final requests = <String, AssistiveDeviceRequest>{};
  final loans = <String, DeviceLoan>{};
  final custody = <String>[];
  final audits = <String>[];
  var _n = 0;

  bool get matchingIsDiagnosis => false;
  bool get diseaseNameProvesMedicalFit => false;
  bool get usedDeviceRedistributesWithoutInspection => false;
  bool get registrationMakesUnknownSafe => false;
  bool get lifexOwnsOnRegister => false;
  bool get loanGrantsOwnership => false;
  bool get donationOpensBeneficiaryHealthRecord => false;
  bool get doctorSeesDonationFinanceByDefault => false;
  bool get assistiveDeviceIsLabResult => false;
  bool get consumerElectronicsAutoAssistive => false;
  bool get localCardIsGovernmentId => false;
  bool get riskSignalIsGuilt => false;
  bool get caregiverGetsFullHealthByDefault => false;

  AssistiveMedicalDevice registerDevice({
    required String categoryId,
    required String name,
    required String countryCode,
    DeviceOwnershipType ownership = DeviceOwnershipType.privateOwned,
    List<String> supportedNeeds = const [],
    bool used = false,
    bool classifiedAssistive = true,
    String? knowledgeDeviceId,
    String? serialNumber,
  }) {
    _n++;
    final d = AssistiveMedicalDevice(
      deviceId: 'amd$_n',
      knowledgeDeviceId: knowledgeDeviceId,
      categoryId: categoryId,
      name: name,
      countryCode: countryCode,
      ownershipType: ownership,
      serialNumber: serialNumber,
      classifiedAssistive: classifiedAssistive,
      availabilityStatus: used
          ? DeviceAvailabilityStatus.pendingInspection
          : DeviceAvailabilityStatus.registered,
      condition: used ? DeviceCondition.notInspected : DeviceCondition.unknown,
      supportedNeeds: supportedNeeds,
      used: used,
    );
    devices[d.deviceId] = d;
    custody.add('registered:${d.deviceId}:${ownership.name}');
    return d;
  }

  AssistiveDeviceDonation donateDevice({
    required String donorId,
    required String deviceId,
    bool anonymous = false,
    DonationKind69 type = DonationKind69.device,
  }) {
    _n++;
    final donation = AssistiveDeviceDonation(
      donationId: 'dd$_n',
      donorId: donorId,
      deviceId: deviceId,
      type: type,
      donorWantsAnonymity: anonymous,
      status: DeviceDonationStatus.awaitingInspection,
    );
    donations[donation.donationId] = donation;
    final device = devices[deviceId];
    if (device != null && device.used) {
      device.availabilityStatus = DeviceAvailabilityStatus.pendingInspection;
    }
    audits.add('donation_submitted:${donation.donationId}');
    return donation;
  }

  String publicDonorLabel(AssistiveDeviceDonation d) {
    if (d.donorWantsAnonymity) return 'فاعل خير';
    return d.donorId;
  }

  bool inspectAndApproveReuse(String deviceId) {
    final d = devices[deviceId];
    if (d == null) return false;
    if (d.safetyStatus == DeviceSafetyStatus.recalled) return false;
    d.condition = DeviceCondition.approvedForReuse;
    d.safetyStatus = DeviceSafetyStatus.safetyVerified;
    d.availabilityStatus = DeviceAvailabilityStatus.available;
    custody.add('approved:$deviceId');
    for (final don in donations.values.where((x) => x.deviceId == deviceId)) {
      don.status = DeviceDonationStatus.approved;
    }
    return true;
  }

  void reportRecall(String deviceId) {
    final d = devices[deviceId];
    if (d == null) return;
    d.safetyStatus = DeviceSafetyStatus.recalled;
    d.availabilityStatus = DeviceAvailabilityStatus.quarantined;
    audits.add('recall:$deviceId');
  }

  AssistiveDeviceRequest createRequest({
    required String beneficiaryId,
    required List<String> requiredCategories,
    required List<String> functionalNeeds,
    required String countryCode,
    String? diseaseNameHint,
    bool requiresProfessionalAssessment = false,
  }) {
    _n++;
    final r = AssistiveDeviceRequest(
      requestId: 'rq$_n',
      beneficiaryId: beneficiaryId,
      requiredCategories: requiredCategories,
      functionalNeeds: functionalNeeds,
      countryCode: countryCode,
      diseaseNameHint: diseaseNameHint,
      requiresProfessionalAssessment: requiresProfessionalAssessment,
    );
    requests[r.requestId] = r;
    return r;
  }

  DeviceMatchingResult matchDevice(String requestId) {
    final req = requests[requestId]!;
    if (req.diseaseNameHint != null && req.functionalNeeds.isEmpty) {
      return const DeviceMatchingResult(
        deviceId: null,
        compatibility: Compatibility.unknown,
      );
    }
    AssistiveMedicalDevice? hit;
    for (final d in devices.values) {
      if (!d.classifiedAssistive) continue;
      if (d.availabilityStatus != DeviceAvailabilityStatus.available) continue;
      if (d.safetyStatus == DeviceSafetyStatus.recalled) continue;
      if (d.used && d.condition != DeviceCondition.approvedForReuse) continue;
      if (!req.requiredCategories.contains(d.categoryId)) continue;
      final overlap = d.supportedNeeds.any(req.functionalNeeds.contains);
      if (!overlap) continue;
      hit = d;
      break;
    }
    if (hit == null) {
      return const DeviceMatchingResult(
        deviceId: null,
        compatibility: Compatibility.notCompatible,
      );
    }
    if (req.requiresProfessionalAssessment) {
      return DeviceMatchingResult(
        deviceId: hit.deviceId,
        compatibility: Compatibility.requiresFitting,
      );
    }
    return DeviceMatchingResult(
      deviceId: hit.deviceId,
      compatibility: Compatibility.compatible,
    );
  }

  bool reserveDevice(String deviceId, String beneficiaryId) {
    final d = devices[deviceId];
    if (d == null || d.availabilityStatus != DeviceAvailabilityStatus.available) {
      return false;
    }
    d.availabilityStatus = DeviceAvailabilityStatus.reserved;
    custody.add('reserved:$deviceId:$beneficiaryId');
    return true;
  }

  bool confirmDelivery(String deviceId, String beneficiaryId) {
    final d = devices[deviceId];
    if (d == null || d.availabilityStatus != DeviceAvailabilityStatus.reserved) {
      return false;
    }
    d.availabilityStatus = DeviceAvailabilityStatus.assigned;
    d.ownershipType = DeviceOwnershipType.donated;
    custody.add('delivered:$deviceId:$beneficiaryId');
    for (final don in donations.values.where((x) => x.deviceId == deviceId)) {
      don.status = DeviceDonationStatus.delivered;
    }
    return true;
  }

  PatientDevice toPatientAssignment({
    required String patientId,
    required String deviceId,
  }) {
    _n++;
    return PatientDevice(
      patientDeviceId: 'pd$_n',
      patientId: patientId,
      deviceId: deviceId,
      relationship: 'assistive',
      linkedAt: DateTime.now().toUtc(),
    );
  }

  DeviceLoan createLoan({
    required String deviceId,
    required String beneficiaryId,
    required DateTime dueAt,
  }) {
    final d = devices[deviceId]!;
    d.availabilityStatus = DeviceAvailabilityStatus.loaned;
    d.ownershipType = DeviceOwnershipType.loaned;
    _n++;
    final loan = DeviceLoan(
      loanId: 'ln$_n',
      deviceId: deviceId,
      beneficiaryId: beneficiaryId,
      dueAt: dueAt,
    );
    loans[loan.loanId] = loan;
    return loan;
  }

  bool returnLoan(String loanId) {
    final loan = loans[loanId];
    if (loan == null) return false;
    loan.returned = true;
    final d = devices[loan.deviceId]!;
    d.availabilityStatus = DeviceAvailabilityStatus.pendingInspection;
    d.condition = DeviceCondition.notInspected;
    d.ownershipType = DeviceOwnershipType.organizationOwned;
    custody.add('returned:${loan.deviceId}');
    return true;
  }

  Future<PaymentStatus> fundRepair({
    required int amountMinor,
    required String idempotencyKey,
    required String partyId,
  }) async {
    final pay = await financial.createPayment(
      amountMinor: amountMinor,
      currency: 'USD',
      idempotencyKey: idempotencyKey,
      kind: MoneyKind.donation,
      partyId: partyId,
    );
    return pay.status;
  }

  LocalAssistiveCareCard issueLocalCard({
    required String memberId,
    required String countryCode,
  }) {
    _n++;
    return LocalAssistiveCareCard(
      cardId: 'ac$_n',
      memberId: memberId,
      countryCode: countryCode,
      cardNumber: 'AC$_n',
    );
  }

  bool unusualRepeatRequestSignal(int count) => count >= 8;
}
