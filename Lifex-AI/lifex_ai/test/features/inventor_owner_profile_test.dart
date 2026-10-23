import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/admin/admin_manager.dart';
import 'package:lifex_ai/core/admin/admin_permissions.dart';
import 'package:lifex_ai/core/app_constants.dart';
import 'package:lifex_ai/features/profile/active_profile_controller.dart';
import 'package:lifex_ai/features/profile/health_identity_manager.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';
import 'package:lifex_ai/features/profile/inventor_owner_profile.dart';
import 'package:lifex_ai/features/profile/multi_profile_engine.dart';
import 'package:lifex_ai/features/profile/profile_privacy_manager.dart';

void main() {
  late ActiveProfileController controller;

  setUp(() {
    controller = ActiveProfileController(engine: MultiProfileEngine());
    HealthIdentityManager.instance.resetForTesting();
    ProfilePrivacyRegistry.instance.resetForTesting();
    GlobalAdminManager.instance.resetForTesting();
  });

  test('ملف المخترع لا يفتح دور المالك والاسم وحده يبقى بلا دور', () {
    final draft = InventorOwnerProfileDraft.official();
    expect(draft.profile.fullName, 'غازي سليم بكفلاوي');
    expect(draft.email, AppConstants.ownerEmail);
    expect(draft.phone, AppConstants.ownerPhoneNumber);
    expect(draft.profile.statedAgeYears, isNull);
    expect(draft.profile.dateOfBirth, isNull);
    expect(draft.profile.bloodType, BloodType.unknown);
    expect(draft.profile.chronicConditions, isEmpty);

    final created = controller.createInitialProfile(
      draft.profile,
      email: draft.email,
      phoneNumber: draft.phone,
    );
    expect(created.success, isTrue);
    final ownerIdentity = HealthIdentityManager.instance
        .getByProfileId(InventorOwnerProfileDraft.profileId);
    expect(
      GlobalAdminManager.instance.roleOf(ownerIdentity!.lifexId),
      GlobalAdminRole.none,
    );

    final nameOnly = HealthProfile(
      profileId: 'name-only',
      fullName: 'غازي سليم بكفلاوي',
    );
    final added = controller.addFamilyMember(
      nameOnly,
      role: ProfileRole.otherRelative,
    );
    expect(added.success, isTrue);
    final plain = HealthIdentityManager.instance.getByProfileId('name-only');
    expect(
      GlobalAdminManager.instance.roleOf(plain!.lifexId),
      GlobalAdminRole.none,
    );
  });
}
