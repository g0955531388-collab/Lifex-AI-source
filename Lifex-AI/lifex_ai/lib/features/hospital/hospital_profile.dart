/// =============================================================
/// Lifex-AI — وحدة المستشفيات
/// الملف: hospital_profile.dart
/// المسار: lib/features/hospital/hospital_profile.dart
/// الوصف: الملف العام (الخارجي) للمستشفى — ما يراه المريض عند البحث.
/// =============================================================
library;

class HospitalProfile {
  final String hospitalId;
  final String nameAr;
  final String addressAr;
  final List<String> departmentIds;
  final bool hasEmergencyRoom;
  final double? averageRating;

  const HospitalProfile({
    required this.hospitalId,
    required this.nameAr,
    required this.addressAr,
    this.departmentIds = const [],
    this.hasEmergencyRoom = true,
    this.averageRating,
  });

  Map<String, dynamic> toJson() => {
        'hospitalId': hospitalId,
        'nameAr': nameAr,
        'addressAr': addressAr,
        'departmentIds': departmentIds,
        'hasEmergencyRoom': hasEmergencyRoom,
        'averageRating': averageRating,
      };

  factory HospitalProfile.fromJson(Map<String, dynamic> json) =>
      HospitalProfile(
        hospitalId: json['hospitalId'] as String,
        nameAr: json['nameAr'] as String,
        addressAr: json['addressAr'] as String,
        departmentIds: (json['departmentIds'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        hasEmergencyRoom: json['hasEmergencyRoom'] as bool? ?? true,
        averageRating: (json['averageRating'] as num?)?.toDouble(),
      );
}
