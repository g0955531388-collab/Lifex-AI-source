// اختبارات: donor_eligibility_filter.dart — التركيز على استبعاد
// المتبرعين الرافضين لتلقي طلبات التبرع.

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/blood_network/donor_eligibility_filter.dart';
import 'package:lifex_ai/features/blood_network/donor_history_registry.dart';
import 'package:lifex_ai/features/blood_network/profile_donor_directory.dart';
import 'package:lifex_ai/features/hospital/hospital_blood_bank.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';

void main() {
  test(
      'متبرع رافض للتبرع (opted-out) لا يظهر أبداً ضمن المؤهلين حتى لو '
      'تطابقت فصيلته وموقعه تماماً', () {
    final filter = DonorEligibilityFilter(
      historyRegistry: DonorHistoryRegistry(),
      donorDirectory: () => [
        const DonorLocation(
          donorLifexId: 'LFX-1',
          bloodType: BloodTypeSimple.oPositive,
          latitude: 33.5,
          longitude: 36.3,
          hasOptedOutOfDonationAlerts: true,
        ),
        const DonorLocation(
          donorLifexId: 'LFX-2',
          bloodType: BloodTypeSimple.oPositive,
          latitude: 33.5,
          longitude: 36.3,
        ),
      ],
    );

    final eligible = filter.findEligibleDonors(
      bloodType: BloodTypeSimple.oPositive,
      centerLatitude: 33.5,
      centerLongitude: 36.3,
      radiusKm: 5,
    );

    expect(eligible.map((d) => d.donorLifexId), ['LFX-2']);
  });

  test('الحالة الافتراضية (لم يُحدَّد الحقل): يُعامَل كمشارك، ليس كرافض', () {
    final filter = DonorEligibilityFilter(
      historyRegistry: DonorHistoryRegistry(),
      donorDirectory: () => [
        const DonorLocation(
          donorLifexId: 'LFX-3',
          bloodType: BloodTypeSimple.aNegative,
          latitude: 33.5,
          longitude: 36.3,
        ),
      ],
    );

    final eligible = filter.findEligibleDonors(
      bloodType: BloodTypeSimple.aNegative,
      centerLatitude: 33.5,
      centerLongitude: 36.3,
      radiusKm: 5,
    );

    expect(eligible, hasLength(1));
  });

  test('من أوقف استقبال التبرع في ملفه الصحي لا يُدرَج في الدليل', () {
    final optedOut = HealthProfile(
      profileId: 'p-out',
      fullName: 'رافض',
      dateOfBirth: DateTime(1990, 1, 1),
      bloodType: BloodType.oPositive,
      acceptsBloodDonationAlerts: false,
    );
    final optedIn = HealthProfile(
      profileId: 'p-in',
      fullName: 'موافق',
      dateOfBirth: DateTime(1990, 1, 1),
      bloodType: BloodType.oPositive,
      acceptsBloodDonationAlerts: true,
    );
    final donors = ProfileDonorDirectory.fromProfiles([optedOut, optedIn]);
    final filter = DonorEligibilityFilter(
      historyRegistry: DonorHistoryRegistry(),
      donorDirectory: () => donors,
    );
    final eligible = filter.findEligibleDonors(
      bloodType: BloodTypeSimple.oPositive,
      centerLatitude: 0,
      centerLongitude: 0,
      radiusKm: 5,
      ignoreDistance: true,
    );
    expect(eligible.map((d) => d.donorLifexId), ['p-in']);
  });
}
