/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_executor.dart
/// المسار: lib/core/agent/agent_executor.dart
/// الوصف: منفّذ الخطة (بند 26: Tool Calling Loop). يأخذ AgentPlan وينفّذ
/// خطواته بالترتيب عبر AgentToolRegistry، مع دعم إعادة المحاولة، حد
/// أقصى للدورات (منع Infinite Loop — بند 13/26)، وفحص الإلغاء قبل كل
/// خطوة (بند 20).
/// =============================================================
library;

import 'agent_action.dart';
import 'agent_confidence.dart';
import 'agent_context.dart';
import 'agent_error.dart';
import 'agent_logger.dart';
import 'agent_observation.dart';
import 'agent_planner.dart';
import 'agent_policy.dart';
import 'agent_validator.dart';
import 'memory/short_term_memory.dart';
import 'tools/agent_tool_registry.dart';

class StepExecutionOutcome {
  const StepExecutionOutcome({
    required this.step,
    required this.action,
    required this.observation,
    required this.validation,
  });

  final PlanStep step;
  final AgentAction action;
  final AgentObservation observation;
  final ValidationResult validation;

  bool get succeeded => observation.success && validation.isValid;
}

class AgentExecutor {
  AgentExecutor({
    required AgentToolRegistry toolRegistry,
    required AgentValidator validator,
    AgentSafetyPolicy safetyPolicy = const AgentSafetyPolicy(),
    AgentLogger? logger,
    this.maxRetriesPerStep = 2,
    this.maxTotalIterations = 20,
  })  : _toolRegistry = toolRegistry,
        _validator = validator,
        _safetyPolicy = safetyPolicy,
        _logger = logger ?? AgentLogger.instance;

  final AgentToolRegistry _toolRegistry;
  final AgentValidator _validator;
  final AgentSafetyPolicy _safetyPolicy;
  final AgentLogger _logger;

  /// حد أقصى لإعادة محاولة نفس الخطوة (بند 13: "يجب وضع حد أقصى
  /// لإعادة المحاولة لمنع Loop لا نهائي").
  final int maxRetriesPerStep;

  /// حد أقصى لعدد دورات التنفيذ الكلي عبر كل خطوات الخطة (بند 26).
  final int maxTotalIterations;

  int _actionCounter = 0;

  String _nextActionId(String taskId) => '${taskId}_a${_actionCounter++}';

  /// تنفيذ خطة كاملة، خطوة فخطوة، مع احترام الاعتماديات بين الخطوات
  /// (dependsOnStepIds). يتوقف فوراً عند الإلغاء أو تجاوز الحد الأقصى.
  Future<List<StepExecutionOutcome>> executePlan({
    required AgentPlan plan,
    required AgentContext context,
    required ShortTermMemory shortTermMemory,
    required String sessionId,
  }) async {
    final outcomes = <StepExecutionOutcome>[];
    final succeededStepIds = <String>{};
    int iterations = 0;

    for (final step in plan.steps) {
      if (context.isCancelled) {
        throw const UserCancelledError();
      }

      if (iterations >= maxTotalIterations) {
        throw MaxIterationsExceededError(maxTotalIterations);
      }

      // لا تُنفَّذ خطوة تعتمد على خطوة سابقة فشلت — بدل تمرير بيانات
      // ناقصة بصمت لأداة لاحقة.
      final unmetDependency = step.dependsOnStepIds
          .any((depId) => !succeededStepIds.contains(depId));
      if (unmetDependency) {
        continue;
      }

      final outcome = await _executeStepWithRetry(
        step: step,
        context: context,
        shortTermMemory: shortTermMemory,
        sessionId: sessionId,
      );
      outcomes.add(outcome);
      iterations++;

      if (outcome.succeeded) {
        succeededStepIds.add(step.stepId);
      }
    }

    return outcomes;
  }

