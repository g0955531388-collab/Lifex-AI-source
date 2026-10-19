/// =============================================================
/// Lifex-AI — اختبار شبكة الأجهزة المساعدة 69
/// الملف: assistive_devices_engine_test.dart
/// =============================================================
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/assistive_medical_devices/device_engine.dart';
import 'package:lifex_ai/core/assistive_medical_devices/device_types.dart';
import 'package:lifex_ai/core/financial/financial_types.dart';

void main() {
  test('SQL has assistive tables not patients copy', () {
    final sql = File(
      'lib/core/assistive_medical_devices/lifex_assistive_medical_devices_69_schema.sql',
    ).readAsStringSync();
    expect(sql.contains('CREATE TABLE assistive_devices'), isTrue);
    expect(sql.contains('CREATE TABLE patients'), isFalse);
  });

  test('used donate inspect match loan recall honesty', () async {
    final engine = LifexAssistiveMedicalDeviceEngine();
    expect(engine.matchingIsDiagnosis, isFalse);
    expect(engine.diseaseNameProvesMedicalFit, isFalse);
    expect(engine.usedDeviceRedistributesWithoutInspection, isFalse);
    expect(engine.registrationMakesUnknownSafe, isFalse);
    expect(engine.lifexOwnsOnRegister, isFalse);
    expect(engine.loanGrantsOwnership, isFalse);
    expect(engine.donationOpensBeneficiaryHealthRecord, isFalse);
    expect(engine.doctorSeesDonationFinanceByDefault, isFalse);
    expect(engine.assistiveDeviceIsLabResult, isFalse);
    expect(engine.consumerElectronicsAutoAssistive, isFalse);
    expect(engine.localCardIsGovernmentId, isFalse);
    expect(engine.riskSignalIsGuilt, isFalse);
    expect(engine.caregiverGetsFullHealthByDefault, isFalse);

    final phone = engine.registerDevice(
      categoryId: 'phone',
      name: 'هاتف عادي',
      countryCode: 'TR',
      classifiedAssistive: false,
    );
    expect(phone.classifiedAssistive, isFalse);

    final chair = engine.registerDevice(
      categoryId: 'wheelchair',
      name: 'كرسي يدوي',
      countryCode: 'TR',
      used: true,
      supportedNeeds: const ['mobility'],
      knowledgeDeviceId: '54-dev-chair',
    );
    expect(chair.ownershipType, DeviceOwnershipType.privateOwned);
    expect(chair.availabilityStatus, DeviceAvailabilityStatus.pendingInspection);

    final donation = engine.donateDevice(
      donorId: 'donor-secret',
      deviceId: chair.deviceId,
      anonymous: true,
    );
    expect(engine.publicDonorLabel(donation), 'فاعل خير');
    expect(donation.status, DeviceDonationStatus.awaitingInspection);

    final need = engine.createRequest(
      beneficiaryId: 'ben1',
      requiredCategories: const ['wheelchair'],
      functionalNeeds: const [],
      countryCode: 'TR',
      diseaseNameHint: 'شلل',
    );
    expect(engine.matchDevice(need.requestId).compatibility, Compatibility.unknown);
    expect(engine.matchDevice(need.requestId).isDiagnosis, isFalse);

    final mobility = engine.createRequest(
      beneficiaryId: 'ben1',
      requiredCategories: const ['wheelchair'],
      functionalNeeds: const ['mobility'],
      countryCode: 'TR',
    );
    expect(engine.matchDevice(mobility.requestId).deviceId, isNull);
    expect(engine.inspectAndApproveReuse(chair.deviceId), isTrue);
    expect(chair.availabilityStatus, DeviceAvailabilityStatus.available);

    final match = engine.matchDevice(mobility.requestId);
    expect(match.deviceId, chair.deviceId);
    expect(match.isDiagnosis, isFalse);
    expect(engine.reserveDevice(chair.deviceId, 'ben1'), isTrue);
    expect(engine.confirmDelivery(chair.deviceId, 'ben1'), isTrue);
    final assigned = engine.toPatientAssignment(
      patientId: 'pat55',
      deviceId: chair.deviceId,
    );
    expect(assigned.deviceId, chair.deviceId);

    final walker = engine.registerDevice(
      categoryId: 'walker',
      name: 'مشاية',
      countryCode: 'TR',
      ownership: DeviceOwnershipType.organizationOwned,
      supportedNeeds: const ['mobility'],
    );
    engine.inspectAndApproveReuse(walker.deviceId);
    final loan = engine.createLoan(
      deviceId: walker.deviceId,
      beneficiaryId: 'ben1',
      dueAt: DateTime.utc(2026, 12, 1),
    );
    expect(walker.ownershipType, DeviceOwnershipType.loaned);
    expect(engine.loanGrantsOwnership, isFalse);
    engine.returnLoan(loan.loanId);
    expect(walker.availabilityStatus, DeviceAvailabilityStatus.pendingInspection);

    final recalled = engine.registerDevice(
      categoryId: 'hearing',
      name: 'سماعة',
      countryCode: 'TR',
      supportedNeeds: const ['hearing'],
    );
    engine.inspectAndApproveReuse(recalled.deviceId);
    engine.reportRecall(recalled.deviceId);
    expect(recalled.availabilityStatus, DeviceAvailabilityStatus.quarantined);
    final hearing = engine.createRequest(
      beneficiaryId: 'ben2',
      requiredCategories: const ['hearing'],
      functionalNeeds: const ['hearing'],
      countryCode: 'TR',
    );
    expect(engine.matchDevice(hearing.requestId).deviceId, isNull);
    expect(engine.inspectAndApproveReuse(recalled.deviceId), isFalse);

    expect(
      await engine.fundRepair(
        amountMinor: 4000,
        idempotencyKey: 'FIX-1',
        partyId: 'donor-secret',
      ),
      isNot(PaymentStatus.succeeded),
    );

    final card = engine.issueLocalCard(memberId: 'LFX-MEMBER-1', countryCode: 'TR');
    expect(card.governmentIdentity, isFalse);
    expect(card.showsDiagnoses, isFalse);
    expect(engine.unusualRepeatRequestSignal(8), isTrue);
    expect(engine.riskSignalIsGuilt, isFalse);
  });
}
