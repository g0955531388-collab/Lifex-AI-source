/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_policy.dart
/// المسار: lib/core/agent/agent_policy.dart
/// الوصف: AgentSafetyPolicy — تعمل قبل وبعد تنفيذ أي أداة (بند 16).
/// تفحص: نوع البيانات، مستوى الخطورة، صلاحيات المستخدم، الموافقة
/// البشرية، وسلامة المخرجات (بما فيها فحص أساسي لمؤشرات الحقن
/// التعليمي Prompt Injection قادمة من محتوى غير موثوق — بند 30).
/// =============================================================
library;

import 'agent_action.dart';
import 'agent_context.dart';
import 'agent_permissions.dart';

enum SafetyCheckOutcome { allow, blockRequiresConfirmation, blockDenied }

class SafetyCheckResult {
  const SafetyCheckResult({
    required this.outcome,
    required this.reasonAr,
  });

  final SafetyCheckOutcome outcome;
  final String reasonAr;

  bool get isAllowed => outcome == SafetyCheckOutcome.allow;

  static const SafetyCheckResult allowed =
      SafetyCheckResult(outcome: SafetyCheckOutcome.allow, reasonAr: 'مسموح.');
}

/// عبارات شائعة تحاول انتحال صفة تعليمات نظام داخل محتوى مستخدم/ملف
/// (بند 30). هذه مطابقة نصية بسيطة وشفافة كخط دفاع أول فقط — لا تُغني
/// عن فصل Instructions/Untrusted Data المعماري (الذي يُفرض عبر عدم
/// تمرير محتوى المستندات كتعليمات أبداً، بل كبيانات دائماً — انظر
/// DocumentReaderTool).
const List<String> kPromptInjectionMarkersAr = [
  'تجاهل تعليمات النظام',
  'تجاهل التعليمات السابقة',
  'ignore previous instructions',
  'ignore all previous instructions',
  'system prompt',
  'disregard the above',
];

class AgentSafetyPolicy {
  const AgentSafetyPolicy();

  /// فحص قبل التنفيذ: هل يُسمح بهذا الإجراء الآن، أم يحتاج توقفاً
  /// لطلب تأكيد بشري، أم يُرفض تماماً؟
  SafetyCheckResult checkBeforeExecution({
    required AgentAction action,
    required AgentActionRiskLevel riskLevel,
    required AgentContext context,
  }) {
    if (context.isCancelled) {
      return const SafetyCheckResult(
        outcome: SafetyCheckOutcome.blockDenied,
        reasonAr: 'المهمة ملغاة من المستخدم.',
      );
    }

    if (riskLevel == AgentActionRiskLevel.high &&
        !context.permissions.isActionConfirmed(action.actionId)) {
      return const SafetyCheckResult(
        outcome: SafetyCheckOutcome.blockRequiresConfirmation,
        reasonAr:
            'هذا إجراء عالي الخطورة (طبي/دوائي/مالي/أمني) ويتطلب تأكيداً بشرياً صريحاً قبل التنفيذ.',
      );
    }

    return SafetyCheckResult.allowed;
  }

  /// فحص محتوى نصي غير موثوق (نص مستخرج من مستند/صورة/رابط) قبل دمجه
  /// في سياق أي وكيل، للتحذير من محاولات حقن تعليمات (بند 30). لا
  /// يحذف المحتوى ولا يرفضه تلقائياً — فقط يُعلم الطبقات الأعلى حتى
  /// تتعامل معه كبيانات صرفة (Untrusted Data) وليس كتعليمات أبداً.
  bool containsPromptInjectionMarkers(String untrustedText) {
    final normalized = untrustedText.toLowerCase();
    return kPromptInjectionMarkersAr
        .any((marker) => normalized.contains(marker.toLowerCase()));
  }

  /// فحص بعد التنفيذ: سلامة المخرجات الأساسية — هل البيانات فارغة رغم
  /// نجاح ظاهري؟ هل هناك تناقض واضح؟ هذا فحص عام أولي؛ فحوصات أعمق
  /// خاصة بنوع البيانات تبقى في AgentValidator.
  SafetyCheckResult checkOutputSanity(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return const SafetyCheckResult(
        outcome: SafetyCheckOutcome.blockDenied,
        reasonAr: 'المخرجات فارغة رغم نجاح ظاهري للعملية — يُعامَل كفشل.',
      );
    }
    return SafetyCheckResult.allowed;
  }
}
