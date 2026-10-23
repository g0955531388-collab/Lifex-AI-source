/// =============================================================
/// Lifex-AI — الصيدليات والمخابر
/// الملف: lab_test_request_manager.dart
/// المسار: lib/features/providers/lab_test_request_manager.dart
/// الوصف: إدارة طلبات التحاليل من المريض/الطبيب إلى المخبر، وتتبّع
/// حالة النتيجة حتى استلامها.
/// =============================================================
library;

import '../../core/health_event_manager.dart';

enum LabRequestStatus { pending, sampleCollected, processing, resultReady, delivered }

class LabTestRequest {
  final String requestId;
  final String patientProfileId;
  final String laboratoryId;
  final String? referringDoctorId;
  final List<String> testIds; // معرّفات من tests_database.json
  LabRequestStatus status;
  Map<String, dynamic>? resultData;

  LabTestRequest({
    required this.requestId,
    required this.patientProfileId,
    required this.laboratoryId,
    required this.testIds,
    this.referringDoctorId,
    this.status = LabRequestStatus.pending,
    this.resultData,
  });
}

/// نسخة واحدة للمريض ونسخة للطبيب المحيل. لا زيارة ثانية لنقل النتيجة.
class ReleasedClinicalCopy {
  const ReleasedClinicalCopy({
    required this.artifactId,
    required this.patientProfileId,
    this.referringDoctorId,
  });

  final String artifactId;
  final String patientProfileId;
  final String? referringDoctorId;
}

/// مدير طلبات التحاليل.
class LabTestRequestManager {
  LabTestRequestManager();

  final Map<String, LabTestRequest> _requests = {};
  final List<ReleasedClinicalCopy> _filedCopies = [];
  int _counter = 0;

  LabTestRequest createRequest({
    required String patientProfileId,
    required String laboratoryId,
    required List<String> testIds,
    String? referringDoctorId,
  }) {
    _counter++;
    final request = LabTestRequest(
      requestId: 'LAB-$_counter',
      patientProfileId: patientProfileId,
      laboratoryId: laboratoryId,
      testIds: testIds,
      referringDoctorId: referringDoctorId,
    );
    _requests[request.requestId] = request;
    return request;
  }

  void advanceStatus(String requestId, LabRequestStatus newStatus) {
    _requests[requestId]?.status = newStatus;
  }

  /// تسجيل النتيجة النهائية — يُصدر حدث "استلام نتيجة تحليل" ليستفيد
  /// منه الذكاء الاصطناعي أو تنبيهات المستخدم.
  void submitResult(String requestId, Map<String, dynamic> resultData) {
    final request = _requests[requestId];
    if (request == null) return;
    request.resultData = resultData;
    request.status = LabRequestStatus.resultReady;
    _fileBothCopies(request);

    final doctorId = request.referringDoctorId;
    HealthEventManager.instance.emitQuick(
      HealthEventType.labResultReceived,
      sourceModule: 'lab_test_request_manager',
      profileId: request.patientProfileId,
      data: {
        'requestId': requestId,
        if (doctorId != null) 'referringDoctorId': doctorId,
      },
    );
  }

  void _fileBothCopies(LabTestRequest request) {
    if (_filedCopies.any((c) => c.artifactId == request.requestId)) return;
    _filedCopies.add(
      ReleasedClinicalCopy(
        artifactId: request.requestId,
        patientProfileId: request.patientProfileId,
        referringDoctorId: request.referringDoctorId,
      ),
    );
  }

  List<ReleasedClinicalCopy> copiesForPatient(String patientProfileId) {
    return _filedCopies
        .where((c) => c.patientProfileId == patientProfileId)
        .toList(growable: false);
  }

  List<ReleasedClinicalCopy> copiesForReferringDoctor(String referringDoctorId) {
    return _filedCopies
        .where((c) => c.referringDoctorId == referringDoctorId)
        .toList(growable: false);
  }

  /// يغلق الطلب بعد أن تكون النسختان قد أُودعتا عند التسجيل.
  ReleasedClinicalCopy? deliverToReferrerAndCv(String requestId) {
    final request = _requests[requestId];
    if (request == null || request.resultData == null) return null;
    _fileBothCopies(request);
    request.status = LabRequestStatus.delivered;
    for (final copy in _filedCopies) {
      if (copy.artifactId == request.requestId) return copy;
    }
    return null;
  }

  List<LabTestRequest> pendingRequestsFor(String laboratoryId) {
    return _requests.values
        .where((r) =>
            r.laboratoryId == laboratoryId &&
            r.status != LabRequestStatus.resultReady &&
            r.status != LabRequestStatus.delivered)
        .toList();
  }

  List<LabTestRequest> readyResultsFor(String laboratoryId) {
    return _requests.values
        .where((r) =>
            r.laboratoryId == laboratoryId &&
            r.status == LabRequestStatus.resultReady)
        .toList();
  }
}
