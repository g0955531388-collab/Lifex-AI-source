/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: ai_agent_screen.dart
/// المسار: lib/screens/ai_agent_screen.dart
/// الوصف: شاشة "Lifex-AI Agent" (بند 22). تعرض حالة المهمة الحالية
/// كقائمة خطوات (✓/●/○) دون كشف أي تفكير داخلي للنموذج (بند 21)، مع
/// زر إيقاف المهمة (بند 20)، وتبديل بين وضعي المحادثة والوكيل (بند 23).
/// لا تتعامل هذه الشاشة مع Planner/Executor/ToolRegistry أو Agent مباشرة؛
/// كل تفاعل حسّاس يمر عبر LioSensitiveActionEntry → ProductionLioGateway.
/// =============================================================
library lifex_ai.screens.ai_agent_screen;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/agent/agent_context.dart';
import '../core/agent/agent_permissions.dart';
import '../core/agent/agent_result.dart';
import '../core/agent/agent_state.dart';
import '../core/agent/agents/report_agent.dart';
import '../core/orchestrator/lio_gateway_contracts.dart';
import '../core/orchestrator/lio_sensitive_action_entry.dart';
import '../features/ai/ai_service_router.dart';

enum _AppMode { chat, agent }

class _ProgressStep {
  const _ProgressStep(this.state, this.labelAr);
  final AgentTaskState state;
  final String labelAr;
}

/// ترتيب الخطوات المعروضة للمستخدم — تبسيط مقصود لآلة الحالة الكاملة
/// في agent_state.dart، مطابق لمثال بند 22 في المواصفة تحديداً.
const List<_ProgressStep> _displaySteps = [
  _ProgressStep(AgentTaskState.understanding, 'فهم الطلب'),
  _ProgressStep(AgentTaskState.planning, 'البحث في المعرفة'),
  _ProgressStep(AgentTaskState.executing, 'التحليل'),
  _ProgressStep(AgentTaskState.validating, 'التحقق'),
  _ProgressStep(AgentTaskState.completed, 'التقرير'),
];

class AiAgentScreen extends StatefulWidget {
  const AiAgentScreen({super.key, required this.profileId});

  final String profileId;

  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen> {
  _AppMode _mode = _AppMode.agent;
  final TextEditingController _inputController = TextEditingController();

  bool _isRunning = false;
  String? _currentTaskId;
  AgentTaskState _currentState = AgentTaskState.idle;
  String _currentStepLabelAr = '';
  AgentResult? _lastResult;
  String? _chatReplyAr;

  int _taskCounter = 0;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isRunning) return;

