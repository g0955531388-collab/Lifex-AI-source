/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_tool.dart
/// المسار: lib/core/agent/tools/agent_tool.dart
/// الوصف: العقد الموحّد (Interface) الذي يجب أن تطبّقه أي أداة (بند 7).
/// القاعدة الصارمة: أدوات هذه الطبقة لا تُعيد تنفيذ منطق موجود فعلاً
/// في features/ — بل تكون غلافاً رقيقاً (thin wrapper) يستدعي الخدمة
/// الحقيقية الموجودة (MedicalOcrReader، AiServiceRouter، إلخ) ويحوّل
/// نتيجتها إلى شكل موحّد يفهمه AgentExecutor.
/// =============================================================
library;

import '../agent_context.dart';
import '../agent_permissions.dart';

/// نتيجة تنفيذ أداة واحدة — شكل خام قبل تحويله إلى AgentObservation
/// من قبل AgentExecutor (الذي يضيف معلومات المهمة/الإجراء).
class AgentToolExecutionResult {
  const AgentToolExecutionResult.success(this.data, {this.notesAr})
      : isSuccess = true,
        errorMessageAr = null;

  const AgentToolExecutionResult.failure(this.errorMessageAr)
      : isSuccess = false,
        data = const {},
        notesAr = null;

  final bool isSuccess;
  final Map<String, dynamic> data;
  final String? errorMessageAr;
  final String? notesAr;
}

/// عقد أي أداة قابلة للاستدعاء من الوكيل. لا يجوز لأي وكيل استدعاء
/// خدمة تطبيق مباشرة — كل شيء يمر عبر تطبيق هذا العقد ثم AgentToolRegistry.
abstract class AgentTool {
  /// اسم فريد ثابت (يُستخدم كمفتاح في السجل، ولا يجوز أن يتغيّر بين
  /// الإصدارات لأن الـ Audit Log القديم يشير إليه بالاسم).
  String get name;

  /// وصف مختصر بالعربية — يُستخدم داخلياً لبناء تعريف الأداة المُرسَل
  /// لمزوّد الذكاء الاصطناعي (Tool Definition)، وليس للعرض المباشر.
  String get descriptionAr;

  /// وصف تخطيطي للمدخلات المتوقعة (اسم الحقل → نوعه كنص وصفي). ليس
  /// JSON Schema كاملاً حتى لا نُقحم مكتبة خارجية غير ضرورية؛ يكفي هذا
  /// لتوثيق الأداة وفحص المفاتيح الأساسية في validate().
  Map<String, String> get inputSchema;

  AgentToolPermissionSpec get permissionSpec;

  /// فحص أولي سريع للمدخلات قبل التنفيذ الفعلي — يتحقق من وجود
  /// الحقول المطلوبة وشكلها العام فقط (وليس صحتها الطبية/المنطقية،
  /// فهذا دور AgentValidator بعد التنفيذ).
  bool validate(Map<String, dynamic> arguments);

  /// التنفيذ الفعلي. يجب ألا يُلقي (throw) استثناءً خاماً — أي فشل
  /// متوقع يُعاد كـ AgentToolExecutionResult.failure حتى يبقى مسار
  /// الخطأ صريحاً ومتوقعاً من AgentExecutor.
  Future<AgentToolExecutionResult> execute({
    required Map<String, dynamic> arguments,
    required AgentContext context,
  });
}
