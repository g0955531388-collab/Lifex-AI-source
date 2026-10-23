/// =============================================================
/// Lifex-AI — التصوير الطبي والأشعة
/// الملف: imaging_center_dashboard.dart
/// المسار: lib/features/medical_imaging/imaging_center_dashboard.dart
/// الوصف: مجمّع بيانات لوحة تحكم مركز التصوير — الفحوصات المجدولة اليوم
/// والتقارير المعلّقة على أطباء الأشعة.
/// =============================================================
library;

import 'imaging_appointment_manager.dart';

class ImagingCenterDashboardSummary {
  final int todaysScansCount;
  final int pendingReportsCount;

  const ImagingCenterDashboardSummary({
    required this.todaysScansCount,
    required this.pendingReportsCount,
  });
}

class ImagingCenterDashboard {
  ImagingCenterDashboard({required this.appointmentManager});

  final ImagingAppointmentManager appointmentManager;

  ImagingCenterDashboardSummary buildSummary(String centerId) {
    final all = appointmentManager.appointmentsForCenter(centerId);
    final now = DateTime.now();

    final todays = all.where((a) =>
        a.scheduledAt.year == now.year &&
        a.scheduledAt.month == now.month &&
        a.scheduledAt.day == now.day);

    final pendingReports = all.where((a) => a.reportReady == false).length;

    return ImagingCenterDashboardSummary(
      todaysScansCount: todays.length,
      pendingReportsCount: pendingReports,
    );
  }
}
