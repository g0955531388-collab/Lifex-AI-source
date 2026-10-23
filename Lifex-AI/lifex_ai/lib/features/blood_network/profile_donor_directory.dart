/// =============================================================
/// Lifex-AI — شبكة التبرع بالدم
/// الملف: profile_donor_directory.dart
/// المسار: lib/features/blood_network/profile_donor_directory.dart
/// الوصف: يحوّل الملفات الصحية المحلية إلى دليل متبرعين. الفلاش يصل
/// فقط لمن لم يوقف استقبال الطلبات في ملفه.
/// =============================================================
library lifex_ai.features.blood_network.profile_donor_directory;

import '../profile/health_identity_manager.dart';
import '../profile/health_profile.dart';
import '../hospital/hospital_blood_bank.dart';
import 'donor_eligibility_filter.dart';

class ProfileDonorDirectory {
  const ProfileDonorDirectory._();

  static BloodTypeSimple? toSimple(BloodType type) {
    switch (type) {
      case BloodType.aPositive:
        return BloodTypeSimple.aPositive;
      case BloodType.aNegative:
        return BloodTypeSimple.aNegative;
      case BloodType.bPositive:
        return BloodTypeSimple.bPositive;
      case BloodType.bNegative:
        return BloodTypeSimple.bNegative;
      case BloodType.abPositive:
        return BloodTypeSimple.abPositive;
      case BloodType.abNegative:
        return BloodTypeSimple.abNegative;
      case BloodType.oPositive:
        return BloodTypeSimple.oPositive;
      case BloodType.oNegative:
        return BloodTypeSimple.oNegative;
      case BloodType.unknown:
        return null;
    }
  }

  static List<DonorLocation> fromProfiles(Iterable<HealthProfile> profiles) {
    final donors = <DonorLocation>[];
    for (final profile in profiles) {
      final simple = toSimple(profile.bloodType);
      if (simple == null) continue;
      final identity =
          HealthIdentityManager.instance.getByProfileId(profile.profileId);
      final city = profile.questionnaireData['bloodCity']?.toString() ?? '';
      final latRaw = profile.questionnaireData['bloodLatitude'];
      final lonRaw = profile.questionnaireData['bloodLongitude'];
      final lat = latRaw is num ? latRaw.toDouble() : 0.0;
      final lon = lonRaw is num ? lonRaw.toDouble() : 0.0;
      final usable = DonorEligibilityFilter.coordinatesUsable(lat, lon);
      final radiusRaw = profile.questionnaireData['bloodRadiusKm'];
      donors.add(
        DonorLocation(
          donorLifexId: identity?.lifexId ?? profile.profileId,
          bloodType: simple,
          latitude: usable ? lat : 0,
          longitude: usable ? lon : 0,
          hasOptedOutOfDonationAlerts: !profile.acceptsBloodDonationAlerts,
          city: city,
          profileId: profile.profileId,
          hasReliableFix: usable,
          preferredRadiusKm: radiusRaw is num ? radiusRaw.toDouble() : null,
        ),
      );
    }
    return donors;
  }
}
