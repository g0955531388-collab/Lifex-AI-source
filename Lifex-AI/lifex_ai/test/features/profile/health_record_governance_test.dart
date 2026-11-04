import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/profile/health_record_governance.dart';

class _Verifier implements HealthDeletionVerifier {
  _Verifier(this.verified);
  final bool verified;
  @override
  Future<bool> verifyOwnership({
    required String profileId,
    required HealthDeletionChannel channel,
    required String registeredContact,
  }) async => verified;
}

class _Backup implements HealthRecordBackupPort {
  bool exists = false;
  @override
  Future<void> createImmutableBackup({
    required String recordId,
    required String profileId,
    required Map<String, dynamic> payload,
  }) async {
    exists = true;
  }
  @override
  Future<bool> hasImmutableBackup(String recordId) async => exists;
}

class _Notifier implements AccreditedUnitNotifier {
  bool notified = false;
  @override
  Future<void> notifyDeletionRequested({
    required String recordId,
    required String profileId,
  }) async {
    notified = true;
  }
}

class _Access implements AccreditedUnitAccessPort {
  _Access(this.allowed);
  final bool allowed;
  @override
  Future<bool> canReceiveHealthRecord({
    required String profileId,
    required String unitId,
  }) async => allowed;
}

void main() {
  test('unverified deletion leaves the health record untouched', () async {
    final backup = _Backup();
    final notifier = _Notifier();
    final governance = HealthRecordGovernance(
      verifier: _Verifier(false),
      backup: backup,
      notifier: notifier,
      access: _Access(true),
    )..registerRecord(
        recordId: 'record-1',
        profileId: 'patient-1',
        payload: {'diagnosis': 'example'},
      );

    final result = await governance.requestDeletion(
      recordId: 'record-1',
      channel: HealthDeletionChannel.email,
      registeredContact: 'patient@example.test',
    );

    expect(result, HealthDeletionResult.ownershipNotVerified);
    expect(governance.record('record-1')!.lifecycle, HealthRecordLifecycle.active);
    expect(backup.exists, isFalse);
    expect(notifier.notified, isFalse);
  });

  test('deletion requires verification, backup and unit notification', () async {
    final backup = _Backup();
    final notifier = _Notifier();
    final governance = HealthRecordGovernance(
      verifier: _Verifier(true),
      backup: backup,
      notifier: notifier,
      access: _Access(true),
    )..registerRecord(
        recordId: 'record-2',
        profileId: 'patient-2',
        payload: {'lab': {'value': 12}},
      );

    final result = await governance.requestDeletion(
      recordId: 'record-2',
      channel: HealthDeletionChannel.phone,
      registeredContact: '+10000000000',
    );

    expect(result, HealthDeletionResult.deleted);
    expect(backup.exists, isTrue);
    expect(notifier.notified, isTrue);
    expect(governance.record('record-2')!.lifecycle, HealthRecordLifecycle.deleted);
    expect(governance.record('record-2')!.payload['lab'], {'value': 12});
  });

  test('unit copies are immutable but accept separate comments', () async {
    final governance = HealthRecordGovernance(
      verifier: _Verifier(true),
      backup: _Backup(),
      notifier: _Notifier(),
      access: _Access(true),
    )..registerRecord(
        recordId: 'record-3',
        profileId: 'patient-3',
        payload: {'measurements': [1, 2]},
      );

    final copy = await governance.createReadOnlyCopy(
      recordId: 'record-3',
      requestingUnitId: 'hospital-1',
    );
    expect(
      () => (copy.payload['measurements'] as List).add(3),
      throwsUnsupportedError,
    );
    copy.addComment(
      requestingUnitId: 'hospital-1',
      text: 'Reviewed by the receiving unit',
    );
    expect(copy.comments, hasLength(1));
    expect(governance.record('record-3')!.payload['measurements'], [1, 2]);
  });

  test('archived health record can be reopened', () {
    final governance = HealthRecordGovernance(
      verifier: _Verifier(true),
      backup: _Backup(),
      notifier: _Notifier(),
      access: _Access(true),
    )..registerRecord(
        recordId: 'record-4',
        profileId: 'patient-4',
        payload: {'note': 'follow-up'},
      );

    governance.archive('record-4');
    expect(governance.record('record-4')!.lifecycle, HealthRecordLifecycle.archived);
    governance.reopen('record-4');
    expect(governance.record('record-4')!.lifecycle, HealthRecordLifecycle.active);
    expect(governance.record('record-4')!.reopenedAt, isNotNull);
  });
}
