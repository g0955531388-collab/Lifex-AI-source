/// =============================================================
/// Lifex-AI — محولات استيعاب محلية حتمية
/// =============================================================
library lifex_ai.core.lio.knowledge_engine.ingestion.local_ingestion_adapters;

import 'dart:convert';

import 'ingestion_contracts.dart';
import 'source_registry_model.dart';

class InMemoryDocumentStore implements DocumentAcquisitionAdapter {
  InMemoryDocumentStore([Map<String, RawKnowledgeDocument>? seed])
      : _docs = Map.of(seed ?? {});

  final Map<String, RawKnowledgeDocument> _docs;

  void put(RawKnowledgeDocument doc) => _docs[doc.documentId] = doc;

  @override
  Future<RawKnowledgeDocument?> acquire({
    required RegisteredKnowledgeSource source,
    required String documentId,
  }) async {
    final doc = _docs[documentId];
    if (doc == null) return null;
    if (doc.sourceId != source.sourceId) return null;
    return doc;
  }
}

class SimpleContentNormalizer implements ContentNormalizer {
  const SimpleContentNormalizer();

  @override
  String normalize(String input) => input
      .trim()
      .replaceAll(RegExp(r'[\u064B-\u0652]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// تقسيم بسيط بالفقرات — ليس NLP كاملًا.
class ParagraphSegmenter implements ContentSegmenter {
  const ParagraphSegmenter({this.normalizer = const SimpleContentNormalizer()});

  final ContentNormalizer normalizer;

  @override
  List<NormalizedKnowledgeChunk> segment(RawKnowledgeDocument doc) {
    final body = normalizer.normalize(doc.body);
    if (body.isEmpty) return const [];
    final parts = body
        .split(RegExp(r'\n{2,}|(?<=\.)\s+'))
        .map(normalizer.normalize)
        .where((p) => p.length >= 8)
        .toList();
    final segments = parts.isEmpty ? <String>[body] : parts;
    final hashBase = doc.contentHash ??
        const FnvChecksum().hash('${doc.title}|$body');
    final chunks = <NormalizedKnowledgeChunk>[];
    for (var i = 0; i < segments.length; i++) {
      chunks.add(
        NormalizedKnowledgeChunk(
          chunkId: '${doc.documentId}#$i',
          documentId: doc.documentId,
          sourceId: doc.sourceId,
          title: doc.title,
          body: segments[i],
          contentHash: const FnvChecksum().hash('$hashBase#$i|${segments[i]}'),
          terms: doc.terms,
          metadata: {
            ...doc.metadata,
            'chunkIndex': '$i',
          },
          version: doc.version,
        ),
      );
    }
    return chunks;
  }
}

/// FNV-1a 64 — حتمي بلا اعتماد crypto ثقيل.
class FnvChecksum implements ChecksumCalculator {
  const FnvChecksum();

  @override
  String hash(String content) {
    const fnvOffset = 0xcbf29ce484222325;
    const fnvPrime = 0x100000001b3;
    var hash = fnvOffset;
    for (final b in utf8.encode(content)) {
      hash ^= b;
      hash = (hash * fnvPrime) & 0xFFFFFFFFFFFFFFFF;
    }
    return 'fnv1a64:${hash.toRadixString(16).padLeft(16, '0')}';
  }
}
