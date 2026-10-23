/// =============================================================
/// Lifex-AI — الأطباء والمستشفيات
/// الملف: doctor_schedule_manager.dart
/// المسار: lib/features/medical_services/doctors/doctor_schedule_manager.dart
/// الوصف: إدارة جدول توافر الطبيب (الأوقات المتاحة للحجز) بمعزل عن
/// المواعيد المؤكدة فعلياً — يمنع تعارض الحجوزات.
/// =============================================================
library;

class AvailabilitySlot {
  final DateTime start;
  final DateTime end;
  bool isBooked;

  AvailabilitySlot({
    required this.start,
    required this.end,
    this.isBooked = false,
  });

  bool overlaps(DateTime time) => time.isAfter(start) && time.isBefore(end);
}

/// مدير جدول مناوبات طبيب واحد.
class DoctorScheduleManager {
  DoctorScheduleManager({required this.doctorId});

  final String doctorId;
  final List<AvailabilitySlot> _slots = [];

  void addAvailability(DateTime start, DateTime end) {
    _slots.add(AvailabilitySlot(start: start, end: end));
  }

  List<AvailabilitySlot> get availableSlots =>
      _slots.where((s) => !s.isBooked).toList();

  /// محاولة حجز وقت معيّن — تفشل إن لم يقع الوقت ضمن أي فترة متاحة أو
  /// إن كانت الفترة محجوزة بالفعل.
  bool bookSlotAt(DateTime time) {
    for (final slot in _slots) {
      if (!slot.isBooked && slot.overlaps(time)) {
        slot.isBooked = true;
        return true;
      }
    }
    return false;
  }

  void releaseSlotAt(DateTime time) {
    for (final slot in _slots) {
      if (slot.isBooked && slot.overlaps(time)) {
        slot.isBooked = false;
      }
    }
  }
}
