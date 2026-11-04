// =============================================================
// Lifex-AI — اختبارات التكامل
// الملف: coordinator_agent_test.dart
// المسار: test/core/agent/agents/coordinator_agent_test.dart
// الوصف: يختبر أهم قاعدة سلامة في كامل الطبقة (بند 15): عندما يُكتشف
// مؤشر طوارئ حرج/عالي الخطورة، يجب أن تتوقف المهمة العادية فوراً
// وتُعاد نتيجة "blocked" تطلب انتباهاً بشرياً — دون تنفيذ أي أداة على
// الإطلاق، حتى لو كانت الخطة قد تنجح لولا ذلك.
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/agent/agent_context.dart';
import 'package:lifex_ai/core/agent/agent_executor.dart';
import 'package:lifex_ai/core/agent/agent_memory.dart';
import 'package:lifex_ai/core/agent/agent_orchestrator.dart';
import 'package:lifex_ai/core/agent/agent_permissions.dart';
import 'package:lifex_ai/core/agent/agent_planner.dart';
import 'package:lifex_ai/core/agent/agent_state.dart';
import 'package:lifex_ai/core/agent/agent_validator.dart';
import 'package:lifex_ai/core/agent/agents/coordinator_agent.dart';
import 'package:lifex_ai/core/agent/agents/emergency_agent.dart';
import 'package:lifex_ai/core/agent/agents/knowledge_agent.dart';
import 'package:lifex_ai/core/agent/agents/medical_agent.dart';
import 'package:lifex_ai/core/agent/agents/report_agent.dart';
import 'package:lifex_ai/core/agent/agents/vision_agent.dart';
import 'package:lifex_ai/core/agent/tools/agent_tool.dart';
import 'package:lifex_ai/core/agent/tools/agent_tool_registry.dart';
import '../../../support/knowledge_retriever_test_doubles.dart';

/// أداة يجب ألا تُستدعى أبداً في سيناريو الطوارئ — أي استدعاء لها
/// يعني رسوب الاختبار.
class _MustNotBeCalledTool implements AgentTool {
  bool wasCalled = false;

  @override
  String get name => 'must_not_be_called';

  @override
  String get descriptionAr => 'اختبار';

  @override
  Map<String, String> get inputSchema => const {};

  @override
  AgentToolPermissionSpec get permissionSpec => const AgentToolPermissionSpec(
        requiredPermissions: {},
        riskLevel: AgentActionRiskLevel.low,
      );

  @override
  bool validate(Map<String, dynamic> arguments) => true;

  @override
  Future<AgentToolExecutionResult> execute({
    required Map<String, dynamic> arguments,
    required AgentContext context,
  }) async {
    wasCalled = true;
    return const AgentToolExecutionResult.success({'ok': true});
  }
}

void main() {
  group('CoordinatorAgent.handleUserRequest — emergency short-circuit', () {
    test('مؤشر طوارئ حرج يوقف المهمة قبل أي تنفيذ ويطلب انتباهاً بشرياً',
        () async {
      final probeTool = _MustNotBeCalledTool();
      final registry = AgentToolRegistry()..register(probeTool);

      final executor = AgentExecutor(
        toolRegistry: registry,
        validator: AgentValidator(),
      );

      final orchestrator = AgentOrchestrator(
        planner: const AgentPlanner(),
        executor: executor,
        memory: AgentMemory(),
        knowledgeRetriever: const StubKnowledgeRetriever(),
      );

      final coordinator = CoordinatorAgent(
        orchestrator: orchestrator,
        emergencyAgent: EmergencyAgent(),
        medicalAgent: MedicalAgent(),
        visionAgent: const VisionAgent(),
        knowledgeAgent: KnowledgeAgent(retriever: const StubKnowledgeRetriever()),
        reportAgent: const ReportAgent(),
      );

      final context = AgentContext(
        taskId: 'emergency_task',
        profileId: 'p1',
        userRequest: 'ما فوائد شرب الماء؟', // طلب عادي تماماً
        permissions: const AgentGrantedPermissions(granted: {}),
      );

      final result = await coordinator.handleUserRequest(
        context: context,
        sessionId: 'session1',
        emergencyTriggerContext: const {'triggerType': 'cardiac_symptom'},
      );

      expect(result.finalState, AgentTaskState.blocked);
      expect(probeTool.wasCalled, isFalse,
          reason: 'لا يجوز تنفيذ أي أداة أثناء حالة طوارئ حرجة غير مؤكَّدة');
    });

    test('غياب مؤشر طوارئ يسمح بالتنفيذ العادي كاملاً', () async {
      final registry = AgentToolRegistry();
      final executor = AgentExecutor(
        toolRegistry: registry,
        validator: AgentValidator(),
      );

      final orchestrator = AgentOrchestrator(
        planner: const AgentPlanner(),
        executor: executor,
        memory: AgentMemory(),
        knowledgeRetriever: const StubKnowledgeRetriever(),
      );

      final coordinator = CoordinatorAgent(
        orchestrator: orchestrator,
        emergencyAgent: EmergencyAgent(),
        medicalAgent: MedicalAgent(),
        visionAgent: const VisionAgent(),
        knowledgeAgent: KnowledgeAgent(retriever: const StubKnowledgeRetriever()),
        reportAgent: const ReportAgent(),
      );

      final context = AgentContext(
        taskId: 'normal_task',
        profileId: 'p1',
        userRequest: '', // بلا نية واضحة → ستفشل الخطة، لكن دون طوارئ
        permissions: const AgentGrantedPermissions(granted: {}),
      );

      final result = await coordinator.handleUserRequest(
        context: context,
        sessionId: 'session2',
        // بلا emergencyTriggerContext إطلاقاً
      );

      // لم تُحظر بسبب طوارئ — فشلت لسبب مختلف تماماً (لا نية واضحة).
      expect(result.finalState, isNot(AgentTaskState.blocked));
    });
  });
}
