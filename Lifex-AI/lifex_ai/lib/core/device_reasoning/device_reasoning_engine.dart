/// =============================================================
/// Lifex-AI — استدلال أجهزة
/// الملف: device_reasoning_engine.dart
/// لا يستدعي السائق. CONTROL غير موثّق → محظور. ناقص المعلومات ≠ سماح.
/// =============================================================
library lifex_ai.core.device_reasoning.device_reasoning_engine;

import '../device_intelligence/device_semantic_graph.dart';
import 'reasoning_types.dart';

class DeviceReasoningEngine {
  DeviceReasoningEngine({DeviceSemanticGraph? graph})
      : graph = graph ?? DeviceSemanticGraph();

  final DeviceSemanticGraph graph;
  final observations = <Observation>[];
  final facts = <Fact>[];
  final hypotheses = <Hypothesis>[];
  final conflicts = <ReasoningConflict>[];
  final audit = <DeviceDecision>[];
  ReasoningMode mode = ReasoningMode.recommendation;

  void addObservation(Observation o) => observations.add(o);

  void addFact(Fact f) => facts.add(f);

  Hypothesis createHypothesis(Hypothesis h) {
    final copy = Hypothesis(
      id: h.id,
      statement: h.statement,
      evidenceIds: h.evidenceIds,
      confidence: h.confidence,
      verified: false,
    );
    hypotheses.add(copy);
    return copy;
  }

  Fact? fact(String subject, String predicate) {
    for (final f in facts.reversed) {
      if (f.subjectId == subject && f.predicate == predicate) {
        if (f.expiresAt != null && DateTime.now().isAfter(f.expiresAt!)) {
          continue;
        }
        return f;
      }
    }
    return null;
  }

  Observation? latestObservation(String subject, String property) {
    for (final o in observations.reversed) {
      if (o.subjectId == subject && o.property == property) return o;
    }
    return null;
  }

  List<DecisionOption> generateOptions(ReasoningContext ctx) {
    final disconnected =
        latestObservation(ctx.subjectId, 'connectionState')?.value ==
            'disconnected';
    final readEcg = graph.servicesProviding('ECG').isNotEmpty || ctx.readVerified;

    return [
      DecisionOption(
        id: 'reconnect',
        label: 'Reconnect existing device',
        feasibility: disconnected && ctx.supportsReconnect && ctx.authorized
            ? OptionFeasibility.feasible
            : (disconnected ? OptionFeasibility.unauthorized : OptionFeasibility.blocked),
      ),
      DecisionOption(
        id: 'alternative',
        label: 'Search another authorized ECG source',
        feasibility: readEcg ? OptionFeasibility.unknown : OptionFeasibility.unsupported,
        missing: const ['other_source_authorization'],
      ),
      DecisionOption(
        id: 'continue_without',
        label: 'Continue without ECG',
        feasibility: OptionFeasibility.feasible,
      ),
      DecisionOption(
        id: 'ask_user',
        label: 'Ask user for intervention',
        feasibility: OptionFeasibility.feasible,
      ),
      DecisionOption(
        id: 'control',
        label: 'Control device',
        feasibility: ctx.controlVerified
            ? OptionFeasibility.feasible
            : OptionFeasibility.unauthorized,
        controlClaimed: ctx.controlVerified,
      ),
    ];
  }

  List<ReasoningConflict> detectConflicts(ReasoningContext ctx) {
    final found = <ReasoningConflict>[];
    if (ctx.resourceClaimants.length > 1) {
      found.add(
        ReasoningConflict(
          id: 'c_res',
          type: ConflictType.resource,
          description:
              'Shared exclusive resource claimed by ${ctx.resourceClaimants.join(",")}',
        ),
      );
    }
    conflicts.addAll(found);
    return found;
  }

