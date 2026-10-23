/// =============================================================
/// Lifex-AI — طبقة الوكيل الذكي (AI Agent Layer)
/// الملف: agent_orchestrator.dart
/// المسار: lib/core/agent/agent_orchestrator.dart
/// الوصف: المنسّق المركزي (Coordinator Agent — بند 4). يدير دورة حياة
/// مهمة واحدة كاملة عبر آلة الحالة (agent_state.dart): فهم → تخطيط →
/// تنفيذ → ملاحظة → تحقق → (تكرار أو اكتمال). هذا هو المكوّن الوحيد
/// الذي تستدعيه الواجهة مباشرة (عبر runTask) — لا تتعامل الواجهة مع
/// Planner/Executor/ToolRegistry بشكل منفصل أبداً.
/// =============================================================
library;

import 'agent_confidence.dart';
import 'agent_context.dart';
import 'agent_error.dart';
import 'agent_executor.dart';
import 'agent_logger.dart';
import 'agent_memory.dart';
import 'agent_planner.dart';
import 'agent_result.dart';
import 'agent_state.dart';
import 'knowledge/knowledge_retriever.dart';

/// توقيع دالة الاستماع لتحديثات حالة المهمة الحية — تُستخدم من واجهة
/// "المهمة الحالية" (بند 22) لعرض ✓/●/○ لكل خطوة دون Chain-of-Thought
/// داخلي مكشوف (بند 21).
typedef AgentTaskProgressListener = void Function(
  AgentTaskState state,
  String stepDescriptionAr,
);

class AgentOrchestrator {
  AgentOrchestrator({
    required AgentPlanner planner,
    required AgentExecutor executor,
    required AgentMemory memory,
    required KnowledgeRetriever knowledgeRetriever,
    AgentLogger? logger,
  })  : _planner = planner,
        _executor = executor,
        _memory = memory,
        _knowledgeRetriever = knowledgeRetriever,
        _logger = logger ?? AgentLogger.instance;

  final AgentPlanner _planner;
  final AgentExecutor _executor;
  final AgentMemory _memory;
  final KnowledgeRetriever _knowledgeRetriever;
  final AgentLogger _logger;

  final Map<String, AgentTaskState> _stateByTaskId = {};
  final Map<String, AgentContext> _contextByTaskId = {};

  AgentTaskState stateOf(String taskId) =>
      _stateByTaskId[taskId] ?? AgentTaskState.idle;

  /// طلب إلغاء مهمة قيد التنفيذ (بند 20) — يُفعّل Cancel Token في
  /// AgentContext؛ AgentExecutor يفحصه قبل كل خطوة تالية.
  void cancelTask(String taskId) {
    _contextByTaskId[taskId]?.cancel();
  }

