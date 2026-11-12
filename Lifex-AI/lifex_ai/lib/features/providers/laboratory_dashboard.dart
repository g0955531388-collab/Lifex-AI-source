/// =============================================================
/// Lifex-AI — الصيدليات والمخابر
/// الملف: laboratory_dashboard.dart
/// المسار: lib/features/providers/laboratory_dashboard.dart
/// الوصف: مجمّع بيانات لوحة تحكم المخبر — طلبات التحاليل المعلّقة
/// والنتائج الجاهزة للتسليم.
/// =============================================================
library;

import 'lab_test_request_manager.dart';

class LaboratoryDashboardSummary {
  final int pendingRequestsCount;
  final int readyResultsCount;

  const LaboratoryDashboardSummary({
    required this.pendingRequestsCount,
    required this.readyResultsCount,
  });
}

class LaboratoryDashboard {
  LaboratoryDashboard({required this.requestManager});

  final LabTestRequestManager requestManager;

  LaboratoryDashboardSummary buildSummary(String laboratoryId) {
    final pending = requestManager.pendingRequestsFor(laboratoryId).length;
    final ready = requestManager.readyResultsFor(laboratoryId).length;

    return LaboratoryDashboardSummary(
      pendingRequestsCount: pending,
      readyResultsCount: ready,
    );
  }
}
