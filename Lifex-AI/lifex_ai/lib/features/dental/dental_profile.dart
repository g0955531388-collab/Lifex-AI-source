/// =============================================================
/// Lifex-AI — وحدة الأسنان
/// الملف: dental_profile.dart
/// المسار: lib/features/dental/dental_profile.dart
/// الوصف: الملف العام (الخارجي) لطبيب أو مركز الأسنان.
/// =============================================================
library;

class DentalProfile {
  final String dentalProviderId;
  final String nameAr;
  final List<String> servicesOfferedAr;
  final double? averageRating;

  const DentalProfile({
    required this.dentalProviderId,
    required this.nameAr,
    this.servicesOfferedAr = const [],
    this.averageRating,
  });

  Map<String, dynamic> toJson() => {
        'dentalProviderId': dentalProviderId,
        'nameAr': nameAr,
        'servicesOfferedAr': servicesOfferedAr,
        'averageRating': averageRating,
      };

  factory DentalProfile.fromJson(Map<String, dynamic> json) => DentalProfile(
        dentalProviderId: json['dentalProviderId'] as String,
        nameAr: json['nameAr'] as String,
        servicesOfferedAr: (json['servicesOfferedAr'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        averageRating: (json['averageRating'] as num?)?.toDouble(),
      );
}
