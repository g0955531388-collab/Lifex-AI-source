import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/ingestion/ingestion_safety.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/ingestion/source_registry.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/ingestion/source_registry_model.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_types.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/retrieval_adapters.dart';
import 'package:lifex_ai/core/lio/lio_canon.dart';
import 'package:lifex_ai/core/lio/lio_types.dart';
import 'package:lifex_ai/core/lio/source_reliability.dart';

void main() {
  const safety = IngestionSafetyPolicy();
  const canon = LifexLioCanon();
  const keSafety = KnowledgeEngineSafety();

  test('Clinical DB usage محظور', () {
    expect(safety.mayTouchClinicalDatabase, isFalse);
    expect(keSafety.mayTouchClinicalDatabase, isFalse);
    expect(canon.clinicalDataEntersGeneralAiMemory, isFalse);
  });

  test('patient data ingestion محظور', () {
    expect(safety.mayIngestClinicalRecords, isFalse);
    expect(safety.mayIngestPrivateHealth, isFalse);
    expect(safety.mayIngestPrescriptions, isFalse);
  });

  test('LLM-as-SoT محظور', () {
    expect(safety.llmIsSourceOfTruth, isFalse);
    expect(keSafety.llmIsSourceOfTruth, isFalse);
    expect(canon.memoryIsNotSourceOfTruth, isTrue);
  });

  test('UI → repository/database محظور', () {
    expect(safety.mayWriteUiDirectToRepository, isFalse);
    expect(keSafety.uiMayTalkKnowledgeDbDirectly, isFalse);
    expect(canon.aiMayTalkSqlDirectly, isFalse);
  });

  test('ingestion bypassing provenance محظور', () {
    expect(safety.mayBypassProvenance, isFalse);
  });

  test('ingestion bypassing validation محظور', () {
    expect(safety.mayBypassValidation, isFalse);
  });

  test('direct corpus clinical add محظور', () {
    final c = InMemoryKnowledgeCorpus();
    expect(
      () => c.add(
        KnowledgeRecord(
          id: 'x',
          title: 't',
          body: 'b',
          layer: KnowledgeLayer.clinicalData,
          provenance: LioSourceProvenance(
            sourceId: 'x',
            sourceType: 'clinical',
            authority: LioSourceAuthority.unverified,
            retrievedAt: DateTime(2026),
          ),
        ),
      ),
      throwsStateError,
    );
  });

  test('registry rejects non-citable unverified source', () {
    final reg = InMemoryKnowledgeSourceRegistry();
    final r = reg.register(
      RegisteredKnowledgeSource(
        sourceId: 'n',
        kind: KnowledgeSourceKind.internalAuthoredKnowledge,
        title: 'n',
        authority: LioSourceAuthority.unverified,
        status: KnowledgeSourceStatus.active,
        retrievedAt: DateTime(2026, 9, 20),
      ),
    );
    expect(r.accepted, isFalse);
  });
}
