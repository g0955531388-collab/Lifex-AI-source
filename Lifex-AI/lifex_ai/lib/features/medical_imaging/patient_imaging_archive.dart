/// =============================================================
/// Lifex-AI — التصوير الطبي والأشعة
/// الملف: patient_imaging_archive.dart
/// المسار: lib/features/medical_imaging/patient_imaging_archive.dart
/// الوصف: أرشيف صور الأشعة/الرنين/السونار الخاصة بمريض معيّن عبر الزمن،
/// لتمكين مقارنة زمنية بين فحصين لنفس المنطقة.
/// =============================================================
library;

import 'imaging_center_profile.dart';

class PatientImagingRecord {
  final String imageId;
  final String patientProfileId;
  final String? referringDoctorId;
  final ImagingModality modality;
  final String bodyRegionAr;
  final String storageReference;
  final DateTime capturedAt;

  PatientImagingRecord({
    required this.imageId,
    required this.patientProfileId,
    required this.modality,
    required this.bodyRegionAr,
    required this.storageReference,
    this.referringDoctorId,
    DateTime? capturedAt,
  }) : capturedAt = capturedAt ?? DateTime.now();
}

/// أرشيف الصور الطبية للمريض.
class PatientImagingArchive {
  PatientImagingArchive();

  final Map<String, List<PatientImagingRecord>> _archive = {};
  final Map<String, List<String>> _doctorCopies = {};
  int _counter = 0;

  PatientImagingRecord addRecord({
    required String patientProfileId,
    required ImagingModality modality,
    required String bodyRegionAr,
    required String storageReference,
    String? referringDoctorId,
  }) {
    _counter++;
    final record = PatientImagingRecord(
      imageId: 'PIMG-$_counter',
      patientProfileId: patientProfileId,
      modality: modality,
      bodyRegionAr: bodyRegionAr,
      storageReference: storageReference,
      referringDoctorId: referringDoctorId,
    );
    _archive.putIfAbsent(patientProfileId, () => []).add(record);
    if (referringDoctorId != null && referringDoctorId.isNotEmpty) {
      _doctorCopies.putIfAbsent(referringDoctorId, () => []).add(record.imageId);
    }
    return record;
  }

  List<String> copiesForReferringDoctor(String referringDoctorId) =>
      List.unmodifiable(_doctorCopies[referringDoctorId] ?? const []);

  List<PatientImagingRecord> historyForRegion(
    String patientProfileId,
    String bodyRegionAr,
  ) {
    final all = _archive[patientProfileId] ?? const [];
    return all.where((r) => r.bodyRegionAr == bodyRegionAr).toList()
      ..sort((a, b) => a.capturedAt.compareTo(b.capturedAt));
  }

  List<PatientImagingRecord> allRecordsFor(String patientProfileId) =>
      List.unmodifiable(_archive[patientProfileId] ?? const []);
}
