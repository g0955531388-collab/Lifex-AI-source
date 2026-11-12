/// =============================================================
/// Lifex-AI — وحدة الأسنان
/// الملف: dental_dashboard.dart
/// المسار: lib/features/dental/dental_dashboard.dart
/// الوصف: تتبّع خطط العلاج السنية طويلة المدى (مثل تقويم الأسنان)
/// المكوّنة من عدة جلسات، لعرضها في لوحة تحكم الطبيب.
/// =============================================================
library;

enum TreatmentPlanStatus { active, completed, paused }

class DentalTreatmentStep {
  final String descriptionAr;
  bool completed;
  DateTime? completedAt;

  DentalTreatmentStep({required this.descriptionAr, this.completed = false, this.completedAt});
}

class DentalTreatmentPlan {
  final String planId;
  final String patientProfileId;
  final String dentalProviderId;
  final List<DentalTreatmentStep> steps;
  TreatmentPlanStatus status;

  DentalTreatmentPlan({
    required this.planId,
    required this.patientProfileId,
    required this.dentalProviderId,
    List<DentalTreatmentStep>? steps,
    this.status = TreatmentPlanStatus.active,
  }) : steps = steps ?? [];

  double get completionRatio {
    if (steps.isEmpty) return 0.0;
    final completedCount = steps.where((s) => s.completed).length;
    return completedCount / steps.length;
  }
}

/// جلسة عيادة: نوع العمل، مدته، المواد، والسعر بالوحدة الصغرى.
class DentalSessionRecord {
  DentalSessionRecord({
    required this.sessionId,
    required this.patientProfileId,
    required this.dentalProviderId,
    required this.workTypeAr,
    required this.duration,
    required this.materialsConsumed,
    required this.priceMinorUnits,
    DateTime? recordedAt,
  }) : recordedAt = recordedAt ?? DateTime.now();

  final String sessionId;
  final String patientProfileId;
  final String dentalProviderId;
  final String workTypeAr;
  final Duration duration;
  final List<String> materialsConsumed;
  final int priceMinorUnits;
  final DateTime recordedAt;
}

/// لوحة تحكم طبيب الأسنان.
class DentalDashboard {
  DentalDashboard();

  final Map<String, DentalTreatmentPlan> _plans = {};
  final List<DentalSessionRecord> _sessions = [];
  int _counter = 0;
  int _sessionCounter = 0;

  DentalTreatmentPlan createPlan({
    required String patientProfileId,
    required String dentalProviderId,
    required List<String> stepDescriptionsAr,
  }) {
    _counter++;
    final plan = DentalTreatmentPlan(
      planId: 'DEN-$_counter',
      patientProfileId: patientProfileId,
      dentalProviderId: dentalProviderId,
      steps: stepDescriptionsAr
          .map((d) => DentalTreatmentStep(descriptionAr: d))
          .toList(),
    );
    _plans[plan.planId] = plan;
    return plan;
  }

  bool markStepCompleted(String planId, int stepIndex) {
    final plan = _plans[planId];
    if (plan == null || stepIndex >= plan.steps.length) return false;
    plan.steps[stepIndex].completed = true;
    plan.steps[stepIndex].completedAt = DateTime.now();

    if (plan.steps.every((s) => s.completed)) {
      plan.status = TreatmentPlanStatus.completed;
    }
    return true;
  }

  DentalSessionRecord? recordSession({
    required String patientProfileId,
    required String dentalProviderId,
    required String workTypeAr,
    required Duration duration,
    required List<String> materialsConsumed,
    required int priceMinorUnits,
  }) {
    if (workTypeAr.trim().isEmpty || priceMinorUnits < 0) return null;
    if (patientProfileId.trim().isEmpty || dentalProviderId.trim().isEmpty) {
      return null;
    }
    if (duration.inMinutes <= 0) return null;
    _sessionCounter++;
    final session = DentalSessionRecord(
      sessionId: 'DSES-$_sessionCounter',
      patientProfileId: patientProfileId,
      dentalProviderId: dentalProviderId,
      workTypeAr: workTypeAr.trim(),
      duration: duration,
      materialsConsumed: List.unmodifiable(materialsConsumed),
      priceMinorUnits: priceMinorUnits,
    );
    _sessions.add(session);
    return session;
  }

  List<DentalSessionRecord> sessionsForPatient(String patientProfileId) {
    return _sessions
        .where((s) => s.patientProfileId == patientProfileId)
        .toList(growable: false);
  }

  List<DentalSessionRecord> sessionsForProvider(String dentalProviderId) {
    return _sessions
        .where((s) => s.dentalProviderId == dentalProviderId)
        .toList(growable: false);
  }

  List<DentalTreatmentPlan> activePlansForProvider(String dentalProviderId) {
    return _plans.values
        .where((p) =>
            p.dentalProviderId == dentalProviderId &&
            p.status == TreatmentPlanStatus.active)
        .toList();
  }
}
