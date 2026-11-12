/// =============================================================
/// Lifex-AI — التصوير الطبي والأشعة
/// الملف: imaging_center_profile.dart
/// المسار: lib/features/medical_imaging/imaging_center_profile.dart
/// الوصف: الملف العام (الخارجي) لمركز التصوير الطبي.
/// =============================================================
library;

enum ImagingModality { xray, ctScan, mri, ultrasound, mammography }

class ImagingCenterProfile {
  final String centerId;
  final String nameAr;
  final List<ImagingModality> availableModalities;

  const ImagingCenterProfile({
    required this.centerId,
    required this.nameAr,
    this.availableModalities = const [],
  });

  Map<String, dynamic> toJson() => {
        'centerId': centerId,
        'nameAr': nameAr,
        'availableModalities': availableModalities.map((m) => m.name).toList(),
      };

  factory ImagingCenterProfile.fromJson(Map<String, dynamic> json) =>
      ImagingCenterProfile(
        centerId: json['centerId'] as String,
        nameAr: json['nameAr'] as String,
        availableModalities: (json['availableModalities'] as List<dynamic>? ?? [])
            .map((e) => ImagingModality.values.firstWhere((m) => m.name == e))
            .toList(),
      );
}
