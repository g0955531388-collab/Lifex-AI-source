/// =============================================================
/// Lifex-AI — الأطباء والمستشفيات
/// الملف: appointment_manager.dart
/// المسار: lib/features/medical_services/doctors/appointment_manager.dart
/// الوصف: إدارة دورة حياة المواعيد الطبية — حجز، تأكيد، إلغاء، إعادة
/// جدولة، بغض النظر عن كون الطرف طبيباً مستقلاً أو قسماً داخل مستشفى.
/// =============================================================
library;

import '../../../core/health_event_manager.dart';

enum AppointmentStatus { requested, confirmed, cancelled, completed, noShow }

class Appointment {
  final String appointmentId;
  final String patientProfileId;
  final String providerId; // doctorId أو hospitalDepartmentId
  final DateTime scheduledAt;
  AppointmentStatus status;
  final String? reasonAr;

  Appointment({
    required this.appointmentId,
    required this.patientProfileId,
    required this.providerId,
    required this.scheduledAt,
    this.status = AppointmentStatus.requested,
    this.reasonAr,
  });
}

/// مدير المواعيد.
class AppointmentManager {
  AppointmentManager();

  final Map<String, Appointment> _appointments = {};
  int _counter = 0;

  Appointment requestAppointment({
    required String patientProfileId,
    required String providerId,
    required DateTime scheduledAt,
    String? reasonAr,
  }) {
    _counter++;
    final appointment = Appointment(
      appointmentId: 'APT-$_counter',
      patientProfileId: patientProfileId,
      providerId: providerId,
      scheduledAt: scheduledAt,
      reasonAr: reasonAr,
    );
    _appointments[appointment.appointmentId] = appointment;

    HealthEventManager.instance.emitQuick(
      HealthEventType.appointmentScheduled,
      sourceModule: 'appointment_manager',
      profileId: patientProfileId,
      data: {'appointmentId': appointment.appointmentId},
    );

    return appointment;
  }

  bool confirm(String appointmentId) {
    final appointment = _appointments[appointmentId];
    if (appointment == null) return false;
    appointment.status = AppointmentStatus.confirmed;
    return true;
  }

  bool cancel(String appointmentId) {
    final appointment = _appointments[appointmentId];
    if (appointment == null) return false;
    appointment.status = AppointmentStatus.cancelled;

    HealthEventManager.instance.emitQuick(
      HealthEventType.appointmentCancelled,
      sourceModule: 'appointment_manager',
      profileId: appointment.patientProfileId,
      data: {'appointmentId': appointmentId},
    );
    return true;
  }

  bool markCompleted(String appointmentId) {
    final appointment = _appointments[appointmentId];
    if (appointment == null) return false;
    appointment.status = AppointmentStatus.completed;
    return true;
  }

  List<Appointment> appointmentsForPatient(String patientProfileId) {
    return _appointments.values
        .where((a) => a.patientProfileId == patientProfileId)
        .toList();
  }

  List<Appointment> appointmentsForProvider(String providerId) {
    return _appointments.values
        .where((a) => a.providerId == providerId)
        .toList();
  }
}
