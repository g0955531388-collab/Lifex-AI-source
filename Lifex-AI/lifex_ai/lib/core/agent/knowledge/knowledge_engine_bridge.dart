/// =============================================================
/// Lifex-AI — جسر توافق: Agent Knowledge ← Knowledge Engine
/// Evidence Pack → KnowledgeDocument / KnowledgeContext
/// =============================================================
library lifex_ai.core.agent.knowledge.knowledge_engine_bridge;

import '../../lio/knowledge_engine/evidence_pack.dart';
import '../../lio/knowledge_engine/knowledge_types.dart';
import '../../lio/source_reliability.dart';
import 'knowledge_context.dart';
import 'knowledge_document.dart';

/// تحويل نتائج Knowledge Engine إلى عقود الوكيل — بلا إعادة استرجاع.
class AgentKnowledgeBridge {
  const AgentKnowledgeBridge({
    this.reliability = const LifexSourceReliabilityEngine(),
  });

  final LifexSourceReliabilityEngine reliability;

  KnowledgeContext toAgentContext({
    required String originalQuery,
    required KnowledgeEvidencePack pack,
    int maxResults = 8,
  }) {
    if (pack.status == KnowledgeRetrievalStatus.missingProvenance ||
        pack.status == KnowledgeRetrievalStatus.forbidden) {
      return KnowledgeContext(
        query: originalQuery,
        matches: const [],
        retrievalStatus: pack.status.wireName,
        conflicts: pack.conflicts,
        notesAr: pack.notesAr,
        evidencePackMap: pack.toMap(),
        llmIsSourceOfTruth: false,
      );
    }

    final docs = <KnowledgeDocument>[];
    for (final item in pack.items.take(maxResults)) {
      if (!reliability.acceptAsEvidence(item.provenance)) {
        continue;
      }
      docs.add(
        KnowledgeDocument(
          id: item.recordId,
          sourceFile: item.provenance.document ??
              item.provenance.repository ??
              item.provenance.sourceType,
          category: item.provenance.sourceType,
          searchableText: '${item.title} ${item.snippet}'.toLowerCase(),
          raw: {
            'id': item.recordId,
            'title': item.title,
            'snippet': item.snippet,
            'score': item.score,
            'channel': item.channel.name,
            'provenance': item.toMap(),
            'competingIds': item.competingIds,
            'evidenceLevel': item.provenance.evidenceLevel,
            'confidence': item.provenance.confidence,
            'conflictStatus': item.provenance.conflict.name,
            'authority': item.provenance.authority.name,
            'sourceId': item.provenance.sourceId,
            'version': item.provenance.version,
          },
        ),
      );
    }

    return KnowledgeContext(
      query: originalQuery,
      matches: docs,
      retrievalStatus: pack.status.wireName,
      conflicts: pack.conflicts,
      notesAr: pack.notesAr,
      evidencePackMap: pack.toMap(),
      llmIsSourceOfTruth: pack.llmIsSourceOfTruth,
    );
  }

  KnowledgeQuery toEngineQuery(String query, {int maxResults = 8}) {
    return KnowledgeQuery(
      text: query,
      topK: maxResults,
      requireProvenance: true,
      allowClinical: false,
      channels: const [
        RetrievalChannel.keywordBm25,
        RetrievalChannel.metadata,
        RetrievalChannel.graph,
      ],
    );
  }
}
