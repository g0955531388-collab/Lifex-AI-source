/// Governance lifecycle for sensitive health records.
///
/// Real OTP verification, immutable cloud backup, and accredited-unit
/// notification are mandatory backend ports. No local-only implementation
/// is presented as a cloud security control.
import '../../../core/health_event_manager.dart';

enum HealthRecordLifecycle { active, archived, deleted }
enum HealthDeletionChannel { email, phone }

Map<String, dynamic> _freezeMap(Map<String, dynamic> source) =>
    Map<String, dynamic>.unmodifiable(
      source.map((key, value) => MapEntry(key, _freezeValue(value))),
    );

dynamic _freezeValue(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.map((key, nested) =>
          MapEntry(key.toString(), _freezeValue(nested))),
    );
  }
  if (value is List) {
    return List<dynamic>.unmodifiable(value.map(_freezeValue));
  }
  return value;
}

abstract interface class AccreditedUnitAccessPort {
  Future<bool> canReceiveHealthRecord({
    required String profileId,
    required String unitId,
  });
}

abstract interface class HealthDeletionVerifier {
  /// Must perform a fresh OTP challenge against the registered contact.
  Future<bool> verifyOwnership({
    required String profileId,
    required HealthDeletionChannel channel,
    required String registeredContact,
  });
}

abstract interface class HealthRecordBackupPort {
  /// Must persist an immutable, encrypted server-side backup.
  Future<void> createImmutableBackup({
    required String recordId,
    required String profileId,
    required Map<String, dynamic> payload,
  });

  Future<bool> hasImmutableBackup(String recordId);
}

abstract interface class AccreditedUnitNotifier {
  /// Must resolve and notify every currently authorized accredited unit.
  Future<void> notifyDeletionRequested({
    required String recordId,
    required String profileId,
  });
}

class HealthRecordComment {
  final String commentId;
  final String unitId;
  final String text;
  final DateTime createdAt;

