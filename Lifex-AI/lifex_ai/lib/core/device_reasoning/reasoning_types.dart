/// =============================================================
/// Lifex-AI — استدلال أجهزة
/// الملف: reasoning_types.dart
/// ملاحظة ≠ حقيقة ≠ فرضية ≠ قرار. الاستدلال ≠ تشخيص.
/// =============================================================
library lifex_ai.core.device_reasoning.reasoning_types;

enum DecisionStatus {
  proposed,
  requiresInformation,
  requiresConfirmation,
  authorized,
  blocked,
  rejected,
  readyForExecution,
  executed,
  failed,
}

enum OptionFeasibility {
  feasible,
  blocked,
  unknown,
  requiresConfirmation,
  unauthorized,
  unsupported,
  unsafe,
}

enum ConflictType {
  capability,
  permission,
  resource,
  command,
  state,
  timing,
  automation,
  safety,
  data,
  protocol,
}

enum RiskLevel {
  negligible,
  low,
  moderate,
  high,
  critical,
  unknown,
}

enum ReasoningMode {
  observeOnly,
  analysisOnly,
  recommendation,
  confirmationRequired,
  executionReady,
  simulation,
  emergencyPolicy,
}

class Observation {
  const Observation({
    required this.id,
    required this.sourceId,
    required this.timestamp,
    required this.subjectId,
    required this.property,
    required this.value,
    this.confidence = 0,
  });

  final String id;
  final String sourceId;
  final DateTime timestamp;
  final String subjectId;
  final String property;
  final Object? value;
  final double confidence;
}

class Fact {
  const Fact({
    required this.id,
    required this.subjectId,
    required this.predicate,
    required this.value,
    required this.observedAt,
    required this.sourceId,
    this.expiresAt,
  });

  final String id;
  final String subjectId;
  final String predicate;
  final Object? value;
  final DateTime observedAt;
  final DateTime? expiresAt;
  final String sourceId;
}

class Hypothesis {
  const Hypothesis({
    required this.id,
    required this.statement,
    this.evidenceIds = const [],
    this.confidence = 0,
    this.verified = false,
  });

  final String id;
  final String statement;
  final List<String> evidenceIds;
  final double confidence;
  final bool verified;
}

class DecisionOption {
  const DecisionOption({
    required this.id,
    required this.label,
    this.feasibility = OptionFeasibility.unknown,
    this.missing = const [],
    this.controlClaimed = false,
  });

  final String id;
  final String label;
  final OptionFeasibility feasibility;
  final List<String> missing;
  final bool controlClaimed;
}

class DecisionExplanation {
  const DecisionExplanation({
    this.reasons = const [],
    this.uncertain = const [],
    this.evidenceChain = const [],
  });

  final List<String> reasons;
  final List<String> uncertain;
  final List<String> evidenceChain;
}

class DeviceDecision {
  const DeviceDecision({
    required this.id,
    required this.objective,
    required this.status,
    this.selectedOption,
    this.evidenceIds = const [],
    this.constraintIds = const [],
    this.confidence = 0,
    this.explanation = const DecisionExplanation(),
    this.clinicalInterpretation = false,
    this.executedByReasoning = false,
  });

  final String id;
  final String objective;
  final DecisionStatus status;
  final DecisionOption? selectedOption;
  final List<String> evidenceIds;
  final List<String> constraintIds;
  final double confidence;
  final DecisionExplanation explanation;
  final bool clinicalInterpretation;
  final bool executedByReasoning;
}

class ReasoningConflict {
  const ReasoningConflict({
    required this.id,
    required this.type,
    required this.description,
  });

  final String id;
  final ConflictType type;
  final String description;
}

class PlanStep {
  const PlanStep({
    required this.order,
    required this.action,
    this.dependsOn = const [],
  });

  final int order;
  final String action;
  final List<int> dependsOn;
}

class ReasoningPlan {
  const ReasoningPlan({
    required this.decisionId,
    this.steps = const [],
  });

  final String decisionId;
  final List<PlanStep> steps;
}

class RiskAssessment {
  const RiskAssessment({
    required this.level,
    this.factor = '',
    this.mitigation = '',
    this.unknownMeansSafe = false,
  });

  final RiskLevel level;
  final String factor;
  final String mitigation;
  final bool unknownMeansSafe;
}

class WhatIfScenario {
  const WhatIfScenario({
    required this.id,
    this.changes = const {},
  });

  final String id;
  final Map<String, Object?> changes;
}

class WhatIfResult {
  const WhatIfResult({
    required this.scenarioId,
    this.projected = const [],
    this.executed = false,
  });

  final String scenarioId;
  final List<String> projected;
  final bool executed;
}

class ReasoningContext {
  const ReasoningContext({
    required this.objective,
    this.subjectId = '',
    this.mode = ReasoningMode.recommendation,
    this.controlVerified = false,
    this.readVerified = false,
    this.authorized = false,
    this.supportsReconnect = false,
    this.resourceClaimants = const [],
    this.policyPrefer = '',
  });

  final String objective;
  final String subjectId;
  final ReasoningMode mode;
  final bool controlVerified;
  final bool readVerified;
  final bool authorized;
  final bool supportsReconnect;
  final List<String> resourceClaimants;
  final String policyPrefer;
}
