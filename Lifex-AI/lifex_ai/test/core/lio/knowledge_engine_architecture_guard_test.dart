import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_engine.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/knowledge_types.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/local_retrievers.dart';
import 'package:lifex_ai/core/lio/knowledge_engine/retrieval_adapters.dart';
import 'package:lifex_ai/core/lio/lio_canon.dart';
import 'package:lifex_ai/core/lio/lio_types.dart';
import 'package:lifex_ai/core/lio/source_reliability.dart';

void main() {
  const safety = KnowledgeEngineSafety();
  const canon = LifexLioCanon();

  test('Knowledge Engine → Clinical Database محظور', () {
    expect(safety.mayTouchClinicalDatabase, isFalse);
    expect(canon.clinicalDataEntersGeneralAiMemory, isFalse);
  });

  test('Knowledge Engine → Medical Device محظور', () {
    expect(safety.mayControlMedicalDevice, isFalse);
  });

  test('Knowledge Engine → Direct Prescription محظور', () {
    expect(safety.mayPrescribe, isFalse);
    expect(safety.mayDiagnose, isFalse);
  });

  test('LLM → Source of Truth محظور', () {
    expect(safety.llmIsSourceOfTruth, isFalse);
    expect(canon.memoryIsNotSourceOfTruth, isTrue);
  });

  test('UI → Knowledge Database مباشرة محظور', () {
    expect(safety.uiMayTalkKnowledgeDbDirectly, isFalse);
    expect(canon.aiMayTalkSqlDirectly, isFalse);
  });

  test('Structured SQL لا يلمس Clinical', () {
    expect(
      const UnavailableStructuredSqlRetriever().mayTouchClinical,
      isFalse,
    );
  });

  test('Corpus يرفض إضافة Clinical', () {
    final c = InMemoryKnowledgeCorpus();
    expect(
      () => c.add(
        // ignore: prefer_const_constructors — runtime layer check
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
}
