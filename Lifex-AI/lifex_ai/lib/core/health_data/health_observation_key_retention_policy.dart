/// =============================================================
/// Lifex-AI — سياسة Retention / Revocation / Archival لمفاتيح HealthObservation
/// metadata فقط — بلا قيم مفاتيح.
/// =============================================================
library lifex_ai.core.health_data.health_observation_key_retention_policy;

/// حالات مفتاح صريحة — لا حالات ضمنية.
enum HealthObservationKeyStatus {
  /// المفتاح الحالي للكتابة الجديدة.
  current,

  /// يُسمح بفك التشفير (بعد rotation عادةً) — لا كتابة جديدة.
  activeForDecryption,

  /// متقاعد: لا كتابة؛ فك التشفير مسموح وفق السياسة.
  retired,

  /// ملغى: ممنوع التشفير والفك.
  revoked,

  /// مؤرشف وغير متاح للعمليات (ليس حذفاً تلقائياً).
  archived,
}

/// Metadata آمنة — بلا DEK.
class HealthObservationKeyMetadata {
  const HealthObservationKeyMetadata({
    required this.keyId,
    required this.version,
    required this.status,
    required this.createdAt,
    this.activatedAt,
    this.retiredAt,
    this.revokedAt,
    this.archivedAt,
    this.archivalNote,
  });

  final String keyId;
  final int version;
  final HealthObservationKeyStatus status;
  final DateTime createdAt;
  final DateTime? activatedAt;
  final DateTime? retiredAt;
  final DateTime? revokedAt;
  final DateTime? archivedAt;
  final String? archivalNote;

  HealthObservationKeyMetadata copyWith({
    HealthObservationKeyStatus? status,
    DateTime? activatedAt,
    DateTime? retiredAt,
    DateTime? revokedAt,
    DateTime? archivedAt,
    String? archivalNote,
  }) {
    return HealthObservationKeyMetadata(
      keyId: keyId,
      version: version,
      status: status ?? this.status,
      createdAt: createdAt,
      activatedAt: activatedAt ?? this.activatedAt,
      retiredAt: retiredAt ?? this.retiredAt,
      revokedAt: revokedAt ?? this.revokedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      archivalNote: archivalNote ?? this.archivalNote,
    );
  }

  Map<String, dynamic> toJson() => {
        'keyId': keyId,
        'version': version,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        if (activatedAt != null) 'activatedAt': activatedAt!.toIso8601String(),
        if (retiredAt != null) 'retiredAt': retiredAt!.toIso8601String(),
        if (revokedAt != null) 'revokedAt': revokedAt!.toIso8601String(),
        if (archivedAt != null) 'archivedAt': archivedAt!.toIso8601String(),
        if (archivalNote != null) 'archivalNote': archivalNote,
      };

  factory HealthObservationKeyMetadata.fromJson(Map<String, dynamic> json) {
    return HealthObservationKeyMetadata(
      keyId: json['keyId']?.toString() ?? '',
      version: (json['version'] as num?)?.toInt() ?? 0,
      status: HealthObservationKeyStatus.values.firstWhere(
        (e) => e.name == json['status']?.toString(),
        orElse: () => HealthObservationKeyStatus.activeForDecryption,
      ),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      activatedAt: json['activatedAt'] == null
          ? null
          : DateTime.tryParse(json['activatedAt'].toString()),
      retiredAt: json['retiredAt'] == null
          ? null
          : DateTime.tryParse(json['retiredAt'].toString()),
      revokedAt: json['revokedAt'] == null
          ? null
          : DateTime.tryParse(json['revokedAt'].toString()),
      archivedAt: json['archivedAt'] == null
          ? null
          : DateTime.tryParse(json['archivedAt'].toString()),
      archivalNote: json['archivalNote']?.toString(),
    );
  }
}

/// قرار سياسة — أكواد صريحة.
class HealthObservationKeyRetentionDecision {
  const HealthObservationKeyRetentionDecision({
    required this.allowed,
    required this.reasonCode,
    required this.messageAr,
  });

  final bool allowed;
  final String reasonCode;
  final String messageAr;

  static const retentionRequired = 'RETENTION_REQUIRED';
  static const purgeAllowed = 'PURGE_ALLOWED';
  static const keyRevoked = 'KEY_REVOKED';
  static const keyArchivedUnavailable = 'KEY_ARCHIVED_UNAVAILABLE';
  static const keyNotCurrent = 'KEY_NOT_CURRENT';
  static const keyStillReferenced = 'KEY_STILL_REFERENCED';
  static const encryptDenied = 'ENCRYPT_DENIED';
  static const decryptDenied = 'DECRYPT_DENIED';
}

/// سياسة Retention / Revocation / Archival.
class HealthObservationKeyRetentionPolicy {
  const HealthObservationKeyRetentionPolicy();

  static const policyId = 'HealthObservationKeyRetentionPolicy';

  /// CURRENT فقط للكتابة الجديدة.
  bool mayEncrypt(HealthObservationKeyMetadata meta) =>
      meta.status == HealthObservationKeyStatus.current;

