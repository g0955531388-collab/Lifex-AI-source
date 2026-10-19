/// =============================================================
/// Lifex-AI — عقود أساسية مشتركة (قبل GAP-001…010)
/// =============================================================
library lifex_ai.core.contracts.lifex_core_contracts;

class LifexId {
  const LifexId(this.value);
  final String value;
  bool get isEmpty => value.trim().isEmpty;
  @override
  String toString() => value;
  @override
  bool operator ==(Object other) => other is LifexId && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

enum LifexErrorCode {
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  unsupported,
  unavailable,
  ownershipViolation,
  provenanceMissing,
}

class LifexError {
  const LifexError(this.code, this.message, {this.details});
  final LifexErrorCode code;
  final String message;
  final Map<String, Object?>? details;
}

class LifexResult<T> {
  const LifexResult._({this.value, this.error});
  final T? value;
  final LifexError? error;
  bool get isOk => error == null;
  bool get isErr => error != null;
  factory LifexResult.ok(T value) => LifexResult._(value: value);
  factory LifexResult.err(LifexError error) => LifexResult._(error: error);
}

/// Required provenance for any canonical clinical / AI / lab artifact.
class EntityProvenance {
  const EntityProvenance({
    required this.sourceSystem,
    required this.provenanceId,
    required this.timestamp,
    this.authorId,
    this.organizationId,
    this.version = '1',
  });

  final String? authorId;
  final String? organizationId;
  final String sourceSystem;
  final String provenanceId;
  final DateTime timestamp;
  final String version;

  bool get isComplete =>
      sourceSystem.isNotEmpty &&
      provenanceId.isNotEmpty &&
      version.isNotEmpty;
}

enum DataKind { original, projection, derived, cache, event, audit }
