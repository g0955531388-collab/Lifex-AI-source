/// =============================================================
/// Lifex-AI — الهوية الصحية والملفات الشخصية
/// الملف: active_profile_controller.dart
/// المسار: lib/features/profile/active_profile_controller.dart
/// الوصف: يسدّ الفجوة بين MultiProfileEngine (منطق بيانات بلا حالة
/// تفاعلية) والواجهة (تحتاج إعادة بناء تلقائية عند تغيّر الملف النشط).
/// بدونه، كانت كل شاشة تعمل بمعرّف ملف وهمي ثابت بدلاً من الملف الصحي
/// الحقيقي — وهذا الملف يحل الفجوة عبر ChangeNotifier موفَّر مركزياً
/// بـ Provider، بحيث تقرأ كل شاشة الملف النشط الحقيقي دائماً.
/// =============================================================

import 'package:flutter/foundation.dart';

import 'health_identity_manager.dart';
import 'health_profile.dart';
import 'multi_profile_engine.dart';
import 'profile_privacy_manager.dart';
import 'profile_vault.dart';

/// متحكم تفاعلي فوق MultiProfileEngine — يُعلم الواجهة تلقائياً عند أي
/// تغيّر في الملف النشط (إنشاء أول ملف، تبديل بين أفراد العائلة).
class ActiveProfileController extends ChangeNotifier {
  ActiveProfileController({required this.engine, this.vault});

  final MultiProfileEngine engine;
  final ProfileVault? vault;

  Future<void> _persist() async {
    await vault?.save(engine);
  }

  /// معرّف الملف الصحي النشط حالياً، أو null إن لم يُنشأ أي ملف بعد
  /// (حالة "أول تشغيل" قبل إكمال شاشة الإعداد الأولي).
  String? get activeProfileId => engine.activeProfileId;

  HealthProfile? get activeProfile => engine.activeProfile;

  bool get hasAnyProfile => engine.activeProfileId != null;

  /// الروابط العائلية المسجَّلة (للقراءة من شاشة إدارة العائلة).
  List<FamilyProfileLink> get familyLinks => engine.links;

  int get remainingFamilySlots => engine.remainingSlots;

  HealthProfile? profileById(String profileId) =>
      engine.getProfileById(profileId);

  List<HealthProfile> get allProfiles => engine.allProfiles;

  /// إنشاء أول ملف صحي للمستخدم (يُستدعى من شاشة الإعداد الأولي) —
  /// يسجّله في MultiProfileEngine كصاحب الحساب الرئيسي، ويصبح نشطاً
  /// تلقائياً، ثم يُعلم كل الواجهة المستمعة بالتغيير.
  AddProfileResult createInitialProfile(
    HealthProfile profile, {
    String? email,
    String? phoneNumber,
  }) {
    final result = engine.addProfile(profile, role: ProfileRole.primaryOwner);
    if (result.success) {
      _bindLocalIdentity(
        profile,
        email: email,
        phoneNumber: phoneNumber,
      );
      if (email != null) {
        profile.questionnaireData['accountEmail'] = email;
      }
      if (phoneNumber != null) {
        profile.questionnaireData['accountPhone'] = phoneNumber;
      }
      notifyListeners();
      _persist();
    }
    return result;
  }

  /// إضافة فرد عائلة جديد (لا يصبح نشطاً تلقائياً إلا إذا كان أول ملف
  /// يُضاف للحساب بالكامل).
  AddProfileResult addFamilyMember(
    HealthProfile profile, {
    required ProfileRole role,
  }) {
    final result = engine.addProfile(profile, role: role);
    if (result.success) {
      _linkFamilyGraphs(profile);
      _bindLocalIdentity(profile);
      notifyListeners();
      _persist();
    }
    return result;
  }

  void _bindLocalIdentity(
    HealthProfile profile, {
    String? email,
    String? phoneNumber,
  }) {
    final storedEmail =
        email ?? profile.questionnaireData['accountEmail'] as String?;
    final storedPhone =
        phoneNumber ?? profile.questionnaireData['accountPhone'] as String?;
    final storedLifexId =
        profile.questionnaireData['accountLifexId'] as String?;
    final identity = HealthIdentityManager.instance.createIdentity(
      profileId: profile.profileId,
      email: storedEmail,
      phoneNumber: storedPhone,
      preferredLifexId: storedLifexId,
    );
    profile.questionnaireData['accountLifexId'] = identity.lifexId;
    if (storedEmail != null) {
      profile.questionnaireData['accountEmail'] = storedEmail;
    }
    if (storedPhone != null) {
      profile.questionnaireData['accountPhone'] = storedPhone;
    }
    ProfilePrivacyRegistry.instance.forProfile(profile.profileId);
  }

  void _linkFamilyGraphs(HealthProfile newMember) {
    final owners = engine.profilesByRole(ProfileRole.primaryOwner);
    if (owners.isEmpty) return;
    final owner = owners.first;
    if (!owner.linkedFamilyProfileIds.contains(newMember.profileId)) {
      owner.linkedFamilyProfileIds.add(newMember.profileId);
    }
    if (!newMember.linkedFamilyProfileIds.contains(owner.profileId)) {
      newMember.linkedFamilyProfileIds.add(owner.profileId);
    }
  }

  /// التبديل الفعلي بين أفراد العائلة من الواجهة — يُعلم كل الشاشات
  /// المفتوحة فوراً بالملف الجديد النشط.
  bool switchTo(String profileId) {
    final success = engine.switchActiveProfile(profileId);
    if (success) {
      notifyListeners();
      _persist();
    }
    return success;
  }

  void notifyProfileChanged() {
    notifyListeners();
    _persist();
  }

  /// تحديث وسيلة الاتصال للحساب النشط ثم إعادة فحص دور المالك مباشرة.
  /// المطابقة محلية في الوقت الحالي ولا تعني تحققاً عبر OTP.
  void updateAccountIdentity({String? email, String? phoneNumber}) {
    final profile = engine.activeProfile;
    if (profile == null) return;
    final storedEmail = email?.trim();
    final storedPhone = phoneNumber?.trim();
    if (storedEmail != null) {
      profile.questionnaireData['accountEmail'] = storedEmail;
    }
    if (storedPhone != null) {
      profile.questionnaireData['accountPhone'] = storedPhone;
    }
    _bindLocalIdentity(
      profile,
      email: storedEmail,
      phoneNumber: storedPhone,
    );
    notifyListeners();
    _persist();
  }

  /// يحفظ في الذاكرة وعلى الجهاز.
  void saveActiveProfileChanges() => notifyProfileChanged();

  Future<void> rebindIdentitiesAfterRestore() async {
    for (final profile in engine.allProfiles) {
      final email = profile.questionnaireData['accountEmail'] as String?;
      final phone = profile.questionnaireData['accountPhone'] as String?;
      _bindLocalIdentity(profile, email: email, phoneNumber: phone);
    }
    await _persist();
  }
}