  HealthRecordComment({
    required this.commentId,
    required this.unitId,
    required this.text,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class ReadOnlyHealthRecordCopy {
  ReadOnlyHealthRecordCopy({
    required this.copyId,
    required this.sourceRecordId,
    required this.profileId,
    required this.unitId,
    required Map<String, dynamic> payload,
  }) : payload = _freezeMap(payload);

  final String copyId;
  final String sourceRecordId;
  final String profileId;
  final String unitId;
  final Map<String, dynamic> payload;
  final List<HealthRecordComment> _comments = [];

  List<HealthRecordComment> get comments => List.unmodifiable(_comments);

  void addComment({
    required String requestingUnitId,
    required String text,
  }) {
    if (requestingUnitId != unitId) {
      throw StateError('Only the receiving unit may annotate its copy');
    }
    final normalized = text.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Comment cannot be empty');
    }
    _comments.add(HealthRecordComment(
      commentId: 'HRC-${DateTime.now().microsecondsSinceEpoch}',
      unitId: unitId,
      text: normalized,
    ));
  }
}

class HealthRecordGovernanceEntry {
  HealthRecordGovernanceEntry({
    required this.recordId,
    required this.profileId,
    required Map<String, dynamic> payload,
    this.lifecycle = HealthRecordLifecycle.active,
  }) : payload = _freezeMap(payload);

  final String recordId;
  final String profileId;
  final Map<String, dynamic> payload;
  HealthRecordLifecycle lifecycle;
  DateTime? archivedAt;
  DateTime? reopenedAt;
  DateTime? deletedAt;
}

enum HealthDeletionResult {
  deleted,
  notFound,
  alreadyDeleted,
  invalidContact,
  ownershipNotVerified,
  backupFailed,
  notificationFailed,
}

class HealthRecordGovernance {
  HealthRecordGovernance({
    required HealthDeletionVerifier verifier,
    required HealthRecordBackupPort backup,
    required AccreditedUnitNotifier notifier,
    required AccreditedUnitAccessPort access,
  })  : _verifier = verifier,
        _backup = backup,
        _notifier = notifier,
        _access = access;

  final HealthDeletionVerifier _verifier;
  final HealthRecordBackupPort _backup;
  final AccreditedUnitNotifier _notifier;
  final AccreditedUnitAccessPort _access;
  final Map<String, HealthRecordGovernanceEntry> _records = {};
  final Map<String, ReadOnlyHealthRecordCopy> _copies = {};

  List<HealthRecordGovernanceEntry> get records =>
      List.unmodifiable(_records.values);
  List<ReadOnlyHealthRecordCopy> get copies =>
      List.unmodifiable(_copies.values);

  void registerRecord({
    required String recordId,
    required String profileId,
    required Map<String, dynamic> payload,
  }) {
    if (recordId.trim().isEmpty || profileId.trim().isEmpty) {
      throw ArgumentError('recordId and profileId are required');
    }
    if (_records.containsKey(recordId)) {
      throw StateError('Health record already registered');
    }
    _records[recordId] = HealthRecordGovernanceEntry(
      recordId: recordId,
      profileId: profileId,
      payload: payload,
    );
  }

  HealthRecordGovernanceEntry? record(String recordId) => _records[recordId];

  void archive(String recordId) {
    final entry = _requireActive(recordId);
    entry.lifecycle = HealthRecordLifecycle.archived;
    entry.archivedAt = DateTime.now();
    HealthEventManager.instance.emitQuick(
      HealthEventType.profileUpdated,
      sourceModule: 'health_record_governance',
      profileId: entry.profileId,
      data: {'recordId': recordId, 'lifecycle': 'archived'},
    );
  }

  void reopen(String recordId) {
    final entry = _records[recordId];
    if (entry == null || entry.lifecycle != HealthRecordLifecycle.archived) {
      throw StateError('Only archived health records can be reopened');
    }
    entry.lifecycle = HealthRecordLifecycle.active;
    entry.reopenedAt = DateTime.now();
    HealthEventManager.instance.emitQuick(
      HealthEventType.profileUpdated,
      sourceModule: 'health_record_governance',
      profileId: entry.profileId,
      data: {'recordId': recordId, 'lifecycle': 'reopened'},
    );
  }

  Future<ReadOnlyHealthRecordCopy> createReadOnlyCopy({
    required String recordId,
    required String requestingUnitId,
  }) async {
    final entry = _records[recordId];
    if (entry == null || entry.lifecycle == HealthRecordLifecycle.deleted) {
      throw StateError('Health record is unavailable');
    }
    if (!await _access.canReceiveHealthRecord(
      profileId: entry.profileId,
      unitId: requestingUnitId,
    )) {
      throw StateError('Requesting unit is not accredited or authorized');
    }
    final copy = ReadOnlyHealthRecordCopy(
      copyId: 'HRCOPY-${DateTime.now().microsecondsSinceEpoch}',
      sourceRecordId: recordId,
      profileId: entry.profileId,
      unitId: requestingUnitId,
      payload: entry.payload,
    );
    _copies[copy.copyId] = copy;
    return copy;
  }

  Future<HealthDeletionResult> requestDeletion({
    required String recordId,
    required HealthDeletionChannel channel,
    required String registeredContact,
  }) async {
    final entry = _records[recordId];
    if (entry == null) return HealthDeletionResult.notFound;
    if (entry.lifecycle == HealthRecordLifecycle.deleted) {
      return HealthDeletionResult.alreadyDeleted;
    }
    if (registeredContact.trim().isEmpty) {
      return HealthDeletionResult.invalidContact;
    }

    final verified = await _verifier.verifyOwnership(
      profileId: entry.profileId,
      channel: channel,
      registeredContact: registeredContact.trim(),
    );
    if (!verified) return HealthDeletionResult.ownershipNotVerified;

    try {
      await _backup.createImmutableBackup(
        recordId: recordId,
        profileId: entry.profileId,
        payload: entry.payload,
      );
      if (!await _backup.hasImmutableBackup(recordId)) {
        return HealthDeletionResult.backupFailed;
      }
    } catch (_) {
      return HealthDeletionResult.backupFailed;
    }

    try {
      await _notifier.notifyDeletionRequested(
        recordId: recordId,
        profileId: entry.profileId,
      );
    } catch (_) {
      return HealthDeletionResult.notificationFailed;
    }

    // Soft-delete only: retain the source payload and immutable backup.
    entry.lifecycle = HealthRecordLifecycle.deleted;
    entry.deletedAt = DateTime.now();
    HealthEventManager.instance.emitQuick(
      HealthEventType.profileUpdated,
      sourceModule: 'health_record_governance',
      profileId: entry.profileId,
      data: {'recordId': recordId, 'lifecycle': 'deleted'},
    );
    return HealthDeletionResult.deleted;
  }

  HealthRecordGovernanceEntry _requireActive(String recordId) {
    final entry = _records[recordId];
    if (entry == null || entry.lifecycle != HealthRecordLifecycle.active) {
      throw StateError('Health record is not active');
    }
    return entry;
  }
}
