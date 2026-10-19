/// =============================================================
/// Lifex-AI — عقود دورة حياة البيانات الحساسة (Production)
/// DELETE ≠ ARCHIVE · EXPORT ≠ SHARE · CONTROL = policy فقط
/// لا نجاح وهمي لعمليات بلا طبقة تنفيذ آمنة.
/// =============================================================
library lifex_ai.core.orchestrator.lio_sensitive_lifecycle_contracts;

/// حالة التنفيذ بعد قرار LIO (ليس قرار البوابة نفسه).
enum LioLifecycleExecutionStatus {
  /// نُفِّذت عبر طبقة Application آمنة موجودة.
  implemented,

  /// مسموح بالسياسة لكن لا طبقة تنفيذ آمنة بعد.
  notImplemented,

  /// العملية غير مدعومة في هذا البناء (عقد صريح).
  unsupportedOperation,
}

extension LioLifecycleExecutionStatusX on LioLifecycleExecutionStatus {
  String get wireCode {
    switch (this) {
      case LioLifecycleExecutionStatus.implemented:
        return 'IMPLEMENTED';
      case LioLifecycleExecutionStatus.notImplemented:
        return 'NOT_IMPLEMENTED';
      case LioLifecycleExecutionStatus.unsupportedOperation:
        return 'UNSUPPORTED_OPERATION';
    }
  }

  bool get isSuccess => this == LioLifecycleExecutionStatus.implemented;
}

/// تصنيف عملية دورة حياة — منفصل عن التشخيص السريري.
enum LioLifecycleOpKind {
  readSensitive,
  readHealth,
  readMedical,
  write,
  update,
  delete,
  archive,
  export,
  share,
  printOp,
  download,
  financial,
  emergencyAccess,
  control,
}

/// نطاق بيانات حساس (مالك منطقي، ليس جدول SQL).
enum LioSensitiveDataDomain {
  patientPhr,
  clinical,
  healthObservation,
  medicalDocument,
  appointment,
  medicationRecord,
  emergencyRecord,
  familyPrivate,
  walletFinancial,
  publicEducation,
  deviceControl,
  medicalCatalog,
}

/// نتيجة دورة حياة بعد عبور LIO — لا تُفسَّر كنجاح إن كانت NOT_IMPLEMENTED.
class LioLifecycleResult {
  const LioLifecycleResult({
    required this.opKind,
    required this.domain,
    required this.executionStatus,
    required this.messageAr,
    required this.reasonCode,
  });

  final LioLifecycleOpKind opKind;
  final LioSensitiveDataDomain domain;
  final LioLifecycleExecutionStatus executionStatus;
  final String messageAr;
  final String reasonCode;

  bool get succeeded => executionStatus.isSuccess;

  factory LioLifecycleResult.notImplemented({
    required LioLifecycleOpKind opKind,
    required LioSensitiveDataDomain domain,
    required String messageAr,
  }) {
    return LioLifecycleResult(
      opKind: opKind,
      domain: domain,
      executionStatus: LioLifecycleExecutionStatus.notImplemented,
      messageAr: messageAr,
      reasonCode: 'NOT_IMPLEMENTED',
    );
  }

  factory LioLifecycleResult.unsupported({
    required LioLifecycleOpKind opKind,
    required LioSensitiveDataDomain domain,
    required String messageAr,
  }) {
    return LioLifecycleResult(
      opKind: opKind,
      domain: domain,
      executionStatus: LioLifecycleExecutionStatus.unsupportedOperation,
      messageAr: messageAr,
      reasonCode: 'UNSUPPORTED_OPERATION',
    );
  }

  factory LioLifecycleResult.implemented({
    required LioLifecycleOpKind opKind,
    required LioSensitiveDataDomain domain,
    required String messageAr,
  }) {
    return LioLifecycleResult(
      opKind: opKind,
      domain: domain,
      executionStatus: LioLifecycleExecutionStatus.implemented,
      messageAr: messageAr,
      reasonCode: 'IMPLEMENTED',
    );
  }
}
