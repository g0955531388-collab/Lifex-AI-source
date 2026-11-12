/// =============================================================
/// Lifex-AI — وحدة المستشفيات
/// الملف: hospital_emergency_ems.dart
/// المسار: lib/features/hospital/hospital_emergency_ems.dart
/// الوصف: إدارة حالات الطوارئ الواردة للمستشفى، مع تصنيف أولوية سريع
/// (Triage مبسّط) لتحديد من يُستقبل أولاً.
///
/// ⚠️ هذا تصنيف أولوية إداري مبسّط فقط لمساعدة التنظيم الداخلي، وليس
/// بديلاً عن تقييم Triage السريري الفعلي الذي يقوم به الطاقم الطبي
/// المؤهل عند وصول الحالة فعلياً.
/// =============================================================
library;

enum TriagePriority { immediate, urgent, delayed, minor }

class EmsCase {
  final String emsCaseId;
  final String hospitalId;
  final String? patientProfileId;
  final TriagePriority priority;
  final DateTime arrivedAt;
  bool resolved;

  EmsCase({
    required this.emsCaseId,
    required this.hospitalId,
    this.patientProfileId,
    required this.priority,
    DateTime? arrivedAt,
    this.resolved = false,
  }) : arrivedAt = arrivedAt ?? DateTime.now();
}

/// مدير وحدة الطوارئ داخل المستشفى.
class HospitalEmergencyEms {
  HospitalEmergencyEms();

  final Map<String, EmsCase> _cases = {};
  int _counter = 0;

  EmsCase registerIncomingCase({
    required String hospitalId,
    String? patientProfileId,
    required TriagePriority priority,
  }) {
    _counter++;
    final emsCase = EmsCase(
      emsCaseId: 'EMS-$_counter',
      hospitalId: hospitalId,
      patientProfileId: patientProfileId,
      priority: priority,
    );
    _cases[emsCase.emsCaseId] = emsCase;
    return emsCase;
  }

  bool resolveCase(String emsCaseId) {
    final emsCase = _cases[emsCaseId];
    if (emsCase == null) return false;
    emsCase.resolved = true;
    return true;
  }

  int activeCasesCount(String hospitalId) {
    return _cases.values
        .where((c) => c.hospitalId == hospitalId && !c.resolved)
        .length;
  }

  /// قائمة الحالات النشطة مرتّبة حسب الأولوية (الأكثر إلحاحاً أولاً).
  List<EmsCase> activeQueueSortedByPriority(String hospitalId) {
    final active = _cases.values
        .where((c) => c.hospitalId == hospitalId && !c.resolved)
        .toList();

    active.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return active;
  }
}
