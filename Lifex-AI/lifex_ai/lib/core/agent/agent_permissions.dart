/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_permissions.dart
/// المسار: lib/core/agent/agent_permissions.dart
/// الوصف: نموذج الصلاحيات ومستوى الخطورة (بند 15، 16، 29). يُستخدم من
/// AgentToolRegistry قبل تنفيذ أي أداة، ومن AgentSafetyPolicy لتحديد
/// متى يجب إيقاف التنفيذ وطلب تأكيد بشري (Human-in-the-Loop).
/// =============================================================
library;

/// مستوى خطورة الإجراء. أي أداة تُصنَّف [medical]/[financial]/[security]
/// عالية الخطورة تتطلب دائماً تأكيداً بشرياً صريحاً قبل التنفيذ الفعلي،
/// بصرف النظر عن أي إعداد آخر — هذا مفروض في AgentSafetyPolicy ولا يجوز
/// لأي أداة تجاوزه ذاتياً.
enum AgentActionRiskLevel {
  low, // قراءة معلومة، بحث في معرفة محلية
  medium, // تحليل بيانات المستخدم، استدعاء API خارجي بمعلومات غير حساسة
  high, // أي قرار طبي/دوائي/مالي/أمني، أو إرسال بيانات صحية لطرف خارجي
}

/// الصلاحيات التي قد تحتاجها أداة معيّنة للعمل. يُطابقها AgentToolRegistry
/// مع الصلاحيات الممنوحة فعلياً في AgentContext قبل السماح بالتنفيذ.
enum AgentPermission {
  readKnowledgeBase,
  readUserDocuments,
  readUserImages,
  readHealthProfile,
  useExternalAiProvider,
  generateReport,
  sendNotification,
  writeMemory,
}

/// وصف صلاحية أداة واحدة: أي أذونات تحتاجها ومستوى خطورتها. تُبنى من
/// كل AgentTool وتُفحص مركزياً بدل ترك كل أداة تقرر بنفسها.
class AgentToolPermissionSpec {
  const AgentToolPermissionSpec({
    required this.requiredPermissions,
    required this.riskLevel,
    this.requiresHumanConfirmation = false,
  });

  final Set<AgentPermission> requiredPermissions;
  final AgentActionRiskLevel riskLevel;

  /// إذا كانت true، فلا يجوز لـ AgentToolRegistry تنفيذ هذه الأداة إلا
  /// بعد تأكيد بشري صريح مسجّل في AgentContext لهذه الخطوة تحديداً —
  /// بصرف النظر عن riskLevel (بعض الأدوات متوسطة الخطر لكنها تتطلب
  /// تأكيداً لأسباب سياسة، مثل إرسال إشعار لطرف ثالث).
  final bool requiresHumanConfirmation;

  /// أي أداة عالية الخطورة تتطلب تأكيداً بشرياً حتماً — هذا يُفرض هنا
  /// كخاصية مشتقة، وليس شيئاً قد ينساه مطوّر أداة جديدة.
  bool get effectivelyRequiresHumanConfirmation =>
      requiresHumanConfirmation || riskLevel == AgentActionRiskLevel.high;
}

/// الصلاحيات الممنوحة فعلياً لمهمة وكيل واحدة — تُبنى مرة عند بدء
/// المهمة (مثلاً من إعدادات المستخدم/الحساب) ولا تتغير أثناء التنفيذ.
class AgentGrantedPermissions {
  const AgentGrantedPermissions({
    required this.granted,
    this.humanConfirmedActionIds = const {},
  });

  final Set<AgentPermission> granted;

  /// معرّفات الإجراءات (AgentAction.actionId) التي أكّد المستخدم صراحة
  /// تنفيذها. لا يكفي "منح صلاحية عامة" لتنفيذ إجراء عالي الخطورة —
  /// يجب تأكيد كل إجراء بعينه (بند 15).
  final Set<String> humanConfirmedActionIds;

  bool has(AgentPermission permission) => granted.contains(permission);

  bool hasAll(Set<AgentPermission> permissions) =>
      permissions.every(granted.contains);

  bool isActionConfirmed(String actionId) =>
      humanConfirmedActionIds.contains(actionId);

  AgentGrantedPermissions withConfirmedAction(String actionId) {
    return AgentGrantedPermissions(
      granted: granted,
      humanConfirmedActionIds: {...humanConfirmedActionIds, actionId},
    );
  }
}
