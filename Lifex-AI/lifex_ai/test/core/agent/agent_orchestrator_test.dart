// =============================================================
// Lifex-AI — اختبارات التكامل
// الملف: agent_orchestrator_test.dart
// المسار: test/core/agent/agent_orchestrator_test.dart
// الوصف: اختبار تكامل لدورة حياة مهمة كاملة عبر Coordinator: فهم →
// تخطيط → تنفيذ → تحقق → اكتمال، بأدوات وهمية بسيطة (بدون شبكة أو
// قاعدة بيانات فعلية)، يغطي: سؤال معرفي بسيط، طلب بلا نية واضحة،
// إلغاء أثناء التنفيذ (بند 34).
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
import 'package:lifex_ai/core/agent/tools/agent_tool.dart';
import 'package:lifex_ai/core/agent/tools/agent_tool_registry.dart';
import '../../support/knowledge_retriever_test_doubles.dart';

/// أداة بحث معرفة وهمية — تُرجع دائماً نتيجة نجاح بسيطة كافية لبناء
/// تقرير، دون الاعتماد على قاعدة بيانات JSON فعلية.
class _FakeKnowledgeSearchTool implements AgentTool {
  @override
  String get name => 'knowledge_search';

  @override
  String get descriptionAr => 'بحث وهمي';

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
    return const AgentToolExecutionResult.success({
      'dataType': 'knowledge_search',
      'matchCount': 1,
      'items': [
        {'id': 'd001', 'category': 'disease', 'sourceFile': 'diseases_database.json'}
      ],
      'confidence': 'medium',
    });
  }
}

void main() {
  late AgentOrchestrator orchestrator;

  setUp(() {
    final registry = AgentToolRegistry()
      ..register(_FakeKnowledgeSearchTool())
      ..register(const _FakeReportGeneratorTool());

    final executor = AgentExecutor(
      toolRegistry: registry,
      validator: AgentValidator(),
    );

    final memory = AgentMemory();

    orchestrator = AgentOrchestrator(
      planner: const AgentPlanner(),
      executor: executor,
      memory: memory,
      knowledgeRetriever: const StubKnowledgeRetriever(),
    );
  });

  group('AgentOrchestrator.runTask', () {
    test('سؤال معرفي عام ينتقل عبر الحالات الصحيحة وينتهي completed',
        () async {
      final context = AgentContext(
        taskId: 'task_general',
        profileId: 'p1',
        userRequest: 'ما فوائد شرب الماء؟',
        permissions: const AgentGrantedPermissions(granted: {}),
      );

      final visitedStates = <AgentTaskState>[];

      final result = await orchestrator.runTask(
        context: context,
        sessionId: 'session1',
        onProgress: (state, _) => visitedStates.add(state),
      );

      expect(result.isSuccessful, isTrue);
      expect(result.finalState, AgentTaskState.completed);
      expect(visitedStates, contains(AgentTaskState.understanding));
      expect(visitedStates, contains(AgentTaskState.planning));
      expect(visitedStates, contains(AgentTaskState.executing));
      expect(visitedStates, contains(AgentTaskState.validating));
      expect(visitedStates.last, AgentTaskState.completed);
    });

    test('طلب فارغ بلا نية واضحة يُحظر بأمان (blocked) دون تنفيذ أي أداة',
        () async {
      final context = AgentContext(
        taskId: 'task_empty',
        profileId: 'p1',
        userRequest: '   ',
        permissions: const AgentGrantedPermissions(granted: {}),
      );

      final result = await orchestrator.runTask(
        context: context,
        sessionId: 'session2',
      );

      expect(result.isSuccessful, isFalse);
      expect(result.finalState, AgentTaskState.failed);
    });

    test('النتيجة تحتوي دائماً تنويهاً غير فارغ (بند 38/31)', () async {
      final context = AgentContext(
        taskId: 'task_disclaimer',
        profileId: 'p1',
        userRequest: 'ما فوائد شرب الماء؟',
        permissions: const AgentGrantedPermissions(granted: {}),
      );

      final result = await orchestrator.runTask(
        context: context,
        sessionId: 'session3',
      );

      expect(result.disclaimerAr, isNotEmpty);
    });
  });
}

class _FakeReportGeneratorTool implements AgentTool {
  const _FakeReportGeneratorTool();

  @override
  String get name => 'report_generator';

  @override
  String get descriptionAr => 'مولّد تقرير وهمي';

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
    return const AgentToolExecutionResult.success({
      'dataType': 'final_report',
      'sections': [
        {'titleAr': 'نتائج', 'contentAr': 'محتوى تجريبي'}
      ],
      'sourceFiles': ['diseases_database.json'],
      'confidence': 'medium',
      'reportKindAr': 'تحليل مساعد وليس قراراً سريرياً',
    });
  }
}
