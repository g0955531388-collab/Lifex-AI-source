/// =============================================================
/// Lifex-AI — وحدة المستشفيات
/// الملف: hospital_booking_engine.dart
/// المسار: lib/features/hospital/hospital_booking_engine.dart
/// الوصف: حجز الموارد الداخلية للمستشفى (غرف عمليات، أجهزة تصوير،
/// مواعيد تحاليل) — منفصل عن حجز مواعيد الأطباء العادية.
/// =============================================================
library;

enum HospitalResourceType { operatingRoom, imagingMachine, labSlot }

class ResourceBookingRequest {
  final String bookingId;
  final String patientProfileId;
  final HospitalResourceType resourceType;
  final String resourceId;
  final DateTime scheduledAt;
  bool confirmed;

  ResourceBookingRequest({
    required this.bookingId,
    required this.patientProfileId,
    required this.resourceType,
    required this.resourceId,
    required this.scheduledAt,
    this.confirmed = false,
  });
}

/// محرك حجز الموارد الداخلية للمستشفى.
class HospitalBookingEngine {
  HospitalBookingEngine();

  final List<ResourceBookingRequest> _bookings = [];
  int _counter = 0;

  /// التحقق من عدم تعارض حجز جديد مع حجز قائم لنفس المورد في نفس الوقت
  /// تقريباً (نافذة ساعة واحدة كحد أدنى للفصل بين الحجوزات).
  bool _hasConflict(String resourceId, DateTime time) {
    return _bookings.any((b) =>
        b.resourceId == resourceId &&
        b.confirmed &&
        b.scheduledAt.difference(time).abs() < const Duration(hours: 1));
  }

  ResourceBookingRequest? requestBooking({
    required String patientProfileId,
    required HospitalResourceType resourceType,
    required String resourceId,
    required DateTime scheduledAt,
  }) {
    if (_hasConflict(resourceId, scheduledAt)) return null;

    _counter++;
    final request = ResourceBookingRequest(
      bookingId: 'BKG-$_counter',
      patientProfileId: patientProfileId,
      resourceType: resourceType,
      resourceId: resourceId,
      scheduledAt: scheduledAt,
    );
    _bookings.add(request);
    return request;
  }

  bool confirmBooking(String bookingId) {
    final matches = _bookings.where((b) => b.bookingId == bookingId).toList();
    if (matches.isEmpty) return false;
    matches.first.confirmed = true;
    return true;
  }

  List<ResourceBookingRequest> bookingsForPatient(String patientProfileId) {
    return _bookings.where((b) => b.patientProfileId == patientProfileId).toList();
  }
}