  /// CURRENT / ACTIVE_FOR_DECRYPTION / RETIRED — فك مسموح.
  /// REVOKED / ARCHIVED — ممنوع.
  bool mayDecrypt(HealthObservationKeyMetadata meta) {
    switch (meta.status) {
      case HealthObservationKeyStatus.current:
      case HealthObservationKeyStatus.activeForDecryption:
      case HealthObservationKeyStatus.retired:
        return true;
      case HealthObservationKeyStatus.revoked:
      case HealthObservationKeyStatus.archived:
        return false;
    }
  }

  HealthObservationKeyRetentionDecision evaluateEncrypt(
    HealthObservationKeyMetadata meta,
  ) {
    if (mayEncrypt(meta)) {
      return const HealthObservationKeyRetentionDecision(
        allowed: true,
        reasonCode: 'ENCRYPT_ALLOWED',
        messageAr: 'المفتاح الحالي مسموح للكتابة.',
      );
    }
    return HealthObservationKeyRetentionDecision(
      allowed: false,
      reasonCode: HealthObservationKeyRetentionDecision.encryptDenied,
      messageAr:
          'الكتابة مرفوضة: المفتاح ${meta.keyId} بحالة ${meta.status.name} '
          '— CURRENT فقط للكتابة الجديدة.',
    );
  }

  HealthObservationKeyRetentionDecision evaluateDecrypt(
    HealthObservationKeyMetadata meta,
  ) {
    if (mayDecrypt(meta)) {
      return const HealthObservationKeyRetentionDecision(
        allowed: true,
        reasonCode: 'DECRYPT_ALLOWED',
        messageAr: 'فك التشفير مسموح وفق سياسة الاحتفاظ.',
      );
    }
    if (meta.status == HealthObservationKeyStatus.revoked) {
      return HealthObservationKeyRetentionDecision(
        allowed: false,
        reasonCode: HealthObservationKeyRetentionDecision.keyRevoked,
        messageAr: 'فك التشفير مرفوض: المفتاح ${meta.keyId} ملغى (REVOKED).',
      );
    }
    if (meta.status == HealthObservationKeyStatus.archived) {
      return HealthObservationKeyRetentionDecision(
        allowed: false,
        reasonCode:
            HealthObservationKeyRetentionDecision.keyArchivedUnavailable,
        messageAr:
            'فك التشفير مرفوض: المفتاح ${meta.keyId} مؤرشف وغير متاح '
            '(ARCHIVED ≠ حذف تلقائي).',
      );
    }
    return HealthObservationKeyRetentionDecision(
      allowed: false,
      reasonCode: HealthObservationKeyRetentionDecision.decryptDenied,
      messageAr: 'فك التشفير مرفوض لحالة ${meta.status.name}.',
    );
  }

  /// حذف مادة المفتاح — فقط إن لم تُشر البيانات إليه وبعد REVOKED/ARCHIVED.
  /// وإلا RETENTION_REQUIRED بلا حذف.
  HealthObservationKeyRetentionDecision evaluatePurge({
    required HealthObservationKeyMetadata meta,
    required bool stillReferencedByCiphertext,
  }) {
    if (meta.status == HealthObservationKeyStatus.current) {
      return HealthObservationKeyRetentionDecision(
        allowed: false,
        reasonCode: HealthObservationKeyRetentionDecision.retentionRequired,
        messageAr: 'لا يُحذف المفتاح الحالي — RETENTION_REQUIRED.',
      );
    }
    if (stillReferencedByCiphertext) {
      return HealthObservationKeyRetentionDecision(
        allowed: false,
        reasonCode: HealthObservationKeyRetentionDecision.keyStillReferenced,
        messageAr:
            'لا يُحذف المفتاح ${meta.keyId}: ما زالت envelopes تعتمد عليه. '
            'أعد التشفير أولاً — RETENTION_REQUIRED.',
      );
    }
    if (meta.status != HealthObservationKeyStatus.revoked &&
        meta.status != HealthObservationKeyStatus.archived) {
      return HealthObservationKeyRetentionDecision(
        allowed: false,
        reasonCode: HealthObservationKeyRetentionDecision.retentionRequired,
        messageAr:
            'لا يُحذف المفتاح قبل REVOKED أو ARCHIVED مع إثبات عدم الاعتماد. '
            'RETENTION_REQUIRED.',
      );
    }
    return HealthObservationKeyRetentionDecision(
      allowed: true,
      reasonCode: HealthObservationKeyRetentionDecision.purgeAllowed,
      messageAr:
          'يُسمح بإنهاء الاحتفاظ بعد إثبات عدم الاعتماد وحالة '
          '${meta.status.name}.',
    );
  }
}

/// فشل سياسة مفتاح — صريح وآمن.
class HealthObservationKeyPolicyException implements Exception {
  HealthObservationKeyPolicyException({
    required this.keyId,
    required this.reasonCode,
    required this.message,
  });

  final String keyId;
  final String reasonCode;
  final String message;

  @override
  String toString() =>
      'HealthObservationKeyPolicyException($keyId/$reasonCode): $message';
}
