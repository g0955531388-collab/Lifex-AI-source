/// =============================================================
/// Lifex-AI — الصيدليات والمخابر
/// الملف: laboratory_profile.dart
/// المسار: lib/features/providers/laboratory_profile.dart
/// الوصف: الملف العام (الخارجي) للمخبر.
/// =============================================================
library;

class LaboratoryProfile {
  final String laboratoryId;
  final String nameAr;
  final String addressAr;
  final bool offersHomeSampleCollection;

  const LaboratoryProfile({
    required this.laboratoryId,
    required this.nameAr,
    required this.addressAr,
    this.offersHomeSampleCollection = false,
  });

  Map<String, dynamic> toJson() => {
        'laboratoryId': laboratoryId,
        'nameAr': nameAr,
        'addressAr': addressAr,
        'offersHomeSampleCollection': offersHomeSampleCollection,
      };

  factory LaboratoryProfile.fromJson(Map<String, dynamic> json) =>
      LaboratoryProfile(
        laboratoryId: json['laboratoryId'] as String,
        nameAr: json['nameAr'] as String,
        addressAr: json['addressAr'] as String,
        offersHomeSampleCollection:
            json['offersHomeSampleCollection'] as bool? ?? false,
      );
}