  /// نقطة الدخول الرئيسية: تشغيل مهمة وكيل كاملة من البداية للنهاية.
  Future<AgentResult> runTask({
    required AgentContext context,
    required String sessionId,
    AgentTaskProgressListener? onProgress,
  }) async {
    final taskId = context.taskId;
    _contextByTaskId[taskId] = context;

    try {
      _transition(taskId, AgentTaskState.understanding, onProgress, 'فهم الطلب');

      final intent = _planner.detectIntent(context);
      if (intent == DetectedIntent.unknown) {
        _transition(taskId, AgentTaskState.blocked, onProgress,
            'تعذّر فهم الطلب');
        return _finish(
          AgentResult.failed(
            taskId: taskId,
            reasonAr: 'تعذّر فهم الطلب — يرجى إعادة صياغته بمزيد من التفاصيل.',
          ),
        );
      }

      _transition(taskId, AgentTaskState.planning, onProgress, 'إعداد الخطة');
      final plan = _planner.buildPlan(intent, context);

      if (plan.isEmpty) {
        _transition(taskId, AgentTaskState.blocked, onProgress,
            'لا توجد خطة قابلة للتنفيذ');
        return _finish(
          AgentResult.failed(
              taskId: taskId, reasonAr: 'لا توجد خطة قابلة للتنفيذ لهذا الطلب.'),
        );
      }

      // إثراء السياق بمعرفة ذات صلة قبل التنفيذ (بند 9) — استعلام واحد
      // مبني على طلب المستخدم، وليس تحميل قاعدة المعرفة كاملة.
      final knowledge = await _knowledgeRetriever.retrieve(context.userRequest);
      final enrichedContext = context.copyWith(
        knowledgeContext: knowledge.toContextMap(),
      );
      _contextByTaskId[taskId] = enrichedContext;

      _transition(taskId, AgentTaskState.executing, onProgress, plan.goalAr);

      final shortTermMemory = _memory.shortTermFor(taskId);
      shortTermMemory.currentPlanSummary = plan.goalAr;

      final outcomes = await _executor.executePlan(
        plan: plan,
        context: enrichedContext,
        shortTermMemory: shortTermMemory,
        sessionId: sessionId,
      );

      _transition(taskId, AgentTaskState.observing, onProgress, 'مراجعة النتائج');
      _transition(taskId, AgentTaskState.validating, onProgress, 'التحقق من النتائج');

      final allStepsSucceeded =
          outcomes.isNotEmpty && outcomes.every((o) => o.succeeded);

      if (!allStepsSucceeded) {
        _transition(taskId, AgentTaskState.failed, onProgress,
            'تعذّر إكمال بعض الخطوات');
        return _finish(
          AgentResult.failed(
            taskId: taskId,
            reasonAr: 'تعذّر إكمال خطوة أو أكثر من خطوات المهمة.',
            completedActions: outcomes.map((o) => o.action).toList(),
          ),
        );
      }

      // دمج مستوى الثقة عبر كل الخطوات — الأضعف يفوز (بند 17).
      final combinedConfidence = outcomes
          .map((o) => o.observation.confidence)
          .fold<AgentConfidence>(
            AgentConfidence.high,
            (acc, c) => acc.combineWith(c),
          );

      _transition(taskId, AgentTaskState.completed, onProgress, 'اكتملت المهمة');

      return _finish(
        AgentResult(
          taskId: taskId,
          finalState: AgentTaskState.completed,
          summaryAr: 'تم تنفيذ ${outcomes.length} خطوة بنجاح ضمن: ${plan.goalAr}.',
          confidence: combinedConfidence,
          disclaimerAr: kAgentDefaultDisclaimerAr,
          completedActions: outcomes.map((o) => o.action).toList(),
          reportData: _collectReportData(outcomes),
        ),
      );
    } on UserCancelledError {
      _transition(taskId, AgentTaskState.cancelled, onProgress, 'أُلغيت المهمة');
      return _finish(AgentResult.cancelled(taskId: taskId));
    } on MaxIterationsExceededError catch (e) {
      _transition(taskId, AgentTaskState.failed, onProgress,
          'تجاوزت المهمة الحد الأقصى من الخطوات');
      return _finish(AgentResult.failed(taskId: taskId, reasonAr: e.message));
    } on AgentError catch (e) {
      _transition(taskId, AgentTaskState.failed, onProgress, 'حدث خطأ');
      return _finish(AgentResult.failed(taskId: taskId, reasonAr: e.message));
    } finally {
      _memory.releaseShortTermFor(taskId);
      _contextByTaskId.remove(taskId);
    }
  }

  Map<String, dynamic> _collectReportData(List<StepExecutionOutcome> outcomes) {
    final reportSteps = outcomes
        .where((o) => o.step.toolName == 'report_generator' && o.succeeded)
        .toList();
    if (reportSteps.isEmpty) return const {};
    return reportSteps.first.observation.data ?? const {};
  }

  void _transition(
    String taskId,
    AgentTaskState to,
    AgentTaskProgressListener? onProgress,
    String stepDescriptionAr,
  ) {
    final from = stateOf(taskId);
    if (from != to && !isValidAgentTransition(from, to)) {
      // انتقال غير مسموح به وفق آلة الحالة — نمنعه بدل تجاهله بصمت،
      // حتى تظهر أي أخطاء منطقية في المخطط أثناء التطوير لا بعد النشر.
      throw StateError('انتقال حالة غير صالح: ${from.name} → ${to.name}');
    }

    _stateByTaskId[taskId] = to;
    _logger.log(AgentAuditEntry(
      sessionId: taskId,
      taskId: taskId,
      agentName: 'Coordinator',
      eventType: 'state_transition',
      statusNote: '${to.name}: $stepDescriptionAr',
    ));
    onProgress?.call(to, stepDescriptionAr);
  }

  AgentResult _finish(AgentResult result) {
    return result;
  }
}
