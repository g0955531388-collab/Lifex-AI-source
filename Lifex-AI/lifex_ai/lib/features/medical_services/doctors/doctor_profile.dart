/// =============================================================
/// Lifex-AI — الأطباء والمستشفيات
/// الملف: doctor_profile.dart
/// المسار: lib/features/medical_services/doctors/doctor_profile.dart
/// الوصف: الملف العام (الخارجي) للطبيب — ما يراه المريض عند البحث عن
/// طبيب أو حجز موعد. البيانات الإدارية الداخلية (جداول المناوبات
/// التفصيلية) تُدار في doctor_dashboard.dart وdoctor_schedule_manager.dart.
/// =============================================================
library;

class DoctorProfile {
  final String doctorId;
  final String fullName;
  final String specialtyAr;
  final String? affiliatedHospitalId;
  final double? averageRating;
  final int reviewsCount;
  final bool acceptsNewPatients;
  final List<String> languagesSpoken;

  const DoctorProfile({
    required this.doctorId,
    required this.fullName,
    required this.specialtyAr,
    this.affiliatedHospitalId,
    this.averageRating,
    this.reviewsCount = 0,
    this.acceptsNewPatients = true,
    this.languagesSpoken = const ['ar'],
  });

  Map<String, dynamic> toJson() => {
        'doctorId': doctorId,
        'fullName': fullName,
        'specialtyAr': specialtyAr,
        'affiliatedHospitalId': affiliatedHospitalId,
        'averageRating': averageRating,
        'reviewsCount': reviewsCount,
        'acceptsNewPatients': acceptsNewPatients,
        'languagesSpoken': languagesSpoken,
      };

  factory DoctorProfile.fromJson(Map<String, dynamic> json) => DoctorProfile(
        doctorId: json['doctorId'] as String,
        fullName: json['fullName'] as String,
        specialtyAr: json['specialtyAr'] as String,
        affiliatedHospitalId: json['affiliatedHospitalId'] as String?,
        averageRating: (json['averageRating'] as num?)?.toDouble(),
        reviewsCount: json['reviewsCount'] as int? ?? 0,
        acceptsNewPatients: json['acceptsNewPatients'] as bool? ?? true,
        languagesSpoken: (json['languagesSpoken'] as List<dynamic>? ?? ['ar'])
            .map((e) => e as String)
            .toList(),
      );
}