  Future<StepExecutionOutcome> _executeStepWithRetry({
    required PlanStep step,
    required AgentContext context,
    required ShortTermMemory shortTermMemory,
    required String sessionId,
  }) async {
    int attempt = 0;
    StepExecutionOutcome? lastOutcome;

    while (attempt <= maxRetriesPerStep) {
      if (context.isCancelled) {
        throw const UserCancelledError();
      }

      final actionId = _nextActionId(context.taskId);
      final action = AgentAction(
        actionId: actionId,
        toolName: step.toolName,
        arguments: _buildArgumentsFor(step, shortTermMemory, context),
        reason: step.descriptionAr,
      );

      shortTermMemory.recordAction(action);
      _logAction(sessionId, context.taskId, action, 'action_dispatched');

      final toolResult = await _toolRegistry.executeTool(
        toolName: step.toolName,
        arguments: action.arguments,
        context: context,
        actionId: actionId,
        sessionId: sessionId,
      );

      final observation = toolResult.isSuccess
          ? AgentObservation.success(
              actionId: actionId,
              data: toolResult.data,
              confidence: _confidenceFromData(toolResult.data),
              notesAr: toolResult.notesAr,
            )
          : AgentObservation.failure(
              actionId: actionId,
              error: ToolExecutionFailedError(
                toolResult.errorMessageAr ?? 'فشل غير محدد.',
                sourceToolName: step.toolName,
              ),
              notesAr: toolResult.errorMessageAr,
            );

      shortTermMemory.recordObservation(observation);

      // فحص سلامة المخرجات بعد التنفيذ (بند 16) قبل التحقق التفصيلي.
      final sanityCheck = observation.success
          ? _safetyPolicy.checkOutputSanity(observation.data)
          : SafetyCheckResult.allowed; // فشل الأداة نفسه يُعالَج أدناه

      final effectiveObservation = sanityCheck.isAllowed
          ? observation
          : AgentObservation.failure(
              actionId: actionId,
              error: ToolExecutionFailedError(sanityCheck.reasonAr,
                  sourceToolName: step.toolName),
            );

      final validation = _validator.validate(effectiveObservation);

      final outcome = StepExecutionOutcome(
        step: step,
        action: action.copyWith(
          status: effectiveObservation.success
              ? AgentActionStatus.succeeded
              : AgentActionStatus.failed,
        ),
        observation: effectiveObservation,
        validation: validation,
      );

      _logAction(
        sessionId,
        context.taskId,
        outcome.action,
        outcome.succeeded ? 'step_succeeded' : 'step_failed',
        observation: effectiveObservation,
      );

      if (outcome.succeeded) return outcome;

      lastOutcome = outcome;

      if (validation.outcome != ValidationOutcome.retry) {
        // فشل غير قابل لإعادة المحاولة وفق الـ Validator (يحتاج
        // replan أو تدخل مستخدم) — لا فائدة من إعادة نفس الشيء.
        break;
      }

      attempt++;
    }

    return lastOutcome!;
  }

  /// يبني وسائط الخطوة من السياق والذاكرة قصيرة الأمد لنفس المهمة —
  /// يسمح لخطوة لاحقة (مثل report_generator) بالوصول لمخرجات خطوة
  /// سابقة (مثل النص المستخرج من document_reader) دون إعادة تنفيذها.
  Map<String, dynamic> _buildArgumentsFor(
    PlanStep step,
    ShortTermMemory shortTermMemory,
    AgentContext context,
  ) {
    return {
      'userRequest': context.userRequest,
      'taskContext': context.taskContext,
      'priorObservations': shortTermMemory.observations
          .where((o) => o.success)
          .map((o) => o.data)
          .toList(),
    };
  }

  /// استنتاج مستوى ثقة أولي من بيانات الأداة إن كانت تحمله صراحة، وإلا
  /// افتراضي متوسط. الوكلاء المتخصصون قد يعدّلون هذا لاحقاً عبر
  /// AgentConfidence.combineWith عند تجميع عدة نتائج.
  AgentConfidence _confidenceFromData(Map<String, dynamic>? data) {
    final raw = data?['confidence'] as String?;
    switch (raw) {
      case 'high':
        return AgentConfidence.high;
      case 'low':
        return AgentConfidence.low;
      case 'unknown':
        return AgentConfidence.unknown;
      default:
        return AgentConfidence.medium;
    }
  }

  void _logAction(
    String sessionId,
    String taskId,
    AgentAction action,
    String eventType, {
    AgentObservation? observation,
  }) {
    _logger.log(AgentAuditEntry(
      sessionId: sessionId,
      taskId: taskId,
      agentName: 'Executor',
      eventType: eventType,
      action: action,
      observation: observation,
    ));
  }
}
