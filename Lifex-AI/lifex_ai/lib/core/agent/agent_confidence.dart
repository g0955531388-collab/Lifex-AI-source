/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_confidence.dart
/// المسار: lib/core/agent/agent_confidence.dart
/// الوصف: تصنيف مستوى الثقة (بند 17). يُرفق بأي نتيجة مهمة قادمة من
/// أداة أو وكيل متخصص. القاعدة الصارمة: لا يجوز لأي طبقة أعلى (خاصة
/// Report Agent أو الواجهة) تحويل [low]/[unknown] إلى نتيجة قطعية —
/// هذا يُفرض برمجياً في AgentValidator وليس فقط توثيقياً.
/// =============================================================
library;

enum AgentConfidence {
  high,
  medium,
  low,
  unknown,
}

extension AgentConfidenceLabel on AgentConfidence {
  /// نص عربي مختصر يُعرض للمستخدم مباشرة.
  String get labelAr {
    switch (this) {
      case AgentConfidence.high:
        return 'مرتفعة';
      case AgentConfidence.medium:
        return 'متوسطة';
      case AgentConfidence.low:
        return 'منخفضة';
      case AgentConfidence.unknown:
        return 'غير معروفة';
    }
  }

  /// هل هذا المستوى منخفض بما يكفي لمنع أي صياغة قطعية في التقرير
  /// النهائي؟ يُستخدم من ReportAgent وValidator معاً.
  bool get requiresHedgedLanguage =>
      this == AgentConfidence.low || this == AgentConfidence.unknown;

  /// دمج مستويين من الثقة (مثلاً عند تجميع نتائج عدة أدوات) — النتيجة
  /// دائماً الأضعف بينهما، لأن السلسلة بقوة أضعف حلقاتها. هذا يمنع
  /// أداة عالية الثقة من "تبييض" نتيجة أداة أخرى منخفضة الثقة.
  AgentConfidence combineWith(AgentConfidence other) {
    const order = [
      AgentConfidence.unknown,
      AgentConfidence.low,
      AgentConfidence.medium,
      AgentConfidence.high,
    ];
    final thisIndex = order.indexOf(this);
    final otherIndex = order.indexOf(other);
    return order[thisIndex < otherIndex ? thisIndex : otherIndex];
  }
}
