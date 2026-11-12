/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_model_client.dart
/// المسار: lib/core/agent/agent_model_client.dart
/// الوصف: AgentModelClient (بند 25) — الطبقة التي ترسل السياق وتعريفات
/// الأدوات لمزوّد الذكاء الاصطناعي وتستقبل رده.
///
/// ⚠️ ملاحظة صدق تقنية إلزامية (بند 39: "لا تستخدم حلولاً وهمية"):
/// عملاء المحرك الخارجي الموجودون فعلاً في
/// features/ai/ai_service_router.dart (GeminiEngineClient/OpenAiEngineClient/
/// ClaudeEngineClient) يرسلون نصاً خاماً ويستقبلون نصاً خاماً فقط —
/// لا يدعمون بروتوكول "استدعاء أدوات" (Function/Tool Calling) الرسمي
/// لكل مزوّد (وهو بروتوكول مختلف الشكل عند Gemini/OpenAI/Claude ثلاثتهم).
///
/// لذلك:
/// - هذا الملف يوفّر abstraction حقيقياً وحدوداً واضحة (العقد أدناه).
/// - المسار العامل فعلياً الآن هو "استدلال النية من نص حر" (نطلب من
///   المحرك اختيار اسم أداة كنص JSON بسيط ضمن الرد، ثم نحلّله)، وهو
///   أسلوب معروف باسم "ReAct-style prompting" ويعمل مع أي عميل نصي
///   حالي دون تعديله.
/// - لتفعيل Tool Calling الرسمي لاحقاً: أضف دالة `sendQueryWithTools`
///   لكل عميل في ai_service_router.dart تبني حقل `tools`/`functions`
///   الخاص ببروتوكول كل مزوّد (راجع توثيق كل مزوّد)، ثم نفّذ
///   [NativeToolCallingModelClient] هنا بدل [PromptBasedModelClient].
/// =============================================================
library;

import 'dart:convert';

import '../../features/ai/ai_service_router.dart';
import 'agent_context.dart';
import 'agent_error.dart';

class AgentToolDefinition {
  const AgentToolDefinition({
    required this.name,
    required this.descriptionAr,
    required this.inputSchema,
  });

  final String name;
  final String descriptionAr;
  final Map<String, String> inputSchema;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': descriptionAr,
        'inputSchema': inputSchema,
      };
}

/// قرار النموذج بعد استقبال السياق: إما استدعاء أداة، أو رد نهائي.
class ModelDecision {
  const ModelDecision.toolCall({
    required this.toolName,
    required this.toolArguments,
  })  : isFinalAnswer = false,
        finalAnswerAr = null;

  const ModelDecision.finalAnswer(String answer)
      : isFinalAnswer = true,
        finalAnswerAr = answer,
        toolName = null,
        toolArguments = null;

  final bool isFinalAnswer;
  final String? finalAnswerAr;
  final String? toolName;
  final Map<String, dynamic>? toolArguments;
}

/// العقد الذي يعتمد عليه AgentOrchestrator — لا يعرف الأخير أي تفاصيل
/// عن Gemini/ChatGPT/Claude، فقط هذا العقد (بند 24: AIProvider
/// abstraction، مبني هنا فوق UnifiedAiHubGateway الموجود فعلاً).
abstract class AgentModelClient {
  Future<ModelDecision> decide({
    required AgentContext context,
    required List<AgentToolDefinition> availableTools,
    required List<Map<String, dynamic>> priorToolResults,
  });
}

/// التنفيذ العامل فعلياً الآن — يستخدم AiServiceRouter/
/// UnifiedAiHubGateway الموجودين بدون تعديلهما، عبر أسلوب "اطلب رداً
/// بصيغة JSON محددة" بدل بروتوكول Tool Calling الرسمي (انظر الملاحظة
/// أعلى الملف). يبقى استخدام هذا اختيارياً: Coordinator/الخطط
/// المبنية على قواعد صريحة (AgentPlanner) لا تحتاج هذا الملف إطلاقاً؛
/// هو مخصص فقط للحالات التي تحتاج فعلاً استدلال النموذج الحر لاختيار
/// أداة غير محسومة سلفاً بقاعدة.
class PromptBasedModelClient implements AgentModelClient {
  PromptBasedModelClient({
    required AiServiceRouter serviceRouter,
    required this.profileId,
  }) : _serviceRouter = serviceRouter;

  final AiServiceRouter _serviceRouter;
  final String profileId;

  @override
  Future<ModelDecision> decide({
    required AgentContext context,
    required List<AgentToolDefinition> availableTools,
    required List<Map<String, dynamic>> priorToolResults,
  }) async {
    final prompt = _buildPrompt(context, availableTools, priorToolResults);

    final response = await _serviceRouter.query(
      profileId: profileId,
      userQuery: prompt,
    );

    if (!response.success || response.responseText == null) {
      throw ModelError(response.errorMessageAr ?? 'فشل استدعاء النموذج.');
    }

    return _parseDecision(response.responseText!);
  }

  String _buildPrompt(
    AgentContext context,
    List<AgentToolDefinition> tools,
    List<Map<String, dynamic>> priorResults,
  ) {
    final toolsJson = jsonEncode(tools.map((t) => t.toJson()).toList());
    final requestData = context.forModelRequest();

    return '''
أنت طبقة تخطيط تنفيذي داخل Lifex-AI Agent. لديك الأدوات التالية فقط:
$toolsJson

طلب المستخدم: ${requestData['userRequest']}

نتائج أدوات سابقة في نفس المهمة: ${jsonEncode(priorResults)}

إن احتجت أداة، أجب بصيغة JSON فقط بالشكل:
{"action": "tool_call", "tool": "اسم_الأداة", "arguments": {}}

وإن كان لديك رد نهائي كافٍ، أجب بصيغة JSON فقط بالشكل:
{"action": "final_answer", "answer": "نص الرد"}

لا تُضف أي نص خارج كائن JSON.
''';
  }

  ModelDecision _parseDecision(String rawResponse) {
    try {
      final cleaned = rawResponse
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
      final action = decoded['action'] as String?;

      if (action == 'tool_call') {
        final toolName = decoded['tool'] as String?;
        if (toolName == null) {
          throw const ModelError('رد النموذج لا يحدد اسم أداة صالحاً.');
        }
        return ModelDecision.toolCall(
          toolName: toolName,
          toolArguments:
              (decoded['arguments'] as Map<String, dynamic>?) ?? const {},
        );
      }

      if (action == 'final_answer') {
        final answer = decoded['answer'] as String?;
        return ModelDecision.finalAnswer(
            answer ?? 'تعذّر الحصول على رد نهائي واضح.');
      }

      throw const ModelError('رد النموذج بصيغة غير متوقعة.');
    } on FormatException {
      // النموذج لم يلتزم بصيغة JSON المطلوبة — هذا خطأ متوقع الحدوث مع
      // بعض المزوّدين، لذا نُعيده كـ ModelError صريح بدل كسر التنفيذ.
      throw const ModelError('تعذّر تحليل رد النموذج كـ JSON صالح.');
    }
  }
}
