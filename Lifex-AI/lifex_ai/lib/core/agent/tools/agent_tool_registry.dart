/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_tool_registry.dart
/// المسار: lib/core/agent/tools/agent_tool_registry.dart
/// الوصف: سجل الأدوات المركزي (بند 8). هذا هو المكان الوحيد المسموح له
/// فعلياً بتنفيذ أداة — AgentExecutor والوكلاء المتخصصون يطلبون التنفيذ
/// من هنا فقط، ولا يستدعون AgentTool.execute() مباشرة، لضمان مرور كل
/// عملية عبر فحص الصلاحيات + التسجيل + Timeout معاً دون استثناء.
/// =============================================================
library;

import 'dart:async';

import '../agent_context.dart';
import '../agent_error.dart';
import '../agent_logger.dart';
import 'agent_tool.dart';

class AgentToolRegistry {
  AgentToolRegistry({AgentLogger? logger})
      : _logger = logger ?? AgentLogger.instance;

  final AgentLogger _logger;
  final Map<String, AgentTool> _tools = {};

  /// مهلة افتراضية لأي أداة لا تحدد مهلتها الخاصة (بند 33: وضع
  /// Timeout للأدوات لمنع تعليق المهمة إلى ما لا نهاية).
  static const Duration defaultToolTimeout = Duration(seconds: 30);

  void register(AgentTool tool) {
    if (_tools.containsKey(tool.name)) {
      throw StateError(
          'أداة بنفس الاسم مسجّلة بالفعل: ${tool.name}. الأسماء يجب أن تبقى فريدة وثابتة.');
    }
    _tools[tool.name] = tool;
  }

  void registerAll(Iterable<AgentTool> tools) {
    for (final tool in tools) {
      register(tool);
    }
  }

  bool has(String toolName) => _tools.containsKey(toolName);

  AgentTool? _find(String toolName) => _tools[toolName];

  List<String> get registeredToolNames => _tools.keys.toList(growable: false);

  /// نقطة التنفيذ الموحدة الوحيدة. الترتيب إلزامي:
  /// 1) التحقق من وجود الأداة.
  /// 2) التحقق من الصلاحيات (بما فيها التأكيد البشري للإجراءات عالية
  ///    الخطورة — بند 15).
  /// 3) فحص المدخلات (validate).
  /// 4) التنفيذ الفعلي مع Timeout.
  /// 5) تسجيل العملية في Audit Log (بند 19) — دائماً، نجاحاً أو فشلاً.
  Future<AgentToolExecutionResult> executeTool({
    required String toolName,
    required Map<String, dynamic> arguments,
    required AgentContext context,
    required String actionId,
    required String sessionId,
    Duration? timeout,
  }) async {
    final tool = _find(toolName);

    if (tool == null) {
      final error = ToolNotFoundError(toolName);
      _log(sessionId, context.taskId, toolName, 'tool_not_found', error.code);
      return AgentToolExecutionResult.failure(error.message);
    }

    final permissionError = _checkPermissions(tool, context, actionId);
    if (permissionError != null) {
      _log(sessionId, context.taskId, toolName, 'permission_denied',
          permissionError.code);
      return AgentToolExecutionResult.failure(permissionError.message);
    }

    if (!tool.validate(arguments)) {
      final error = InvalidArgumentsError(
        'مدخلات غير صالحة للأداة $toolName.',
        sourceToolName: toolName,
      );
      _log(sessionId, context.taskId, toolName, 'invalid_arguments',
          error.code);
      return AgentToolExecutionResult.failure(error.message);
    }

    try {
      final result = await tool
          .execute(arguments: arguments, context: context)
          .timeout(timeout ?? defaultToolTimeout);

      _log(
        sessionId,
        context.taskId,
        toolName,
        result.isSuccess ? 'tool_succeeded' : 'tool_failed',
        result.isSuccess ? null : 'TOOL_EXECUTION_FAILED',
      );

      return result;
    } on TimeoutException {
      final error = AgentTimeoutError(
        'انتهت مهلة تنفيذ الأداة $toolName.',
        sourceToolName: toolName,
      );
      _log(sessionId, context.taskId, toolName, 'tool_timeout', error.code);
      return AgentToolExecutionResult.failure(error.message);
    } catch (e) {
      // لا نُخفي الخطأ بـ catch عام صامت (بند 27) — نحوّله لنوع صريح
      // ونسجّله دائماً قبل إعادته.
      final error = ToolExecutionFailedError(
        'فشل تنفيذ الأداة $toolName بسبب خطأ غير متوقع.',
        sourceToolName: toolName,
        originalException: e,
      );
      _log(sessionId, context.taskId, toolName, 'tool_exception', error.code);
      return AgentToolExecutionResult.failure(error.message);
    }
  }

  AgentError? _checkPermissions(
    AgentTool tool,
    AgentContext context,
    String actionId,
  ) {
    final spec = tool.permissionSpec;

    if (!context.permissions.hasAll(spec.requiredPermissions)) {
      return PermissionDeniedError(
        'الصلاحيات المطلوبة غير ممنوحة لتنفيذ ${tool.name}.',
        sourceToolName: tool.name,
      );
    }

    if (spec.effectivelyRequiresHumanConfirmation &&
        !context.permissions.isActionConfirmed(actionId)) {
      return PermissionDeniedError(
        'الإجراء ${tool.name} عالي الخطورة ويتطلب تأكيداً بشرياً صريحاً قبل التنفيذ.',
        sourceToolName: tool.name,
      );
    }

    return null;
  }

  void _log(
    String sessionId,
    String taskId,
    String toolName,
    String eventType,
    String? errorCode,
  ) {
    _logger.log(AgentAuditEntry(
      sessionId: sessionId,
      taskId: taskId,
      agentName: 'ToolRegistry',
      eventType: eventType,
      statusNote: toolName,
      errorCode: errorCode,
    ));
  }
}
