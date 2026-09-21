/// =============================================================
/// Lifex-AI — فهرس اعتماد مفاتيح HealthObservation
/// keyId → envelopes/records (metadata فقط — بلا plaintext / secrets)
/// =============================================================
library lifex_ai.core.health_data.health_observation_key_reference_index;

import 'dart:convert';
import 'dart:io';

import 'health_observation_cipher.dart';
import 'health_observation_key_lifecycle.dart';
import 'health_observation_repository.dart';

/// حالة مرجع صريحة.
enum HealthObservationKeyReferenceStatus {
  /// Envelope أو سجل يعتمد على المفتاح.
  active,

  /// سجل مؤرشف — ما زال يعتمد على المفتاح (ARCHIVE ≠ حذف مرجع).
  archivedRecord,
}

/// Metadata إثبات اعتماد — بلا DEK / plaintext / ciphertext كامل.
class HealthObservationKeyReference {
  const HealthObservationKeyReference({
    required this.keyId,
    required this.envelopeId,
    required this.formatVersion,
    required this.status,
    required this.updatedAt,
    this.recordId,
    this.contentFingerprint,
  });

  final String keyId;
  final String envelopeId;
  final String? recordId;
  final String formatVersion;
  final HealthObservationKeyReferenceStatus status;
  final String? contentFingerprint;
  final DateTime updatedAt;

  String get referenceKey {
    final r = recordId;
    if (r == null || r.isEmpty) return 'env:$envelopeId';
    return 'rec:$envelopeId:$r';
  }

