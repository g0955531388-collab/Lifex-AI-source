// =============================================================
// Lifex-AI — اختبارات الوحدة
// الملف: admin_manager_test.dart
// المسار: test/core/admin/admin_manager_test.dart
// الوصف: يغطي: تفعيل دور المالك تلقائياً عبر البريد/الهاتف المطابقين
// فقط، رفض منح دور أدمن من غير المالك، سماح الأدمن بمنح دور مشرف،
// استحالة منح/سحب دور المالك يدوياً بأي حال، والتحكم بمفاتيح الأحداث
// الدقيقة حسب الصلاحية.
// =============================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/core/admin/admin_manager.dart';
import 'package:lifex_ai/core/admin/admin_permissions.dart';
import 'package:lifex_ai/core/app_constants.dart';
import 'package:lifex_ai/features/profile/health_identity_manager.dart';

void main() {
  setUp(() {
    GlobalAdminManager.instance.resetForTesting();
  });

  group('تفعيل دور المالك التلقائي', () {
    test('يُفعَّل owner عند تطابق البريد الإلكتروني تماماً', () {
      final admin = GlobalAdminManager.instance;
      final role = admin.autoActivateOwnerIfMatches(
        lifexId: 'LFX-000001',
        email: AppConstants.ownerEmail,
      );
      expect(role, GlobalAdminRole.owner);
    });

    test('يُفعَّل owner عند تطابق بريد الختم الرسمي أيضاً', () {
      final admin = GlobalAdminManager.instance;
      final role = admin.autoActivateOwnerIfMatches(
        lifexId: 'LFX-000001b',
        email: AppConstants.officialContactEmail,
      );
      expect(role, GlobalAdminRole.owner);
    });

    test('يُفعَّل owner عند تطابق رقم الهاتف تماماً', () {
      final admin = GlobalAdminManager.instance;
      final role = admin.autoActivateOwnerIfMatches(
        lifexId: 'LFX-000002',
        phoneNumber: AppConstants.ownerPhoneNumber,
      );
      expect(role, GlobalAdminRole.owner);
    });

    test('لا يُفعَّل owner لأي بريد أو هاتف مختلف', () {
      final admin = GlobalAdminManager.instance;
      final role = admin.autoActivateOwnerIfMatches(
        lifexId: 'LFX-000003',
        email: 'someone-else@example.com',
        phoneNumber: '+10000000000',
      );
      expect(role, GlobalAdminRole.none);
    });
  });

  group('قواعد منح وسحب الأدوار', () {
    test('المالك يمنح دور أدمن بنجاح', () {
      final admin = GlobalAdminManager.instance;
      admin.autoActivateOwnerIfMatches(
        lifexId: 'owner1',
        email: AppConstants.ownerEmail,
      );

      final result = admin.grantRole(
        granterLifexId: 'owner1',
        targetLifexId: 'user1',
        role: GlobalAdminRole.admin,
      );

      expect(result.success, isTrue);
      expect(admin.roleOf('user1'), GlobalAdminRole.admin);
    });

    test('مستخدم عادي لا يستطيع منح دور أدمن لأحد', () {
      final admin = GlobalAdminManager.instance;

      final result = admin.grantRole(
        granterLifexId: 'random_user',
        targetLifexId: 'user2',
        role: GlobalAdminRole.admin,
      );

      expect(result.success, isFalse);
      expect(admin.roleOf('user2'), GlobalAdminRole.none);
    });

    test('الأدمن يستطيع منح دور مشرف لكن ليس دور أدمن', () {
      final admin = GlobalAdminManager.instance;
      admin.autoActivateOwnerIfMatches(
        lifexId: 'owner2',
        email: AppConstants.ownerEmail,
      );
      admin.grantRole(
        granterLifexId: 'owner2',
        targetLifexId: 'admin1',
        role: GlobalAdminRole.admin,
      );

      final moderatorResult = admin.grantRole(
        granterLifexId: 'admin1',
        targetLifexId: 'mod1',
        role: GlobalAdminRole.moderator,
      );
      expect(moderatorResult.success, isTrue);
      expect(admin.roleOf('mod1'), GlobalAdminRole.moderator);

      final adminResult = admin.grantRole(
        granterLifexId: 'admin1',
        targetLifexId: 'user3',
        role: GlobalAdminRole.admin,
      );
      expect(adminResult.success, isFalse);
      expect(admin.roleOf('user3'), GlobalAdminRole.none);
    });

    test('لا يمكن منح دور المالك يدوياً بأي حال', () {
      final admin = GlobalAdminManager.instance;
      admin.autoActivateOwnerIfMatches(
        lifexId: 'owner3',
        email: AppConstants.ownerEmail,
      );

      final result = admin.grantRole(
        granterLifexId: 'owner3',
        targetLifexId: 'user4',
        role: GlobalAdminRole.owner,
      );

      expect(result.success, isFalse);
      expect(admin.roleOf('user4'), GlobalAdminRole.none);
    });

    test('لا يمكن سحب دور المالك عن نفسه أو عن غيره', () {
      final admin = GlobalAdminManager.instance;
      admin.autoActivateOwnerIfMatches(
        lifexId: 'owner4',
        email: AppConstants.ownerEmail,
      );

      final result = admin.revokeRole(
        granterLifexId: 'owner4',
        targetLifexId: 'owner4',
      );

      expect(result.success, isFalse);
      expect(admin.roleOf('owner4'), GlobalAdminRole.owner);
    });
  });

  group('مفاتيح الأحداث الدقيقة', () {
    test('الأدمن يستطيع تعطيل تنبيهات شبكة الدم', () {
      final admin = GlobalAdminManager.instance;
      admin.autoActivateOwnerIfMatches(
        lifexId: 'owner5',
        email: AppConstants.ownerEmail,
      );

      expect(admin.isEventEnabled('blood_network_flash_alerts_enabled'), isTrue);

      final result = admin.setEventToggle(
        actorLifexId: 'owner5',
        eventKey: 'blood_network_flash_alerts_enabled',
        enabled: false,
      );

      expect(result.success, isTrue);
      expect(admin.isEventEnabled('blood_network_flash_alerts_enabled'), isFalse);
    });

    test('مستخدم عادي لا يستطيع التحكم بمفاتيح الأحداث', () {
      final admin = GlobalAdminManager.instance;

      final result = admin.setEventToggle(
        actorLifexId: 'random_user2',
        eventKey: 'ai_gateway_enabled',
        enabled: false,
      );

      expect(result.success, isFalse);
      expect(admin.isEventEnabled('ai_gateway_enabled'), isTrue);
    });
  });

  group('صلاحيات المخترع الكاملة وتعيين الأدمنز', () {
    test('المالك يملك grantAdminRole وجميع صلاحيات الدور', () {
      final admin = GlobalAdminManager.instance;
      admin.autoActivateOwnerIfMatches(
        lifexId: 'LFX-full',
        email: AppConstants.officialContactEmail,
      );
      expect(admin.roleOf('LFX-full'), GlobalAdminRole.owner);
      expect(
        admin.permissionsOf('LFX-full'),
        defaultGlobalRolePermissions[GlobalAdminRole.owner],
      );
      expect(
        admin.hasPermission('LFX-full', GlobalAdminPermission.grantAdminRole),
        isTrue,
      );
      expect(
        admin.hasPermission(
          'LFX-full',
          GlobalAdminPermission.grantModeratorRole,
        ),
        isTrue,
      );
    });

    test('تحديث الاتصال لاحقاً يفعّل المالك', () {
      final ids = HealthIdentityManager.instance;
      ids.resetForTesting();
      GlobalAdminManager.instance.resetForTesting();
      final created = ids.createIdentity(profileId: 'p-owner');
      expect(
        GlobalAdminManager.instance.roleOf(created.lifexId),
        GlobalAdminRole.none,
      );
      ids.updateContactAndReactivateOwner(
        lifexId: created.lifexId,
        email: AppConstants.ownerEmail,
      );
      expect(
        GlobalAdminManager.instance.roleOf(created.lifexId),
        GlobalAdminRole.owner,
      );
    });
  });
}
