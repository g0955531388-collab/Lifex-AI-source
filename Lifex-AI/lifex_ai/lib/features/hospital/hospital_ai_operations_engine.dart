/// =============================================================
/// Lifex-AI — وحدة المستشفيات
/// الملف: hospital_ai_operations_engine.dart
/// المسار: lib/features/hospital/hospital_ai_operations_engine.dart
/// الوصف: تحليل بسيط وشفاف (قائم على قواعد) للتنبؤ بضغط الطوارئ بناءً
/// على عدد الحالات النشطة ومعدل الوصول الأخير، لمساعدة الإدارة على
/// توزيع الموارد. هذا ليس نموذج تعلّم آلي معقّد، بل مؤشر تشغيلي مبسّط.
/// =============================================================
library;

import 'hospital_emergency_ems.dart';

enum OperationalPressureLevel { normal, elevated, high, critical }

class OperationalPressureAssessment {
  final OperationalPressureLevel level;
  final String recommendationAr;

  const OperationalPressureAssessment({
    required this.level,
    required this.recommendationAr,
  });
}

/// محرك تقييم ضغط العمليات في المستشفى.
class HospitalAiOperationsEngine {
  HospitalAiOperationsEngine({required this.emergencyEms});

  final HospitalEmergencyEms emergencyEms;

  /// عتبات بسيطة وقابلة للتعديل بسهولة من قِبل الإدارة، وليست "صندوقاً
  /// أسود" يصعب فهمه أو مراجعته.
  static const int elevatedThreshold = 5;
  static const int highThreshold = 10;
  static const int criticalThreshold = 20;

  OperationalPressureAssessment assessPressure(String hospitalId) {
    final activeCount = emergencyEms.activeCasesCount(hospitalId);

    if (activeCount >= criticalThreshold) {
      return const OperationalPressureAssessment(
        level: OperationalPressureLevel.critical,
        recommendationAr:
            'ضغط حرج على الطوارئ. يُنصح بتفعيل بروتوكول الطوارئ الكبرى '
            'واستدعاء طاقم إضافي فوراً.',
      );
    }
    if (activeCount >= highThreshold) {
      return const OperationalPressureAssessment(
        level: OperationalPressureLevel.high,
        recommendationAr: 'ضغط مرتفع. يُنصح بتوجيه طاقم إضافي لقسم الطوارئ.',
      );
    }
    if (activeCount >= elevatedThreshold) {
      return const OperationalPressureAssessment(
        level: OperationalPressureLevel.elevated,
        recommendationAr: 'ضغط متزايد. متابعة الوضع عن كثب.',
      );
    }
    return const OperationalPressureAssessment(
      level: OperationalPressureLevel.normal,
      recommendationAr: 'الوضع التشغيلي طبيعي حالياً.',
    );
  }
}
