/// =============================================================
/// Lifex-AI — وحدة الأسنان
/// الملف: dental_imaging_archive.dart
/// المسار: lib/features/dental/dental_imaging_archive.dart
/// الوصف: أرشيف صور الأسنان والأشعة البانورامية عبر الزمن لنفس المريض،
/// لمقارنة تطوّر الحالة بين الزيارات.
/// =============================================================
library;

enum DentalImageType { panoramicXray, periapicalXray, intraoralPhoto, panoramicScan }

class DentalImageRecord {
  final String imageId;
  final String patientProfileId;
  final DentalImageType imageType;
  final String storageReference; // مسار أو معرّف الملف المخزَّن
  final DateTime capturedAt;
  final String? notesAr;

  DentalImageRecord({
    required this.imageId,
    required this.patientProfileId,
    required this.imageType,
    required this.storageReference,
    DateTime? capturedAt,
    this.notesAr,
  }) : capturedAt = capturedAt ?? DateTime.now();
}

/// أرشيف صور الأسنان.
class DentalImagingArchive {
  DentalImagingArchive();

  final Map<String, List<DentalImageRecord>> _imagesByProfile = {};
  int _counter = 0;

  DentalImageRecord addImage({
    required String patientProfileId,
    required DentalImageType imageType,
    required String storageReference,
    String? notesAr,
  }) {
    _counter++;
    final record = DentalImageRecord(
      imageId: 'DIMG-$_counter',
      patientProfileId: patientProfileId,
      imageType: imageType,
      storageReference: storageReference,
      notesAr: notesAr,
    );
    _imagesByProfile.putIfAbsent(patientProfileId, () => []).add(record);
    return record;
  }

  List<DentalImageRecord> historyFor(String patientProfileId) =>
      List.unmodifiable(_imagesByProfile[patientProfileId] ?? const []);

  List<DentalImageRecord> historyByType(
    String patientProfileId,
    DentalImageType type,
  ) {
    return historyFor(patientProfileId).where((i) => i.imageType == type).toList();
  }
}
