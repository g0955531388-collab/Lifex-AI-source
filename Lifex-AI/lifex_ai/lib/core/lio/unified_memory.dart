/// =============================================================
/// Lifex-AI — ذاكرة موحّدة متعددة الأنواع
/// Memory ≠ Source of Truth. Clinical معزول.
/// =============================================================
library lifex_ai.core.lio.unified_memory;

import 'lio_types.dart';

class LioMemoryRecord {
  const LioMemoryRecord({
    required this.id,
    required this.kind,
    required this.summaryAr,
    required this.createdAt,
    this.sourceRef,
    this.confidence = 0.0,
    this.rebuildableFromSoT = true,
  });

  final String id;
  final LioMemoryKind kind;
  final String summaryAr;
  final DateTime createdAt;
  final String? sourceRef;
  final double confidence;

  /// إن false تُرفض الكتابة — الذاكرة يجب أن تبقى قابلة لإعادة البناء.
  final bool rebuildableFromSoT;
}

/// مخزن ذاكرة جلسة/مشروع — ليس قاعدة مرضى.
class LifexUnifiedMemory {
  final Map<LioMemoryKind, List<LioMemoryRecord>> _byKind = {
    for (final k in LioMemoryKind.values) k: <LioMemoryRecord>[],
  };

  List<LioMemoryRecord> of(LioMemoryKind kind) =>
      List.unmodifiable(_byKind[kind]!);

  /// رفض إدخال clinicalIsolated في مسارات AI العامة.
  bool acceptForGeneralAiContext(LioMemoryKind kind) =>
      kind != LioMemoryKind.clinicalIsolated;

  String? put(LioMemoryRecord record) {
    if (!record.rebuildableFromSoT &&
        record.kind != LioMemoryKind.working) {
      return 'الذاكرة غير القابلة لإعادة البناء مرفوضة خارج Working.';
    }
    if (record.kind == LioMemoryKind.clinicalIsolated) {
      // يُسمح بالتخزين المعزول فقط — لا يُعرَض لسياق AI العام.
    }
    _byKind[record.kind]!.add(record);
    return null;
  }

  /// حزمة سياق لـ LLM — تستبعد السريري دائماً.
  List<LioMemoryRecord> buildGeneralAiContext({
    int maxItems = 40,
  }) {
    final out = <LioMemoryRecord>[];
    for (final kind in LioMemoryKind.values) {
      if (!acceptForGeneralAiContext(kind)) continue;
      out.addAll(_byKind[kind]!);
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (out.length <= maxItems) return List.unmodifiable(out);
    return List.unmodifiable(out.take(maxItems));
  }

  bool get clinicalNeverInGeneralPack {
    final pack = buildGeneralAiContext();
    return pack.every((r) => r.kind != LioMemoryKind.clinicalIsolated);
  }
}
