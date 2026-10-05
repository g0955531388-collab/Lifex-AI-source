/// =============================================================
/// Lifex-AI — سجل مصادر المعرفة (في الذاكرة — قابل للاختبار)
/// =============================================================
library lifex_ai.core.lio.knowledge_engine.ingestion.source_registry;

import '../../source_reliability.dart';
import 'source_registry_model.dart';

class SourceRegistrationResult {
  const SourceRegistrationResult({
    required this.accepted,
    this.source,
    this.reasonAr,
  });

  final bool accepted;
  final RegisteredKnowledgeSource? source;
  final String? reasonAr;
}

/// تحقق تسجيل المصدر — الوجود ≠ السلطة.
class KnowledgeSourceValidator {
  const KnowledgeSourceValidator({
    this.reliability = const LifexSourceReliabilityEngine(),
  });

  final LifexSourceReliabilityEngine reliability;

  SourceRegistrationResult validate(RegisteredKnowledgeSource candidate) {
    if (candidate.sourceId.trim().isEmpty) {
      return const SourceRegistrationResult(
        accepted: false,
        reasonAr: 'REJECTED — sourceId فارغ.',
      );
    }
    if (candidate.title.trim().isEmpty) {
      return const SourceRegistrationResult(
        accepted: false,
        reasonAr: 'REJECTED — العنوان فارغ.',
      );
    }
    if (!candidate.isCitable) {
      return const SourceRegistrationResult(
        accepted: false,
        reasonAr: 'REJECTED — مصدر بلا URL/repository/document.',
      );
    }
    final prov = candidate.toProvenance();
    if (!reliability.acceptAsEvidence(prov)) {
      return SourceRegistrationResult(
        accepted: false,
        reasonAr:
            'REJECTED — provenance/authority غير مقبول (weight=${reliability.weightOf(candidate.authority)}).',
      );
    }
    if (candidate.allowedDomains.isEmpty) {
      return const SourceRegistrationResult(
        accepted: false,
        reasonAr: 'REJECTED — لا مجال معرفة مسموح.',
      );
    }
    return SourceRegistrationResult(accepted: true, source: candidate);
  }
}

class InMemoryKnowledgeSourceRegistry {
  InMemoryKnowledgeSourceRegistry({
    KnowledgeSourceValidator? validator,
  }) : validator = validator ?? const KnowledgeSourceValidator();

  final KnowledgeSourceValidator validator;
  final Map<String, RegisteredKnowledgeSource> _byId = {};
  final List<RegisteredKnowledgeSource> _history = [];

  List<RegisteredKnowledgeSource> get all =>
      List.unmodifiable(_byId.values);

  List<RegisteredKnowledgeSource> get history =>
      List.unmodifiable(_history);

  RegisteredKnowledgeSource? get(String sourceId) => _byId[sourceId];

  SourceRegistrationResult register(RegisteredKnowledgeSource candidate) {
    final verdict = validator.validate(candidate);
    if (!verdict.accepted) return verdict;

    final now = DateTime.now();
    final existing = _byId[candidate.sourceId];
    var next = candidate.copyWith(
      firstSeen: existing?.firstSeen ?? candidate.firstSeen ?? now,
      lastSeen: now,
    );

    if (existing != null &&
        existing.version != null &&
        next.version != null &&
        existing.version != next.version) {
      // لا نمحو التاريخ — نؤرشف القديم كـ superseded
      final archived = existing.copyWith(
        status: KnowledgeSourceStatus.superseded,
        supersededBySourceId: next.sourceId,
        lastSeen: now,
      );
      _history.add(archived);
      next = next.copyWith(
        status: KnowledgeSourceStatus.active,
        supersedesSourceId: existing.sourceId,
      );
    } else if (existing != null) {
      _history.add(existing);
    }

    _byId[next.sourceId] = next;
    _history.add(next);
    return SourceRegistrationResult(accepted: true, source: next);
  }
}
