/// =============================================================
/// Lifex-AI — التصوير الطبي والأشعة
/// الملف: imaging_appointment_manager.dart
/// المسار: lib/features/medical_imaging/imaging_appointment_manager.dart
/// الوصف: حجز مواعيد الفحوصات التصويرية (أشعة، رنين، سونار...).
/// =============================================================
library;

import 'imaging_center_profile.dart';

class ImagingAppointment {
  final String appointmentId;
  final String patientProfileId;
  final String centerId;
  final ImagingModality modality;
  final DateTime scheduledAt;
  bool reportReady;

  ImagingAppointment({
    required this.appointmentId,
    required this.patientProfileId,
    required this.centerId,
    required this.modality,
    required this.scheduledAt,
    this.reportReady = false,
  });
}

class ImagingAppointmentManager {
  ImagingAppointmentManager();

  final Map<String, ImagingAppointment> _appointments = {};
  int _counter = 0;

  ImagingAppointment bookAppointment({
    required String patientProfileId,
    required String centerId,
    required ImagingModality modality,
    required DateTime scheduledAt,
  }) {
    _counter++;
    final appointment = ImagingAppointment(
      appointmentId: 'IMG-$_counter',
      patientProfileId: patientProfileId,
      centerId: centerId,
      modality: modality,
      scheduledAt: scheduledAt,
    );
    _appointments[appointment.appointmentId] = appointment;
    return appointment;
  }

  void markReportReady(String appointmentId) {
    _appointments[appointmentId]?.reportReady = true;
  }

  List<ImagingAppointment> appointmentsForCenter(String centerId) {
    return _appointments.values.where((a) => a.centerId == centerId).toList();
  }

  List<ImagingAppointment> appointmentsForPatient(String patientProfileId) {
    return _appointments.values
        .where((a) => a.patientProfileId == patientProfileId)
        .toList();
  }
}