  Map<String, dynamic> toJson() => {
        'keyId': keyId,
        'envelopeId': envelopeId,
        if (recordId != null) 'recordId': recordId,
        'formatVersion': formatVersion,
        'status': status.name,
        if (contentFingerprint != null)
          'contentFingerprint': contentFingerprint,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory HealthObservationKeyReference.fromJson(Map<String, dynamic> json) {
    return HealthObservationKeyReference(
      keyId: json['keyId']?.toString() ?? '',
      envelopeId: json['envelopeId']?.toString() ?? '',
      recordId: json['recordId']?.toString(),
      formatVersion: json['formatVersion']?.toString() ?? '',
      status: HealthObservationKeyReferenceStatus.values.firstWhere(
        (e) => e.name == json['status']?.toString(),
        orElse: () => HealthObservationKeyReferenceStatus.active,
      ),
      contentFingerprint: json['contentFingerprint']?.toString(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

/// أنواع عدم اتساق الفهرس — لا تُخفى كـ "لا توجد مراجع".
enum HealthObservationKeyIndexInconsistencyKind {
  missingReference,
  orphanReference,
  wrongKeyId,
  duplicateReference,
  staleReference,
}

class HealthObservationKeyIndexInconsistency {
  const HealthObservationKeyIndexInconsistency({
    required this.kind,
    required this.message,
    this.envelopeId,
    this.keyId,
  });

  final HealthObservationKeyIndexInconsistencyKind kind;
  final String message;
  final String? envelopeId;
  final String? keyId;
}

class HealthObservationKeyIndexConsistencyReport {
  const HealthObservationKeyIndexConsistencyReport({
    required this.consistent,
    required this.issues,
  });

  final bool consistent;
  final List<HealthObservationKeyIndexInconsistency> issues;
}

class HealthObservationKeyIndexRebuildResult {
  const HealthObservationKeyIndexRebuildResult({
    required this.success,
    required this.envelopeReferenced,
    required this.recordCount,
    required this.consistency,
  });

  final bool success;
  final bool envelopeReferenced;
  final int recordCount;
  final HealthObservationKeyIndexConsistencyReport consistency;
}

/// فهرس غير متسق — يمنع REVOKE / ARCHIVE / PURGE.
class HealthObservationKeyIndexInconsistentException implements Exception {
  HealthObservationKeyIndexInconsistentException({
    required this.reasonCode,
    required this.message,
    required this.issues,
  });

  static const reasonCodeValue = 'INDEX_INCONSISTENT';

  final String reasonCode;
  final String message;
  final List<HealthObservationKeyIndexInconsistency> issues;

  @override
  String toString() =>
      'HealthObservationKeyIndexInconsistentException($reasonCode): $message';
}

/// مصدر موثوق لاعتماد المفاتيح — ليس Canonical Owner للـ HealthObservation.
abstract class HealthObservationKeyReferenceIndex {
  static const indexId = 'HealthObservationKeyReferenceIndex';
  static const canonicalEnvelopeId = 'canonical_store_envelope';

  Future<bool> hasReferences(String keyId);

  Future<List<HealthObservationKeyReference>> referencesFor(String keyId);

  Future<List<HealthObservationKeyReference>> allReferences();

  /// بعد WRITE / UPDATE ناجح — envelope + سجلات (معرفات فقط).
  Future<void> upsertAfterPersist({
    required String keyId,
    required String envelopeId,
    required String formatVersion,
    required String contentFingerprint,
    required Map<String, HealthObservationKeyReferenceStatus> recordStatuses,
  });

  /// نقل مرجع المغلف بعد Rotation ناجحة بالكامل.
  Future<void> moveEnvelopeReference({
    required String envelopeId,
    required String fromKeyId,
    required String toKeyId,
    required String formatVersion,
    required String contentFingerprint,
  });

  /// حذف مرجع سجل بعد DELETE ناجح للبيانات.
  Future<void> removeRecordReference({
    required String envelopeId,
    required String recordId,
  });

  /// حذف كل مراجع المغلف عند اختفاء ciphertext.
  Future<void> clearEnvelopeReferences(String envelopeId);

  Future<HealthObservationKeyIndexConsistencyReport> verifyConsistency({
    required HealthObservationPersistentStore cipherTextInner,
    AesGcmHealthObservationCipher? cipher,
  });

  /// يضمن الاتساق أو يرمي INDEX_INCONSISTENT — لا يُرجع false صامتاً.
  Future<void> requireConsistent({
    required HealthObservationPersistentStore cipherTextInner,
    AesGcmHealthObservationCipher? cipher,
  });

  Future<HealthObservationKeyIndexRebuildResult> rebuildFromStore({
    required HealthObservationPersistentStore cipherTextInner,
    required HealthObservationKeyLifecycle lifecycle,
    required AesGcmHealthObservationCipher cipher,
  });
}

/// تنفيذ في الذاكرة — اختبارات / افتراضي غير ملفّي.
class InMemoryHealthObservationKeyReferenceIndex
    implements HealthObservationKeyReferenceIndex {
  InMemoryHealthObservationKeyReferenceIndex({
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final DateTime Function() _clock;
  final Map<String, HealthObservationKeyReference> _byRefKey = {};

  @override
  Future<List<HealthObservationKeyReference>> allReferences() async =>
      _byRefKey.values.toList();

  @override
  Future<List<HealthObservationKeyReference>> referencesFor(
    String keyId,
  ) async {
    return _byRefKey.values.where((r) => r.keyId == keyId).toList();
  }

  @override
  Future<bool> hasReferences(String keyId) async {
    return _byRefKey.values.any((r) => r.keyId == keyId);
  }

  @override
  Future<void> upsertAfterPersist({
    required String keyId,
    required String envelopeId,
    required String formatVersion,
    required String contentFingerprint,
    required Map<String, HealthObservationKeyReferenceStatus> recordStatuses,
  }) async {
    final now = _clock();
    final env = HealthObservationKeyReference(
      keyId: keyId,
      envelopeId: envelopeId,
      formatVersion: formatVersion,
      status: HealthObservationKeyReferenceStatus.active,
      contentFingerprint: contentFingerprint,
      updatedAt: now,
    );
    _byRefKey[env.referenceKey] = env;

    // أزل سجلات لم تعد في الحمولة لهذا المغلف.
    final obsolete = _byRefKey.entries
        .where(
          (e) =>
              e.value.envelopeId == envelopeId &&
              e.value.recordId != null &&
              !recordStatuses.containsKey(e.value.recordId),
        )
        .map((e) => e.key)
        .toList();
    for (final k in obsolete) {
      _byRefKey.remove(k);
    }

    for (final entry in recordStatuses.entries) {
      final rec = HealthObservationKeyReference(
        keyId: keyId,
        envelopeId: envelopeId,
        recordId: entry.key,
        formatVersion: formatVersion,
        status: entry.value,
        contentFingerprint: contentFingerprint,
        updatedAt: now,
      );
      _byRefKey[rec.referenceKey] = rec;
    }
  }

  @override
  Future<void> moveEnvelopeReference({
    required String envelopeId,
    required String fromKeyId,
    required String toKeyId,
    required String formatVersion,
    required String contentFingerprint,
  }) async {
    final now = _clock();
    final updates = <String, HealthObservationKeyReference>{};
    final removals = <String>[];
    for (final e in _byRefKey.entries) {
      if (e.value.envelopeId != envelopeId) continue;
      if (e.value.keyId != fromKeyId) continue;
      removals.add(e.key);
      final moved = HealthObservationKeyReference(
        keyId: toKeyId,
        envelopeId: e.value.envelopeId,
        recordId: e.value.recordId,
        formatVersion: formatVersion,
        status: e.value.status,
        contentFingerprint: contentFingerprint,
        updatedAt: now,
      );
      updates[moved.referenceKey] = moved;
    }
    for (final k in removals) {
      _byRefKey.remove(k);
    }
    _byRefKey.addAll(updates);
    // تأكد من وجود مرجع مغلف على المفتاح الجديد.
    final envKey = 'env:$envelopeId';
    if (!_byRefKey.containsKey(envKey)) {
      _byRefKey[envKey] = HealthObservationKeyReference(
        keyId: toKeyId,
        envelopeId: envelopeId,
        formatVersion: formatVersion,
        status: HealthObservationKeyReferenceStatus.active,
        contentFingerprint: contentFingerprint,
        updatedAt: now,
      );
    }
  }

  @override
  Future<void> removeRecordReference({
    required String envelopeId,
    required String recordId,
  }) async {
    _byRefKey.remove('rec:$envelopeId:$recordId');
  }

  @override
  Future<void> clearEnvelopeReferences(String envelopeId) async {
    final keys = _byRefKey.entries
        .where((e) => e.value.envelopeId == envelopeId)
        .map((e) => e.key)
        .toList();
    for (final k in keys) {
      _byRefKey.remove(k);
    }
  }

  @override
  Future<HealthObservationKeyIndexConsistencyReport> verifyConsistency({
    required HealthObservationPersistentStore cipherTextInner,
    AesGcmHealthObservationCipher? cipher,
  }) {
    return HealthObservationKeyReferenceIndexSupport.verify(
      indexEntries: _byRefKey.values.toList(),
      cipherTextInner: cipherTextInner,
      cipher: cipher ?? AesGcmHealthObservationCipher(),
    );
  }

  @override
  Future<void> requireConsistent({
    required HealthObservationPersistentStore cipherTextInner,
    AesGcmHealthObservationCipher? cipher,
  }) async {
    final report = await verifyConsistency(
      cipherTextInner: cipherTextInner,
      cipher: cipher,
    );
    if (!report.consistent) {
      throw HealthObservationKeyIndexInconsistentException(
        reasonCode:
            HealthObservationKeyIndexInconsistentException.reasonCodeValue,
        message:
            'فهرس اعتماد المفاتيح غير متسق — ممنوع REVOKE/ARCHIVE/PURGE '
            'حتى rebuild/repair آمن.',
        issues: report.issues,
      );
    }
  }

  @override
  Future<HealthObservationKeyIndexRebuildResult> rebuildFromStore({
    required HealthObservationPersistentStore cipherTextInner,
    required HealthObservationKeyLifecycle lifecycle,
    required AesGcmHealthObservationCipher cipher,
  }) {
    return HealthObservationKeyReferenceIndexSupport.rebuildInto(
      clear: () async => _byRefKey.clear(),
      upsert: upsertAfterPersist,
      cipherTextInner: cipherTextInner,
      lifecycle: lifecycle,
      cipher: cipher,
      verify: () => verifyConsistency(
        cipherTextInner: cipherTextInner,
        cipher: cipher,
      ),
    );
  }
}

/// فهرس ملفّي بجانب مخزن الـ ciphertext — بلا أسرار.
class FileHealthObservationKeyReferenceIndex
    implements HealthObservationKeyReferenceIndex {
  FileHealthObservationKeyReferenceIndex({
    required this.indexFile,
    DateTime Function()? clock,
  })  : _memory = InMemoryHealthObservationKeyReferenceIndex(clock: clock),
        _clock = clock ?? (() => DateTime.now().toUtc());

  static const fileName = 'health_observation_key_refs.json';

  final File indexFile;
  final InMemoryHealthObservationKeyReferenceIndex _memory;
  final DateTime Function() _clock;
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    if (await indexFile.exists()) {
      final raw = await indexFile.readAsString();
      if (raw.trim().isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map && decoded['references'] is List) {
          for (final item in decoded['references'] as List) {
            if (item is Map) {
              final ref = HealthObservationKeyReference.fromJson(
                Map<String, dynamic>.from(item),
              );
              _memory._byRefKey[ref.referenceKey] = ref;
            }
          }
        }
      }
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    final parent = indexFile.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final refs = await _memory.allReferences();
    final payload = <String, dynamic>{
      'indexId': HealthObservationKeyReferenceIndex.indexId,
      'updatedAt': _clock().toIso8601String(),
      'references': refs.map((r) => r.toJson()).toList(),
    };
    await indexFile.writeAsString(jsonEncode(payload), flush: true);
  }

  @override
  Future<List<HealthObservationKeyReference>> allReferences() async {
    await _ensureLoaded();
    return _memory.allReferences();
  }

  @override
  Future<List<HealthObservationKeyReference>> referencesFor(
    String keyId,
  ) async {
    await _ensureLoaded();
    return _memory.referencesFor(keyId);
  }

  @override
  Future<bool> hasReferences(String keyId) async {
    await _ensureLoaded();
    return _memory.hasReferences(keyId);
  }

  @override
  Future<void> upsertAfterPersist({
    required String keyId,
    required String envelopeId,
    required String formatVersion,
    required String contentFingerprint,
    required Map<String, HealthObservationKeyReferenceStatus> recordStatuses,
  }) async {
    await _ensureLoaded();
    await _memory.upsertAfterPersist(
      keyId: keyId,
      envelopeId: envelopeId,
      formatVersion: formatVersion,
      contentFingerprint: contentFingerprint,
      recordStatuses: recordStatuses,
    );
    await _persist();
  }

  @override
  Future<void> moveEnvelopeReference({
    required String envelopeId,
    required String fromKeyId,
    required String toKeyId,
    required String formatVersion,
    required String contentFingerprint,
  }) async {
    await _ensureLoaded();
    await _memory.moveEnvelopeReference(
      envelopeId: envelopeId,
      fromKeyId: fromKeyId,
      toKeyId: toKeyId,
      formatVersion: formatVersion,
      contentFingerprint: contentFingerprint,
    );
    await _persist();
  }

  @override
  Future<void> removeRecordReference({
    required String envelopeId,
    required String recordId,
  }) async {
    await _ensureLoaded();
    await _memory.removeRecordReference(
      envelopeId: envelopeId,
      recordId: recordId,
    );
    await _persist();
  }

  @override
  Future<void> clearEnvelopeReferences(String envelopeId) async {
    await _ensureLoaded();
    await _memory.clearEnvelopeReferences(envelopeId);
    await _persist();
  }

  @override
  Future<HealthObservationKeyIndexConsistencyReport> verifyConsistency({
    required HealthObservationPersistentStore cipherTextInner,
    AesGcmHealthObservationCipher? cipher,
  }) async {
    await _ensureLoaded();
    return _memory.verifyConsistency(
      cipherTextInner: cipherTextInner,
      cipher: cipher,
    );
  }

  @override
  Future<void> requireConsistent({
    required HealthObservationPersistentStore cipherTextInner,
    AesGcmHealthObservationCipher? cipher,
  }) async {
    await _ensureLoaded();
    return _memory.requireConsistent(
      cipherTextInner: cipherTextInner,
      cipher: cipher,
    );
  }

  @override
  Future<HealthObservationKeyIndexRebuildResult> rebuildFromStore({
    required HealthObservationPersistentStore cipherTextInner,
    required HealthObservationKeyLifecycle lifecycle,
    required AesGcmHealthObservationCipher cipher,
  }) async {
    await _ensureLoaded();
    final result = await _memory.rebuildFromStore(
      cipherTextInner: cipherTextInner,
      lifecycle: lifecycle,
      cipher: cipher,
    );
    if (result.success) {
      await _persist();
    }
    return result;
  }
}

/// منطق مشترك للاتساق وإعادة البناء — بلا تسجيل بيانات صحية أو مفاتيح.
class HealthObservationKeyReferenceIndexSupport {
  /// بصمة مستقرة للمغلف — ليست مفتاحاً وليست ciphertext مخزّناً.
  static String fingerprintOf(String envelope) {
    var hash = 0xcbf29ce484222325;
    for (final unit in utf8.encode(envelope)) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return '${envelope.length.toRadixString(16)}:'
        '${hash.toRadixString(16).padLeft(16, '0')}';
  }

  /// يستخرج معرفات السجلات وحالاتها من JSON — قيم الملاحظات تُتجاهل.
  static Map<String, HealthObservationKeyReferenceStatus>
      recordStatusesFromPlaintext(String plaintext) {
    final decoded = jsonDecode(plaintext);
    if (decoded is! Map) return {};
    final obs = decoded['observations'];
    if (obs is! Map) return {};
    final out = <String, HealthObservationKeyReferenceStatus>{};
    obs.forEach((key, value) {
      final id = key.toString();
      var status = HealthObservationKeyReferenceStatus.active;
      if (value is Map) {
        final s = value['status']?.toString();
        if (s == 'archived') {
          status = HealthObservationKeyReferenceStatus.archivedRecord;
        }
      }
      out[id] = status;
    });
    return out;
  }

  static Future<HealthObservationKeyIndexConsistencyReport> verify({
    required List<HealthObservationKeyReference> indexEntries,
    required HealthObservationPersistentStore cipherTextInner,
    required AesGcmHealthObservationCipher cipher,
  }) async {
    final issues = <HealthObservationKeyIndexInconsistency>[];
    final envelopeId =
        HealthObservationKeyReferenceIndex.canonicalEnvelopeId;

    final raw = await cipherTextInner.readRaw();
    final envRefs =
        indexEntries.where((r) => r.recordId == null).toList();
    final envRefKeys = <String>{};
    for (final r in envRefs) {
      if (!envRefKeys.add(r.referenceKey)) {
        issues.add(
          HealthObservationKeyIndexInconsistency(
            kind: HealthObservationKeyIndexInconsistencyKind.duplicateReference,
            message: 'مرجع مغلف مكرر: ${r.referenceKey}',
            envelopeId: r.envelopeId,
            keyId: r.keyId,
          ),
        );
      }
    }
    // duplicate record refs
    final seenRec = <String>{};
    for (final r in indexEntries.where((e) => e.recordId != null)) {
      if (!seenRec.add(r.referenceKey)) {
        issues.add(
          HealthObservationKeyIndexInconsistency(
            kind: HealthObservationKeyIndexInconsistencyKind.duplicateReference,
            message: 'مرجع سجل مكرر: ${r.referenceKey}',
            envelopeId: r.envelopeId,
            keyId: r.keyId,
          ),
        );
      }
    }

    if (raw == null || raw.trim().isEmpty) {
      if (indexEntries.isNotEmpty) {
        for (final r in indexEntries) {
          issues.add(
            HealthObservationKeyIndexInconsistency(
              kind: HealthObservationKeyIndexInconsistencyKind.orphanReference,
              message: 'مرجع يتيم بدون ciphertext: ${r.referenceKey}',
              envelopeId: r.envelopeId,
              keyId: r.keyId,
            ),
          );
        }
      }
      return HealthObservationKeyIndexConsistencyReport(
        consistent: issues.isEmpty,
        issues: issues,
      );
    }

    late final HealthObservationCipherEnvelope parsed;
    try {
      parsed = cipher.parse(raw);
    } on HealthObservationCipherException catch (e) {
      issues.add(
        HealthObservationKeyIndexInconsistency(
          kind: HealthObservationKeyIndexInconsistencyKind.staleReference,
          message: 'ciphertext غير قابل للتحليل مقابل الفهرس: $e',
          envelopeId: envelopeId,
        ),
      );
      return HealthObservationKeyIndexConsistencyReport(
        consistent: false,
        issues: issues,
      );
    }

    final storeKeyId = parsed.keyId ??
        HealthObservationKeyLifecycle.legacyKeyId;
    final fp = fingerprintOf(raw);
    final matchingEnv = envRefs.where((r) => r.envelopeId == envelopeId);

    if (matchingEnv.isEmpty) {
      issues.add(
        HealthObservationKeyIndexInconsistency(
          kind: HealthObservationKeyIndexInconsistencyKind.missingReference,
          message: 'ciphertext موجود بدون مرجع فهرس للمغلف $envelopeId',
          envelopeId: envelopeId,
          keyId: storeKeyId,
        ),
      );
    } else {
      for (final r in matchingEnv) {
        if (r.keyId != storeKeyId) {
          issues.add(
            HealthObservationKeyIndexInconsistency(
              kind: HealthObservationKeyIndexInconsistencyKind.wrongKeyId,
              message:
                  'keyId في الفهرس (${r.keyId}) ≠ envelope ($storeKeyId)',
              envelopeId: envelopeId,
              keyId: r.keyId,
            ),
          );
        }
        if (r.contentFingerprint != null &&
            r.contentFingerprint != fp) {
          issues.add(
            HealthObservationKeyIndexInconsistency(
              kind: HealthObservationKeyIndexInconsistencyKind.staleReference,
              message: 'بصمة المغلف في الفهرس قديمة/غير مطابقة',
              envelopeId: envelopeId,
              keyId: r.keyId,
            ),
          );
        }
      }
    }

    // مراجع سجلات/مغلف لمغلف آخر أو key خاطئ مع وجود store
    for (final r in indexEntries) {
      if (r.envelopeId != envelopeId) {
        issues.add(
          HealthObservationKeyIndexInconsistency(
            kind: HealthObservationKeyIndexInconsistencyKind.orphanReference,
            message: 'مرجع لمغلف غير موجود: ${r.envelopeId}',
            envelopeId: r.envelopeId,
            keyId: r.keyId,
          ),
        );
        continue;
      }
      if (r.recordId == null) continue;
      if (r.keyId != storeKeyId) {
        issues.add(
          HealthObservationKeyIndexInconsistency(
            kind: HealthObservationKeyIndexInconsistencyKind.wrongKeyId,
            message:
                'سجل ${r.recordId} يشير إلى ${r.keyId} بينما المغلف $storeKeyId',
            envelopeId: envelopeId,
            keyId: r.keyId,
          ),
        );
      }
      if (r.contentFingerprint != null && r.contentFingerprint != fp) {
        issues.add(
          HealthObservationKeyIndexInconsistency(
            kind: HealthObservationKeyIndexInconsistencyKind.staleReference,
            message: 'مرجع سجل ${r.recordId} ببصمة قديمة',
            envelopeId: envelopeId,
            keyId: r.keyId,
          ),
        );
      }
    }

    return HealthObservationKeyIndexConsistencyReport(
      consistent: issues.isEmpty,
      issues: issues,
    );
  }

  static Future<HealthObservationKeyIndexRebuildResult> rebuildInto({
    required Future<void> Function() clear,
    required Future<void> Function({
      required String keyId,
      required String envelopeId,
      required String formatVersion,
      required String contentFingerprint,
      required Map<String, HealthObservationKeyReferenceStatus> recordStatuses,
    }) upsert,
    required HealthObservationPersistentStore cipherTextInner,
    required HealthObservationKeyLifecycle lifecycle,
    required AesGcmHealthObservationCipher cipher,
    required Future<HealthObservationKeyIndexConsistencyReport> Function()
        verify,
  }) async {
    await clear();
    final raw = await cipherTextInner.readRaw();
    if (raw == null || raw.trim().isEmpty) {
      final report = await verify();
      return HealthObservationKeyIndexRebuildResult(
        success: report.consistent,
        envelopeReferenced: false,
        recordCount: 0,
        consistency: report,
      );
    }

    final parsed = cipher.parse(raw);
    final keyId = parsed.keyId ?? HealthObservationKeyLifecycle.legacyKeyId;
    // فك آمن عبر lifecycle فقط لاستخراج معرفات السجلات — بلا تسجيل قيم.
    final plaintext = await lifecycle.decryptWithRecovery(
      envelope: raw,
      cipher: cipher,
    );
    final records = recordStatusesFromPlaintext(plaintext);
    await upsert(
      keyId: keyId,
      envelopeId: HealthObservationKeyReferenceIndex.canonicalEnvelopeId,
      formatVersion: parsed.format,
      contentFingerprint: fingerprintOf(raw),
      recordStatuses: records,
    );
    final report = await verify();
    return HealthObservationKeyIndexRebuildResult(
      success: report.consistent,
      envelopeReferenced: true,
      recordCount: records.length,
      consistency: report,
    );
  }
}
