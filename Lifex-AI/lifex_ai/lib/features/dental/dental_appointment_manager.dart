/// =============================================================
/// Lifex-AI — وحدة الأسنان
/// الملف: dental_appointment_manager.dart
/// المسار: lib/features/dental/dental_appointment_manager.dart
/// الوصف: حجز مواعيد الأسنان — طبقة رقيقة فوق منطق مشابه لمواعيد
/// الأطباء العاديين، مخصّصة لسياق الأسنان (مدة جلسة أطول عادة).
/// =============================================================
library;

enum DentalAppointmentStatus { requested, confirmed, cancelled, completed }

class DentalAppointment {
  final String appointmentId;
  final String patientProfileId;
  final String dentalProviderId;
  final DateTime scheduledAt;
  final Duration estimatedDuration;
  DentalAppointmentStatus status;

  DentalAppointment({
    required this.appointmentId,
    required this.patientProfileId,
    required this.dentalProviderId,
    required this.scheduledAt,
    this.estimatedDuration = const Duration(minutes: 45),
    this.status = DentalAppointmentStatus.requested,
  });
}

class DentalAppointmentManager {
  DentalAppointmentManager();

  final Map<String, DentalAppointment> _appointments = {};
  int _counter = 0;

  DentalAppointment requestAppointment({
    required String patientProfileId,
    required String dentalProviderId,
    required DateTime scheduledAt,
    Duration estimatedDuration = const Duration(minutes: 45),
  }) {
    _counter++;
    final appointment = DentalAppointment(
      appointmentId: 'DAP-$_counter',
      patientProfileId: patientProfileId,
      dentalProviderId: dentalProviderId,
      scheduledAt: scheduledAt,
      estimatedDuration: estimatedDuration,
    );
    _appointments[appointment.appointmentId] = appointment;
    return appointment;
  }

  bool confirm(String appointmentId) {
    final appointment = _appointments[appointmentId];
    if (appointment == null) return false;
    appointment.status = DentalAppointmentStatus.confirmed;
    return true;
  }

  bool cancel(String appointmentId) {
    final appointment = _appointments[appointmentId];
    if (appointment == null) return false;
    appointment.status = DentalAppointmentStatus.cancelled;
    return true;
  }

  List<DentalAppointment> appointmentsForPatient(String patientProfileId) {
    return _appointments.values
        .where((a) => a.patientProfileId == patientProfileId)
        .toList();
  }
}
