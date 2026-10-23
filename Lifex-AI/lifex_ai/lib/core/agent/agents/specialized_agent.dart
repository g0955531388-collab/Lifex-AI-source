/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: specialized_agent.dart
/// المسار: lib/core/agent/agents/specialized_agent.dart
/// الوصف: العقد المشترك لكل وكيل متخصص (بند 14/32). كل وكيل متخصص هو
/// طبقة "سياسة/تفسير" رقيقة فوق الأدوات — يقرر أي أداة يستدعي ومتى،
/// ويفسّر نتيجتها ضمن مجاله (طبي/رؤية/معرفة/تقرير/طوارئ)، لكنه لا
/// يُنفّذ عملاً فعلياً بمعزل عن AgentToolRegistry أبداً.
///
/// هذا يسمح بإضافة وكلاء جدد لاحقاً (بند 32: Research/Nutrition/
/// Pharmacy/Device/IoT/Voice/Translation/Document/Security/Personal
/// Assistant Agent) دون تعديل Coordinator — فقط بتطبيق هذا العقد
/// وتسجيل الوكيل الجديد.
/// =============================================================
library;

abstract class SpecializedAgent {
  /// اسم ثابت يُستخدم في التسجيل (Audit Log).
  String get agentName;

  /// وصف مختصر بالعربية لمسؤولية هذا الوكيل — للتوثيق والتتبع فقط.
  String get responsibilityAr;
}