    if (_mode == _AppMode.chat) {
      await _submitChat(text);
    } else {
      await _submitAgentTask(text);
    }
  }

  /// وضع المحادثة: بوابة LIO أولاً ثم AiServiceRouter — ممنوع تجاوز LIO.
  Future<void> _submitChat(String text) async {
    setState(() {
      _isRunning = true;
      _chatReplyAr = null;
    });

    final entry = Provider.of<LioSensitiveActionEntry>(context, listen: false);
    final router = Provider.of<AiServiceRouter>(context, listen: false);
    final outcome = await entry.authorizeThenRun<ExternalAiResponse>(
      request: _gatewayRequest(
        action: 'chat_ai_query',
        purpose: 'knowledge_lookup',
        scope: 'knowledge_public',
        risk: LioActionRisk.low,
      ),
      run: () => router.query(
        profileId: widget.profileId,
        userQuery: text,
      ),
    );

    if (!mounted) return;
    if (!outcome.executed) {
      setState(() {
        _isRunning = false;
        _chatReplyAr =
            'توقف عند LIO (${outcome.decision.wireDecision}): ${outcome.decision.reasonAr}';
      });
      return;
    }
    final response = outcome.value!;
    setState(() {
      _isRunning = false;
      _chatReplyAr = response.success
          ? response.responseText ?? ''
          : (response.errorMessageAr ?? 'تعذّر الحصول على رد.');
    });
  }

  /// وضع الوكيل: بوابة LIO ثم Coordinator عبر LioSensitiveActionEntry فقط.
  Future<void> _submitAgentTask(String text) async {
    final entry = Provider.of<LioSensitiveActionEntry>(context, listen: false);
    final taskId = 'task_${widget.profileId}_${_taskCounter++}';

    setState(() {
      _isRunning = true;
      _currentTaskId = taskId;
      _currentState = AgentTaskState.idle;
      _currentStepLabelAr = '';
      _lastResult = null;
    });

    final agentContext = AgentContext(
      taskId: taskId,
      profileId: widget.profileId,
      userRequest: text,
      permissions: const AgentGrantedPermissions(
        granted: {
          AgentPermission.readKnowledgeBase,
          AgentPermission.generateReport,
          AgentPermission.readUserDocuments,
          AgentPermission.readUserImages,
        },
      ),
    );

    final outcome = await entry.runAgentRequest(
      gatewayRequest: _gatewayRequest(
        action: 'agent_user_request',
        purpose: 'knowledge_lookup',
        scope: 'knowledge_public',
        risk: LioActionRisk.medium,
      ),
      agentContext: agentContext,
      sessionId: taskId,
      onProgress: (state, stepLabelAr) {
        if (!mounted) return;
        setState(() {
          _currentState = state;
          _currentStepLabelAr = stepLabelAr;
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _isRunning = false;
      _lastResult = outcome.executed
          ? outcome.value
          : entry.blockedAgentResult(
              taskId: taskId,
              decision: outcome.decision,
            );
    });
  }

  void _cancelTask() {
    final entry = Provider.of<LioSensitiveActionEntry>(context, listen: false);
    final taskId = _currentTaskId;
    if (taskId != null) {
      entry.cancelAgentTask(taskId);
    }
  }

  LioGatewayRequest _gatewayRequest({
    required String action,
    required String purpose,
    required String scope,
    required LioActionRisk risk,
  }) {
    return LioGatewayRequest(
      requestId: 'ui_${widget.profileId}_${DateTime.now().millisecondsSinceEpoch}',
      correlationId: 'corr_${widget.profileId}',
      identityAccountId: widget.profileId,
      purpose: purpose,
      requestedAction: action,
      dataScope: scope,
      sensitivity: LioDataSensitivity.public,
      consent: const LioConsentContext(
        consentGranted: true,
        purposeAligned: true,
      ),
      riskLevel: risk,
      timestamp: DateTime.now().toUtc(),
      authenticated: true,
      authorized: true,
      minimumNecessarySatisfied: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lifex-AI Agent'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<_AppMode>(
              segments: const [
                ButtonSegment(
                  value: _AppMode.chat,
                  label: Text('محادثة'),
                  icon: Icon(Icons.chat_bubble_outline),
                ),
                ButtonSegment(
                  value: _AppMode.agent,
                  label: Text('وكيل'),
                  icon: Icon(Icons.auto_awesome),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: _isRunning
                  ? null
                  : (selection) => setState(() => _mode = selection.first),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: _mode == _AppMode.agent
                    ? _buildAgentBody()
                    : _buildChatBody(),
              ),
              const SizedBox(height: 12),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatBody() {
    if (_chatReplyAr == null) {
      return const Center(
        child: Text(
          'اطرح سؤالاً صحياً عاماً — رد مباشر دون خطوات تنفيذية.',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }
    return SingleChildScrollView(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_chatReplyAr!),
        ),
      ),
    );
  }

  Widget _buildAgentBody() {
    if (_currentTaskId == null) {
      return const Center(
        child: Text(
          'اطلب تحليل مستند، صورة، أو استفساراً صحياً — سيقوم الوكيل '
          'بتنفيذه عبر عدة خطوات قابلة للتتبع.',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'المهمة الحالية',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  for (final step in _displaySteps)
                    _buildStepRow(step),
                  if (_isRunning) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _cancelTask,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('إيقاف المهمة'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 12),
            _buildResultCard(_lastResult!),
          ],
        ],
      ),
    );
  }

  Widget _buildStepRow(_ProgressStep step) {
    final currentIndex = _displaySteps.indexWhere((s) => s.state == _currentState);
    final thisIndex = _displaySteps.indexOf(step);

    IconData icon;
    Color color;
    if (_lastResult != null && !_lastResult!.isSuccessful) {
      icon = thisIndex <= currentIndex
          ? Icons.circle
          : Icons.circle_outlined;
      color = thisIndex <= currentIndex ? Colors.orange : Colors.grey;
    } else if (thisIndex < currentIndex ||
        (thisIndex == currentIndex && _lastResult?.isSuccessful == true)) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (thisIndex == currentIndex) {
      icon = Icons.circle;
      color = Colors.blue;
    } else {
      icon = Icons.circle_outlined;
      color = Colors.grey;
    }

    final showLiveLabel = thisIndex == currentIndex &&
        _isRunning &&
        _currentStepLabelAr.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.labelAr),
                if (showLiveLabel)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      _currentStepLabelAr,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(AgentResult result) {
    const reportAgent = ReportAgent();
    final displayText = result.reportData != null && result.reportData!.isNotEmpty
        ? reportAgent.buildDisplayTextAr(result.reportData!)
        : '${result.summaryAr}\n\n${result.errorMessageAr ?? ''}\n\n${result.disclaimerAr}';

    return Card(
      color: result.isSuccessful ? null : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.isSuccessful ? Icons.check_circle : Icons.warning_amber,
                  color: result.isSuccessful ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  result.isSuccessful ? 'المهمة اكتملت' : 'تعذّر إكمال المهمة',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(displayText),
            if (result.completedActions.isNotEmpty) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('الأدوات المستخدمة', style: TextStyle(fontSize: 13)),
                children: [
                  for (final action in result.completedActions)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.build_outlined, size: 16),
                      title: Text(action.toolName, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(action.reason, style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _inputController,
            enabled: !_isRunning,
            decoration: InputDecoration(
              hintText: _mode == _AppMode.agent
                  ? 'مثال: حلل هذا التقرير وأنشئ ملخصاً'
                  : 'اطرح سؤالك هنا',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _isRunning ? null : _submit,
          icon: _isRunning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send),
        ),
      ],
    );
  }
}
