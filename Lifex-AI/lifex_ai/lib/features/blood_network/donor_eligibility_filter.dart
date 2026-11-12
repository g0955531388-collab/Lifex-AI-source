/// =============================================================
/// Lifex-AI — شبكة التبرع بالدم
/// الملف: donor_eligibility_filter.dart
/// المسار: lib/features/blood_network/donor_eligibility_filter.dart
/// الوصف: تحديد المتبرعين المؤهلين لطلب دم معيّن حسب فصيلة الدم،
/// القرب الجغرافي، وأهلية التبرع (لم يتبرع مؤخراً، لا مانع صحي معروف).
/// =============================================================
library;

import 'dart:math' as math;

import '../hospital/hospital_blood_bank.dart';
import 'blood_type_match.dart';
import 'donor_history_registry.dart';

class DonorLocation {
  final String donorLifexId;
  final BloodTypeSimple bloodType;
  final double latitude;
  final double longitude;

  /// انعكاس مباشر لخيار المستخدم في ملفه الصحي: "لا أرغب في تلقّي طلبات
  /// تبرع بالدم". القيمة الافتراضية false (أي مشارك بشكل افتراضي) لأن كل
  /// من يسجّل بياناته كمتبرع أصلاً في نظام Lifex Blood Network قد وافق
  /// على المبدأ؛ هذا الحقل هو تراجع صريح لاحق، وليس اشتراكاً إضافياً.
  final bool hasOptedOutOfDonationAlerts;
  final String city;
  final String profileId;
  final bool hasReliableFix;
  final double? preferredRadiusKm;

  const DonorLocation({
    required this.donorLifexId,
    required this.bloodType,
    required this.latitude,
    required this.longitude,
    this.hasOptedOutOfDonationAlerts = false,
    this.city = '',
    this.profileId = '',
    this.hasReliableFix = true,
    this.preferredRadiusKm,
  });
}

/// فلترة المتبرعين المؤهلين لطلب دم معيّن.
class DonorEligibilityFilter {
  DonorEligibilityFilter({
    required this.historyRegistry,
    required this.donorDirectory,
  });

  final DonorHistoryRegistry historyRegistry;

  /// دالة تُرجع كل المتبرعين المسجَّلين (تُربط لاحقاً بقاعدة بيانات
  /// فعلية عوضاً عن قائمة ثابتة في الذاكرة).
  final List<DonorLocation> Function() donorDirectory;

  /// الحد الأدنى للفاصل الزمني بين تبرعين متتاليين لنفس الشخص (بالأيام)
  /// — قاعدة سلامة طبية عامة معروفة، وليست قابلة للتعديل من واجهة عادية.
  static const int minimumDaysBetweenDonations = 90;

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * earthRadiusKm * math.asin(math.sqrt(a));
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  static bool coordinatesUsable(double latitude, double longitude) {
    if (latitude == 0 && longitude == 0) return false;
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    return true;
  }

  List<DonorLocation> findEligibleDonors({
    required BloodTypeSimple bloodType,
    required double centerLatitude,
    required double centerLongitude,
    required double radiusKm,
    bool ignoreDistance = false,
    bool compatibleRedCells = false,
    String targetCity = '',
  }) {
    final allDonors = donorDirectory();
    final wantedCity = targetCity.trim().toLowerCase();

    return allDonors.where((donor) {
      // الشرط الأول دائماً: احترام رفض المستخدم الصريح لتلقي طلبات
      // التبرع، بصرف النظر عن مدى توافقه الطبي أو الجغرافي مع الطلب.
      if (donor.hasOptedOutOfDonationAlerts) return false;

      final typeMatches = compatibleRedCells
          ? BloodTypeMatch.canDonateRedCells(donor.bloodType, bloodType)
          : donor.bloodType == bloodType;
      if (!typeMatches) return false;

      final donorCity = donor.city.trim().toLowerCase();
      if (wantedCity.isNotEmpty &&
          donorCity.isNotEmpty &&
          donorCity != wantedCity) {
        return false;
      }

      if (!ignoreDistance) {
        if (radiusKm <= 0) return false;
        final centerOk = coordinatesUsable(centerLatitude, centerLongitude);
        if (!donor.hasReliableFix || !centerOk) {
          if (wantedCity.isEmpty ||
              donorCity.isEmpty ||
              donorCity != wantedCity) {
            return false;
          }
        } else {
          final distance = _distanceKm(
            centerLatitude,
            centerLongitude,
            donor.latitude,
            donor.longitude,
          );
          final preferred = donor.preferredRadiusKm;
          final cap =
              preferred == null || preferred > radiusKm ? radiusKm : preferred;
          if (distance > cap) return false;
        }
      }

      final lastDonation =
          historyRegistry.lastDonationDateFor(donor.donorLifexId);
      if (lastDonation != null) {
        final daysSince = DateTime.now().difference(lastDonation).inDays;
        if (daysSince < minimumDaysBetweenDonations) return false;
      }

      return true;
    }).toList();
  }
}
