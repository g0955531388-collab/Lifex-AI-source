/// =============================================================
/// Lifex-AI — الصيدليات والمخابر
/// الملف: pharmacy_profile.dart
/// المسار: lib/features/providers/pharmacy_profile.dart
/// الوصف: الملف العام (الخارجي) للصيدلية.
/// =============================================================
library;

class PharmacyProfile {
  final String pharmacyId;
  final String nameAr;
  final String addressAr;
  final bool offersDelivery;
  final bool open24Hours;

  const PharmacyProfile({
    required this.pharmacyId,
    required this.nameAr,
    required this.addressAr,
    this.offersDelivery = false,
    this.open24Hours = false,
  });

  Map<String, dynamic> toJson() => {
        'pharmacyId': pharmacyId,
        'nameAr': nameAr,
        'addressAr': addressAr,
        'offersDelivery': offersDelivery,
        'open24Hours': open24Hours,
      };

  factory PharmacyProfile.fromJson(Map<String, dynamic> json) =>
      PharmacyProfile(
        pharmacyId: json['pharmacyId'] as String,
        nameAr: json['nameAr'] as String,
        addressAr: json['addressAr'] as String,
        offersDelivery: json['offersDelivery'] as bool? ?? false,
        open24Hours: json['open24Hours'] as bool? ?? false,
      );
}
