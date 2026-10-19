import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/admin/admin_manager.dart';
import 'package:lifex_ai/core/admin/admin_permissions.dart';
import 'package:lifex_ai/core/app_constants.dart';
import 'package:lifex_ai/core/trial_manager.dart';
import 'package:lifex_ai/features/profile/active_profile_controller.dart';
import 'package:lifex_ai/features/profile/health_identity_manager.dart';
import 'package:lifex_ai/features/profile/health_profile.dart';
import 'package:lifex_ai/features/profile/multi_profile_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HealthIdentityManager.instance.resetForTesting();
    GlobalAdminManager.instance.resetForTesting();
  });

  test('يحافظ على Lifex-ID ودور المالك عند استعادة ملف صحي محفوظ', () async {
    final originalEngine = MultiProfileEngine(maxProfiles: 4);
    final originalController = ActiveProfileController(engine: originalEngine);
    final profile = HealthProfile(
      profileId: 'persisted-owner',
      fullName: 'غازي',
      dateOfBirth: DateTime(1990, 1, 1),
    );
    originalController.createInitialProfile(
      profile,
      email: AppConstants.ownerEmail,
    );
    final lifexId = profile.questionnaireData['accountLifexId'] as String;
    expect(GlobalAdminManager.instance.roleOf(lifexId), GlobalAdminRole.owner);

    HealthIdentityManager.instance.resetForTesting();
    GlobalAdminManager.instance.resetForTesting();
    final restoredEngine = MultiProfileEngine(maxProfiles: 4)
      ..restoreFromJson(originalEngine.toJson());
    final restoredController = ActiveProfileController(engine: restoredEngine);
    await restoredController.rebindIdentitiesAfterRestore();

    expect(
      HealthIdentityManager.instance.getByProfileId('persisted-owner')?.lifexId,
      lifexId,
    );
    expect(GlobalAdminManager.instance.roleOf(lifexId), GlobalAdminRole.owner);
  });

  test('تحديث بيانات الاتصال بعد إنشاء الملف يفعّل وصول المالك فوراً', () {
    final engine = MultiProfileEngine(maxProfiles: 4);
    final controller = ActiveProfileController(engine: engine);
    final profile = HealthProfile(
      profileId: 'owner-contact-update',
      fullName: 'غازي',
      dateOfBirth: DateTime(1990, 1, 1),
    );
    controller.createInitialProfile(profile);
    final lifexId = profile.questionnaireData['accountLifexId'] as String;
    expect(GlobalAdminManager.instance.roleOf(lifexId), GlobalAdminRole.none);

    controller.updateAccountIdentity(phoneNumber: '٠٩٥٥٥٣١٣٨٨');

    expect(GlobalAdminManager.instance.roleOf(lifexId), GlobalAdminRole.owner);
    expect(
      const SessionAccessPolicy().canOpenUnit(
        'box',
        phase: TrialPhase.residual,
        feeExempt: false,
        adminAccess: true,
      ),
      isTrue,
    );
  });
}
