/// =============================================================
/// Lifex-AI — الأطباء والمستشفيات
/// الملف: doctor_dashboard.dart
/// المسار: lib/features/medical_services/doctors/doctor_dashboard.dart
/// الوصف: طبقة تجميع بيانات لوحة تحكم الطبيب — ملخص مواعيد اليوم
/// والمرضى المسؤول عنهم، دون تكرار منطق appointment_manager.dart.
/// =============================================================
library;

import 'appointment_manager.dart';

class DoctorDashboardSummary {
  final int todaysAppointmentsCount;
  final int pendingConfirmationsCount;
  final List<Appointment> todaysAppointments;

  const DoctorDashboardSummary({
    required this.todaysAppointmentsCount,
    required this.pendingConfirmationsCount,
    required this.todaysAppointments,
  });
}

/// مجمّع بيانات لوحة تحكم الطبيب.
class DoctorDashboard {
  DoctorDashboard({required this.appointmentManager});

  final AppointmentManager appointmentManager;

  DoctorDashboardSummary buildSummary(String doctorId) {
    final all = appointmentManager.appointmentsForProvider(doctorId);
    final now = DateTime.now();

    final todays = all.where((a) {
      return a.scheduledAt.year == now.year &&
          a.scheduledAt.month == now.month &&
          a.scheduledAt.day == now.day &&
          a.status != AppointmentStatus.cancelled;
    }).toList();

    final pending =
        all.where((a) => a.status == AppointmentStatus.requested).length;

    return DoctorDashboardSummary(
      todaysAppointmentsCount: todays.length,
      pendingConfirmationsCount: pending,
      todaysAppointments: todays,
    );
  }
}
