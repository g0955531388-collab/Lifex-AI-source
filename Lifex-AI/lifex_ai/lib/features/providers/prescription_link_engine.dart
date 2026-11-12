/// =============================================================
/// Lifex-AI — الصيدليات والمخابر
/// الملف: prescription_link_engine.dart
/// المسار: lib/features/providers/prescription_link_engine.dart
/// الوصف: ربط وصفة طبية صادرة عن طبيب بصيدلية يختارها المريض لصرفها،
/// مع تتبّع حالة الصرف.
///
/// ⚠️ لا يُصرف أي دواء يتطلب وصفة (requiresPrescription = true في
/// medications_database.json) دون وجود وصفة مرتبطة ومؤكدة هنا.
/// =============================================================
library;

enum PrescriptionFulfillmentStatus { pendingReview, approved, dispensed, rejected }

class PrescriptionRequest {
  final String requestId;
  final String patientProfileId;
  final String pharmacyId;
  final String prescribingDoctorId;
  final List<String> medicationIds;
  PrescriptionFulfillmentStatus status;
  final DateTime createdAt;

  PrescriptionRequest({
    required this.requestId,
    required this.patientProfileId,
    required this.pharmacyId,
    required this.prescribingDoctorId,
    required this.medicationIds,
    this.status = PrescriptionFulfillmentStatus.pendingReview,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// محرك ربط الوصفات بالصيدليات.
class PrescriptionLinkEngine {
  PrescriptionLinkEngine();

  final Map<String, PrescriptionRequest> _requests = {};
  int _counter = 0;

  PrescriptionRequest submitToPharmacy({
    required String patientProfileId,
    required String pharmacyId,
    required String prescribingDoctorId,
    required List<String> medicationIds,
  }) {
    _counter++;
    final request = PrescriptionRequest(
      requestId: 'RX-$_counter',
      patientProfileId: patientProfileId,
      pharmacyId: pharmacyId,
      prescribingDoctorId: prescribingDoctorId,
      medicationIds: medicationIds,
    );
    _requests[request.requestId] = request;
    return request;
  }

  bool approve(String requestId) {
    final request = _requests[requestId];
    if (request == null) return false;
    request.status = PrescriptionFulfillmentStatus.approved;
    return true;
  }

  bool markDispensed(String requestId) {
    final request = _requests[requestId];
    if (request == null ||
        request.status != PrescriptionFulfillmentStatus.approved) {
      return false;
    }
    request.status = PrescriptionFulfillmentStatus.dispensed;
    return true;
  }

  bool reject(String requestId) {
    final request = _requests[requestId];
    if (request == null) return false;
    request.status = PrescriptionFulfillmentStatus.rejected;
    return true;
  }

  List<PrescriptionRequest> pendingRequestsFor(String pharmacyId) {
    return _requests.values
        .where((r) =>
            r.pharmacyId == pharmacyId &&
            r.status == PrescriptionFulfillmentStatus.pendingReview)
        .toList();
  }
}
