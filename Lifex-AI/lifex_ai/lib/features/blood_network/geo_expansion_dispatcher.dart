/// =============================================================
/// Lifex-AI — شبكة التبرع بالدم
/// الملف: geo_expansion_dispatcher.dart
/// المسار: lib/features/blood_network/geo_expansion_dispatcher.dart
/// الوصف: عند عدم وجود متبرعين مؤهلين ضمن نطاق ضيق، يوسّع هذا الموزّع
/// نطاق البحث تدريجياً (دوائر متتالية أوسع) حتى يجد متبرعين أو يصل
/// لحد أقصى معقول.
/// =============================================================
library;

class ExpansionStep {
  final String requestId;
  final double radiusKm;
  final DateTime scheduledAt;

  const ExpansionStep({
    required this.requestId,
    required this.radiusKm,
    required this.scheduledAt,
  });
}

/// موزّع التوسيع الجغرافي التدريجي.
class GeoExpansionDispatcher {
  GeoExpansionDispatcher({
    this.expansionIncrementKm = 10.0,
    this.maxRadiusKm = 100.0,
  });

  final double expansionIncrementKm;
  final double maxRadiusKm;

  final List<ExpansionStep> _scheduledSteps = [];

  /// جدولة خطوة توسيع تالية بعد فشل النطاق الحالي في إيجاد متبرعين.
  ExpansionStep? scheduleExpansion(String requestId, double currentRadiusKm) {
    final nextRadius = currentRadiusKm + expansionIncrementKm;
    if (nextRadius > maxRadiusKm) return null;

    final step = ExpansionStep(
      requestId: requestId,
      radiusKm: nextRadius,
      scheduledAt: DateTime.now(),
    );
    _scheduledSteps.add(step);
    return step;
  }

  List<ExpansionStep> stepsForRequest(String requestId) {
    return _scheduledSteps.where((s) => s.requestId == requestId).toList();
  }
}