  DeviceDecision evaluate(ReasoningContext ctx) {
    if (mode == ReasoningMode.observeOnly ||
        ctx.mode == ReasoningMode.observeOnly) {
      return _store(
        DeviceDecision(
          id: 'd_obs',
          objective: ctx.objective,
          status: DecisionStatus.proposed,
          explanation: const DecisionExplanation(
            reasons: ['observe_only'],
          ),
        ),
      );
    }

    final conn = latestObservation(ctx.subjectId, 'connectionState');
    if (conn == null &&
        fact(ctx.subjectId, 'HAS_CAPABILITY') == null &&
        !ctx.readVerified &&
        !ctx.controlVerified) {
      return _store(
        DeviceDecision(
          id: 'd_miss',
          objective: ctx.objective,
          status: DecisionStatus.requiresInformation,
          explanation: const DecisionExplanation(
            uncertain: [
              'device_authorization_state',
              'protocol_version',
            ],
            reasons: ['missing_information_not_allow_or_deny'],
          ),
        ),
      );
    }

    if (!ctx.controlVerified &&
        ctx.objective.toLowerCase().contains('control')) {
      return _store(
        DeviceDecision(
          id: 'd_ctrl',
          objective: ctx.objective,
          status: DecisionStatus.blocked,
          constraintIds: const ['control_not_verified'],
          explanation: const DecisionExplanation(
            reasons: [
              'CONTROL not verified',
              'CONTROL BLOCKED',
            ],
            evidenceChain: ['Decision', 'Constraint', 'Fact', 'Observation'],
          ),
        ),
      );
    }

    final clashes = detectConflicts(ctx);
    if (clashes.isNotEmpty) {
      return _store(
        DeviceDecision(
          id: 'd_conf',
          objective: ctx.objective,
          status: DecisionStatus.blocked,
          explanation: DecisionExplanation(
            reasons: clashes.map((c) => c.description).toList(),
          ),
        ),
      );
    }

    final options = generateOptions(ctx);
    DecisionOption? selected;
    if (ctx.policyPrefer.isNotEmpty) {
      for (final o in options) {
        if (o.id == ctx.policyPrefer) selected = o;
      }
    }
    selected ??= options.where(
          (o) =>
              o.feasibility == OptionFeasibility.feasible && o.id != 'control',
        ).firstOrNull ??
        options.first;

    if (selected!.feasibility == OptionFeasibility.unauthorized ||
        selected.feasibility == OptionFeasibility.unsafe) {
      return _store(
        DeviceDecision(
          id: 'd_unauth',
          objective: ctx.objective,
          status: DecisionStatus.blocked,
          selectedOption: selected,
        ),
      );
    }

    if (ctx.mode == ReasoningMode.confirmationRequired ||
        selected.feasibility == OptionFeasibility.requiresConfirmation) {
      return _store(
        DeviceDecision(
          id: 'd_confm',
          objective: ctx.objective,
          status: DecisionStatus.requiresConfirmation,
          selectedOption: selected,
        ),
      );
    }

    if (ctx.mode == ReasoningMode.simulation) {
      return _store(
        DeviceDecision(
          id: 'd_sim',
          objective: ctx.objective,
          status: DecisionStatus.proposed,
          selectedOption: selected,
          explanation: const DecisionExplanation(reasons: ['simulation_only']),
        ),
      );
    }

    final ready = ctx.mode == ReasoningMode.executionReady &&
        selected.feasibility == OptionFeasibility.feasible &&
        ctx.authorized;

    return _store(
      DeviceDecision(
        id: 'd_${DateTime.now().microsecondsSinceEpoch}',
        objective: ctx.objective,
        status: ready
            ? DecisionStatus.readyForExecution
            : DecisionStatus.proposed,
        selectedOption: selected,
        evidenceIds: observations.map((o) => o.id).toList(),
        clinicalInterpretation: false,
        executedByReasoning: false,
        explanation: DecisionExplanation(
          reasons: [
            'option=${selected.id}',
            'does_not_execute',
            'not_medical_diagnosis',
          ],
          evidenceChain: [
            'Decision',
            'Rule',
            'Fact',
            'Observation',
            conn?.sourceId ?? 'none',
          ],
        ),
      ),
    );
  }

  ReasoningPlan createPlan(DeviceDecision decision) {
    if (decision.status != DecisionStatus.readyForExecution) {
      return ReasoningPlan(decisionId: decision.id);
    }
    return ReasoningPlan(
      decisionId: decision.id,
      steps: const [
        PlanStep(order: 1, action: 'verify_identity'),
        PlanStep(order: 2, action: 'verify_authorization', dependsOn: [1]),
        PlanStep(order: 3, action: 'establish_connection', dependsOn: [2]),
        PlanStep(order: 4, action: 'authenticate', dependsOn: [3]),
        PlanStep(order: 5, action: 'discover_service', dependsOn: [4]),
        PlanStep(order: 6, action: 'verify_capability', dependsOn: [5]),
        PlanStep(order: 7, action: 'read_state', dependsOn: [6]),
        PlanStep(order: 8, action: 'start_stream_if_authorized', dependsOn: [7]),
        PlanStep(order: 9, action: 'verify_stream', dependsOn: [8]),
        PlanStep(order: 10, action: 'report_result', dependsOn: [9]),
      ],
    );
  }

  RiskAssessment assessRisk(DeviceDecision decision) {
    if (latestObservation('', 'connectionState') == null &&
        decision.objective.contains('command')) {
      return const RiskAssessment(
        level: RiskLevel.high,
        factor: 'command_while_state_unknown',
        mitigation: 'refresh_state_before_execution',
        unknownMeansSafe: false,
      );
    }
    if (decision.status == DecisionStatus.requiresInformation) {
      return const RiskAssessment(
        level: RiskLevel.unknown,
        unknownMeansSafe: false,
        mitigation: 'collect_missing_information',
      );
    }
    return const RiskAssessment(level: RiskLevel.low, unknownMeansSafe: false);
  }

  WhatIfResult simulate(WhatIfScenario scenario) {
    final projected = <String>[];
    if (scenario.changes['connectionState'] == 'disconnected') {
      projected.addAll(const [
        'stream_lost',
        'display_loses_source',
        'search_alternative_source',
      ]);
    }
    return WhatIfResult(
      scenarioId: scenario.id,
      projected: projected,
      executed: false,
    );
  }

  DeviceDecision safetyGate(DeviceDecision decision) {
    if (decision.clinicalInterpretation) {
      return DeviceDecision(
        id: decision.id,
        objective: decision.objective,
        status: DecisionStatus.blocked,
        explanation: const DecisionExplanation(
          reasons: ['device_reasoning_is_not_diagnosis'],
        ),
      );
    }
    return decision;
  }

  DeviceDecision _store(DeviceDecision d) {
    audit.add(d);
    return d;
  }
}
