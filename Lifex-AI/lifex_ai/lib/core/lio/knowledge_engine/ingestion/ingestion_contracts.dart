/// =============================================================
/// Lifex-AI — عقود مسار الاستيعاب (Ingestion Contracts)
/// =============================================================
library lifex_ai.core.lio.knowledge_engine.ingestion.ingestion_contracts;

import '../knowledge_types.dart';
import 'source_registry_model.dart';

enum IngestionStatus {
  pending,
  validating,
  acquiring,
  normalizing,
  segmenting,
  attachingProvenance,
  checkingDuplicates,
  checkingConflicts,
  accepted,
  quarantined,
  rejected,
}

enum IngestionRejectReason {
  missingProvenance,
  invalidSource,
  forbiddenClinical,
  forbiddenPrivateHealth,
  forbiddenPrescription,
  forbiddenSecrets,
  forbiddenDeviceCommand,
  emptyContent,
  duplicate,
  validationFailed,
  bypassAttempt,
}

class RawKnowledgeDocument {
  const RawKnowledgeDocument({
    required this.documentId,
    required this.sourceId,
    required this.title,
    required this.body,
    this.terms = const [],
    this.metadata = const {},
    this.contentHash,
    this.version,
  });

  final String documentId;
  final String sourceId;
  final String title;
  final String body;
  final List<String> terms;
  final Map<String, String> metadata;
  final String? contentHash;
  final String? version;
}

class NormalizedKnowledgeChunk {
  const NormalizedKnowledgeChunk({
    required this.chunkId,
    required this.documentId,
    required this.sourceId,
    required this.title,
    required this.body,
    required this.contentHash,
    this.terms = const [],
    this.metadata = const {},
    this.version,
  });

  final String chunkId;
  final String documentId;
  final String sourceId;
  final String title;
  final String body;
  final String contentHash;
  final List<String> terms;
  final Map<String, String> metadata;
  final String? version;
}

/// سجل استيعاب غير قابل للتغيير (append-only منطقيًا).
class ImmutableIngestionRecord {
  const ImmutableIngestionRecord({
    required this.ingestionId,
    required this.status,
    required this.at,
    required this.sourceId,
    this.documentId,
    this.contentHash,
    this.version,
    this.rejectReason,
    this.notesAr = const [],
    this.competingDocumentIds = const [],
    this.supersedesIngestionId,
  });

  final String ingestionId;
  final IngestionStatus status;
  final DateTime at;
  final String sourceId;
  final String? documentId;
  final String? contentHash;
  final String? version;
  final IngestionRejectReason? rejectReason;
  final List<String> notesAr;
  final List<String> competingDocumentIds;
  final String? supersedesIngestionId;
}

class IngestionOutcome {
  const IngestionOutcome({
    required this.status,
    required this.record,
    this.acceptedRecords = const [],
    this.quarantinedChunks = const [],
  });

  final IngestionStatus status;
  final ImmutableIngestionRecord record;
  final List<KnowledgeRecord> acceptedRecords;
  final List<NormalizedKnowledgeChunk> quarantinedChunks;
}

/// اكتساب مستند — محلي/اختباري فقط في هذه المرحلة.
abstract class DocumentAcquisitionAdapter {
  Future<RawKnowledgeDocument?> acquire({
    required RegisteredKnowledgeSource source,
    required String documentId,
  });
}

abstract class ContentNormalizer {
  String normalize(String input);
}

abstract class ContentSegmenter {
  List<NormalizedKnowledgeChunk> segment(RawKnowledgeDocument doc);
}

abstract class ChecksumCalculator {
  String hash(String content);
}
