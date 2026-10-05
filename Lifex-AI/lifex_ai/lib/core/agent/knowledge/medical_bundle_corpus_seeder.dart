/// =============================================================
/// Lifex-AI — بذر Corpus من الحزمة الطبية (ليس محرك استرجاع)
/// يملأ Knowledge Engine فقط؛ البحث يتم عبر LifexKnowledgeEngine.
/// =============================================================
library lifex_ai.core.agent.knowledge.medical_bundle_corpus_seeder;

import '../../../data/medical_database_manager.dart';
import '../../lio/knowledge_engine/knowledge_types.dart';
import '../../lio/knowledge_engine/retrieval_adapters.dart';
import '../../lio/lio_types.dart';
import '../../lio/source_reliability.dart';

/// يحوّل JSON الطبي إلى KnowledgeRecord مع provenance — بلا بحث مستقل.
class MedicalBundleCorpusSeeder {
  const MedicalBundleCorpusSeeder();

  Future<void> seedInto(
    InMemoryKnowledgeCorpus corpus,
    MedicalDatabaseManager databaseManager,
  ) async {
    final bundle = await databaseManager.readFullBundle();
    _seedFile(
      corpus,
      bundle[MedicalBundleFiles.diseases],
      listKey: 'diseases',
      category: 'disease',
      sourceFile: MedicalBundleFiles.diseases,
    );
    _seedFile(
      corpus,
      bundle[MedicalBundleFiles.symptoms],
      listKey: 'symptoms',
      category: 'symptom',
      sourceFile: MedicalBundleFiles.symptoms,
    );
    _seedFile(
      corpus,
      bundle[MedicalBundleFiles.medications],
      listKey: 'medications',
      category: 'medication',
      sourceFile: MedicalBundleFiles.medications,
    );
    _seedFile(
      corpus,
      bundle[MedicalBundleFiles.tests],
      listKey: 'tests',
      category: 'test',
      sourceFile: MedicalBundleFiles.tests,
    );
  }

  void _seedFile(
    InMemoryKnowledgeCorpus corpus,
    Map<String, dynamic>? json, {
    required String listKey,
    required String category,
    required String sourceFile,
  }) {
    if (json == null) return;
    final list = json[listKey] as List<dynamic>? ?? const [];
    final now = DateTime.now();
    for (final entry in list) {
      final map = entry as Map<String, dynamic>;
      final id = (map['id'] as String?) ?? '';
      if (id.isEmpty) continue;
      final nameAr = (map['nameAr'] as String?) ?? '';
      final nameEn = (map['nameEn'] as String?) ?? '';
      final synonyms = (map['synonymsAr'] as List<dynamic>?)
              ?.map((s) => s.toString())
              .join(' ') ??
          '';
      final title = nameAr.isNotEmpty ? nameAr : nameEn;
      final body = '$nameAr $nameEn $synonyms'.trim();
      if (body.isEmpty) continue;

      corpus.add(
        KnowledgeRecord(
          id: '$category:$id',
          title: title.isEmpty ? id : title,
          body: body,
          layer: KnowledgeLayer.knowledge,
          terms: [
            if (nameAr.isNotEmpty) nameAr.toLowerCase(),
            if (nameEn.isNotEmpty) nameEn.toLowerCase(),
            category,
          ],
          metadata: {
            'category': category,
            'sourceFile': sourceFile,
            'bundleId': id,
          },
          provenance: LioSourceProvenance(
            sourceId: 'medical-bundle:$sourceFile:$id',
            sourceType: 'medical_json_bundle',
            authority: LioSourceAuthority.documentation,
            retrievedAt: now,
            document: sourceFile,
            version: 'bundle',
            evidenceLevel: 0.65,
            confidence: 0.6,
          ),
        ),
      );
    }
  }
}
