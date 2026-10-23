/// =============================================================
/// Lifex-AI — وحدة التأهيل والتدريب
/// الملف: ai_simulation_lab.dart
/// المسار: lib/features/education/ai_simulation_lab.dart
/// الوصف: سيناريوهات محاكاة تدريبية (مثل حالة طوارئ افتراضية لتدريب
/// مسعف) يتخذ فيها المتدرب قرارات متسلسلة وتُقيَّم استجاباته.
///
/// ⚠️ هذه محاكاة تدريبية تعليمية بحتة على بيانات وهمية بالكامل، ولا
/// تتضمن أي بيانات مريض حقيقية ولا تُستخدم لاتخاذ قرار طبي فعلي.
/// =============================================================
library;

class SimulationStep {
  final String stepId;
  final String scenarioTextAr;
  final List<String> choiceOptionsAr;
  final int correctChoiceIndex;

  const SimulationStep({
    required this.stepId,
    required this.scenarioTextAr,
    required this.choiceOptionsAr,
    required this.correctChoiceIndex,
  });
}

class SimulationScenario {
  final String scenarioId;
  final String titleAr;
  final List<SimulationStep> steps;

  const SimulationScenario({
    required this.scenarioId,
    required this.titleAr,
    required this.steps,
  });
}

class SimulationAttemptResult {
  final String scenarioId;
  final int correctChoicesCount;
  final int totalSteps;
  final double scoreRatio;

  const SimulationAttemptResult({
    required this.scenarioId,
    required this.correctChoicesCount,
    required this.totalSteps,
    required this.scoreRatio,
  });
}

/// مختبر المحاكاة الذكي.
class AiSimulationLab {
  AiSimulationLab();

  final Map<String, SimulationScenario> _scenarios = {};

  void registerScenario(SimulationScenario scenario) {
    _scenarios[scenario.scenarioId] = scenario;
  }

  SimulationScenario? getScenario(String scenarioId) => _scenarios[scenarioId];

  /// تقييم إجابات المتدرب على كل خطوات السيناريو دفعة واحدة.
  SimulationAttemptResult evaluateAttempt({
    required String scenarioId,
    required List<int> chosenIndices,
  }) {
    final scenario = _scenarios[scenarioId];
    if (scenario == null) {
      return const SimulationAttemptResult(
        scenarioId: '',
        correctChoicesCount: 0,
        totalSteps: 0,
        scoreRatio: 0.0,
      );
    }

    int correctCount = 0;
    for (int i = 0; i < scenario.steps.length && i < chosenIndices.length; i++) {
      if (chosenIndices[i] == scenario.steps[i].correctChoiceIndex) {
        correctCount++;
      }
    }

    return SimulationAttemptResult(
      scenarioId: scenarioId,
      correctChoicesCount: correctCount,
      totalSteps: scenario.steps.length,
      scoreRatio: scenario.steps.isEmpty ? 0.0 : correctCount / scenario.steps.length,
    );
  }
}
