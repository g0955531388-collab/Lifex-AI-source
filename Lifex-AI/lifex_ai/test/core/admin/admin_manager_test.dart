import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/admin/admin_manager.dart';
import 'package:lifex_ai/core/admin/admin_permissions.dart';
import 'package:lifex_ai/core/admin/owner_identity_policy.dart';
import 'package:lifex_ai/core/app_constants.dart';
import 'package:lifex_ai/features/profile/health_identity_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GlobalAdminManager.instance.resetForTesting();
    HealthIdentityManager.instance.resetForTesting();
  });

  String toArabicIndic(String value) {
    const western = '0123456789';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    return value.split('').map((char) {
      final index = western.indexOf(char);
      return index < 0 ? char : arabic[index];
    }).join();
  }

  group('رفض تفعيل المالك من النص', () {
    test('البريد أو الهاتف أو الاسم لا يمنح owner', () {
      final admin = GlobalAdminManager.instance;
      expect(
        admin.autoActivateOwnerIfMatches(
          lifexId: 'LFX-mail',
          email: AppConstants.ownerEmail,
        ),
        GlobalAdminRole.none,
      );
      expect(
        admin.autoActivateOwnerIfMatches(
          lifexId: 'LFX-seal',
          email: AppConstants.officialContactEmail,
        ),
        GlobalAdminRole.none,
      );
      expect(
        admin.autoActivateOwnerIfMatches(
          lifexId: 'LFX-phone',
          phoneNumber: toArabicIndic(AppConstants.ownerPhoneNumber),
        ),
        GlobalAdminRole.none,
      );
      expect(
        admin.autoActivateOwnerIfMatches(
          lifexId: 'LFX-name',
          email: 'غازي سليم بكفلاوي',
          phoneNumber: 'غازي سليم بكفلاوي',
        ),
        GlobalAdminRole.none,
      );
      expect(admin.isOwner('LFX-mail'), isFalse);
      expect(admin.hasFullOperationalControlAsOwner, isFalse);
    });

    test('تلميح التفعيل لا يكشف بريد المالك ولا هاتفه', () {
      final hint = const OwnerIdentityPolicy().activationHintAr();
      expect(hint.contains(AppConstants.ownerEmail), isFalse);
      expect(hint.contains(AppConstants.ownerPhoneNumber), isFalse);
      expect(hint.contains(AppConstants.officialContactEmail), isFalse);
    });

    test('تغيير الاتصال بعد الإنشاء لا يُبقي صلاحية مالك', () {
      final ids = HealthIdentityManager.instance;
      final created = ids.createIdentity(profileId: 'p-contact');
      ids.updateContactAndReactivateOwner(
        lifexId: created.lifexId,
        email: AppConstants.ownerEmail,
        phoneNumber: AppConstants.ownerPhoneNumber,
      );
      expect(
        GlobalAdminManager.instance.roleOf(created.lifexId),
        GlobalAdminRole.none,
      );
      expect(created.verificationLevel, IdentityVerificationLevel.unverified);
    });
  });

  group('فصل الأدمن وتعليق المالك المخزّن', () {
    test('خريطة الأدمن لا تحتوي صلاحيات المالك المحظورة', () {
      final adminPerms = defaultGlobalRolePermissions[GlobalAdminRole.admin]!;
      expect(adminPerms, isNot(contains(GlobalAdminPermission.grantAdminRole)));
      expect(adminPerms, isNot(contains(GlobalAdminPermission.grantStaffRole)));
      expect(adminPerms, isNot(contains(GlobalAdminPermission.manageBilling)));
      expect(
        adminPerms,
        isNot(contains(GlobalAdminPermission.manageEmergencyPolicy)),
      );
      expect(
        adminPerms,
        isNot(contains(GlobalAdminPermission.manageRemoteCameraMonitoring)),
      );
      expect(
        defaultGlobalRolePermissions[GlobalAdminRole.owner],
        contains(GlobalAdminPermission.manageRemoteCameraMonitoring),
      );
    });

    test('سجل owner المخزّن يُعلَّق ولا يعود تشغيلياً', () async {
      final admin = GlobalAdminManager.instance;
      SharedPreferences.setMockInitialValues({
        GlobalAdminManager.rolesStorageKey: jsonEncode({
          'LFX-ADMIN-1': 'admin',
          'LFX-OLD-OWNER': 'owner',
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      await admin.initialize(prefs);
      await admin.flushPersistence();

      expect(admin.roleOf('LFX-OLD-OWNER'), GlobalAdminRole.none);
      expect(admin.quarantinedOwnerIds, contains('LFX-OLD-OWNER'));
      expect(admin.roleOf('LFX-ADMIN-1'), GlobalAdminRole.admin);
      final stored = prefs.getString(GlobalAdminManager.rolesStorageKey);
      expect(stored, isNot(contains('owner')));
      final quarantine =
          prefs.getString(GlobalAdminManager.ownerQuarantineStorageKey);
      expect(quarantine, contains('LFX-OLD-OWNER'));
      expect(
        quarantine,
        contains(GlobalAdminManager.ownerQuarantineReason),
      );
    });

    test('الأدمن لا يمنح أدمن ولا يفتح كاميرا بعيدة، ومعرّف الملف مرفوض', () async {
      final admin = GlobalAdminManager.instance;
      final ids = HealthIdentityManager.instance;
      SharedPreferences.setMockInitialValues({
        GlobalAdminManager.rolesStorageKey: jsonEncode({
          'LFX-ADMIN-1': 'admin',
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      await admin.initialize(prefs);
      final identity = ids.createIdentity(
        profileId: 'profile-admin',
        preferredLifexId: 'LFX-ADMIN-1',
      );
      admin.bindActorLookup(ids.actorIsOperationalLifexId);

      final byProfile = admin.grantRole(
        granterLifexId: identity.linkedProfileId,
        targetLifexId: 'LFX-OTHER',
        role: GlobalAdminRole.moderator,
      );
      expect(byProfile.success, isFalse);
      expect(admin.roleOf('LFX-OTHER'), GlobalAdminRole.none);

      final grantAdmin = admin.grantRole(
        granterLifexId: identity.lifexId,
        targetLifexId: 'LFX-NEW-ADMIN',
        role: GlobalAdminRole.admin,
      );
      expect(grantAdmin.success, isFalse);
      expect(admin.roleOf('LFX-NEW-ADMIN'), GlobalAdminRole.none);

      final grantOwner = admin.grantRole(
        granterLifexId: identity.lifexId,
        targetLifexId: 'LFX-FAKE-OWNER',
        role: GlobalAdminRole.owner,
      );
      expect(grantOwner.success, isFalse);

      final grantMod = admin.grantRole(
        granterLifexId: identity.lifexId,
        targetLifexId: 'LFX-MOD',
        role: GlobalAdminRole.moderator,
      );
      expect(grantMod.success, isTrue);
      expect(admin.roleOf('LFX-MOD'), GlobalAdminRole.moderator);

      final camera = admin.setEventToggle(
        actorLifexId: identity.lifexId,
        eventKey: GlobalAdminManager.remoteCameraEventKey,
        enabled: false,
      );
      expect(camera.success, isFalse);
      expect(admin.isEventEnabled(GlobalAdminManager.remoteCameraEventKey), isTrue);

      final blood = admin.setEventToggle(
        actorLifexId: identity.lifexId,
        eventKey: 'blood_network_flash_alerts_enabled',
        enabled: false,
      );
      expect(blood.success, isTrue);
      expect(admin.isEventEnabled('blood_network_flash_alerts_enabled'), isFalse);
    });
  });

  group('المالك على الهوية المربوطة', () {
    test('البريد أو الهاتف المعتمدان يفتحان المالك، والذيل والاسم لا يفتحانه', () {
      final admin = GlobalAdminManager.instance;
      final ids = HealthIdentityManager.instance;
      admin.bindActorLookup(ids.actorIsOperationalLifexId);

      final byMail = ids.createIdentity(
        profileId: 'p-mail-owner',
        email: AppConstants.ownerEmail,
      );
      expect(admin.isOwner(byMail.lifexId), isTrue);
      expect(admin.hasFullOperationalControlAsOwner, isTrue);

      final byPhone = ids.createIdentity(
        profileId: 'p-phone-owner',
        phoneNumber: toArabicIndic(AppConstants.ownerPhoneNumber),
      );
      expect(admin.isOwner(byPhone.lifexId), isTrue);

      final suffix = ids.createIdentity(
        profileId: 'p-suffix',
        phoneNumber: '${AppConstants.ownerPhoneNumber}9',
      );
      expect(admin.isOwner(suffix.lifexId), isFalse);

      final nameOnly = ids.createIdentity(
        profileId: 'p-name',
        email: 'غازي سليم بكفلاوي',
      );
      expect(admin.isOwner(nameOnly.lifexId), isFalse);
      expect(
        admin.autoActivateOwnerIfMatches(
          lifexId: 'LFX-spoof',
          email: AppConstants.ownerEmail,
          phoneNumber: AppConstants.ownerPhoneNumber,
        ),
        GlobalAdminRole.none,
      );

      ids.updateContactAndReactivateOwner(
        lifexId: byMail.lifexId,
        email: 'not-owner@example.com',
        phoneNumber: '',
      );
      expect(admin.isOwner(byMail.lifexId), isFalse);
    });

    test('المالك يعيّن مديراً وموظفاً ومشرفاً والمدير لا يرفع أحداً إلى مدير', () {
      final admin = GlobalAdminManager.instance;
      final ids = HealthIdentityManager.instance;
      admin.bindActorLookup(ids.actorIsOperationalLifexId);
      final owner = ids.createIdentity(
        profileId: 'p-owner',
        email: AppConstants.officialContactEmail,
      );
      final manager = ids.createIdentity(
        profileId: 'p-manager',
        preferredLifexId: 'LFX-MANAGER',
      );

      final asManager = admin.grantRole(
        granterLifexId: owner.lifexId,
        targetLifexId: manager.lifexId,
        role: GlobalAdminRole.admin,
        engagement: StaffEngagement.paid,
      );
      expect(asManager.success, isTrue);
      expect(admin.roleOf(manager.lifexId), GlobalAdminRole.admin);
      expect(admin.engagementOf(manager.lifexId), StaffEngagement.paid);

      final employee = admin.grantRole(
        granterLifexId: owner.lifexId,
        targetLifexId: 'LFX-EMP',
        role: GlobalAdminRole.employee,
        engagement: StaffEngagement.volunteer,
      );
      expect(employee.success, isTrue);
      expect(admin.engagementOf('LFX-EMP'), StaffEngagement.volunteer);

      final supervisor = admin.grantRole(
        granterLifexId: owner.lifexId,
        targetLifexId: 'LFX-SUP',
        role: GlobalAdminRole.moderator,
        engagement: StaffEngagement.paid,
      );
      expect(supervisor.success, isTrue);

      final ownerCopy = admin.grantRole(
        granterLifexId: owner.lifexId,
        targetLifexId: 'LFX-OTHER-OWNER',
        role: GlobalAdminRole.owner,
      );
      expect(ownerCopy.success, isFalse);

      final managerRaises = admin.grantRole(
        granterLifexId: manager.lifexId,
        targetLifexId: 'LFX-NEW-ADMIN',
        role: GlobalAdminRole.admin,
      );
      expect(managerRaises.success, isFalse);
      final managerHires = admin.grantRole(
        granterLifexId: manager.lifexId,
        targetLifexId: 'LFX-NEW-EMP',
        role: GlobalAdminRole.employee,
      );
      expect(managerHires.success, isFalse);
      final managerSupervises = admin.grantRole(
        granterLifexId: manager.lifexId,
        targetLifexId: 'LFX-NEW-MOD',
        role: GlobalAdminRole.moderator,
      );
      expect(managerSupervises.success, isTrue);
    });
  });
}
