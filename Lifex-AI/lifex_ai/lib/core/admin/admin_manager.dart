/// =============================================================
/// Lifex-AI — النواة الأساسية للنظام
/// الملف: admin_manager.dart
/// المسار: lib/core/admin/admin_manager.dart
/// الوصف: المدير الوحيد لأدوار الإدارة العالمية (GlobalAdminRole) ومنح/سحب
/// الصلاحيات، ولمفاتيح الأحداث الدقيقة على مستوى النظام. لا يتعامل هذا
/// الملف مع Android Device Admin (وهو مرفوض معمارياً في هذا المشروع لأنه
/// يمنع حذف التطبيق) — هذا حساب إداري داخل التطبيق فقط، مفهوم مختلف
/// تماماً رغم تشابه الاسم.
/// =============================================================
library lifex_ai.core.admin.admin_manager;

import '../error_handler.dart';
import 'admin_permissions.dart';
import 'owner_identity_policy.dart';

/// نتيجة أي عملية منح/سحب دور — يوضّح النجاح أو سبب الرفض بدل إرجاع
/// قيمة منطقية صامتة، بنفس أسلوب AddProfileResult في multi_profile_engine.
class AdminRoleActionResult {
  final bool success;
  final String messageAr;

  const AdminRoleActionResult._(this.success, this.messageAr);

  factory AdminRoleActionResult.ok(String messageAr) =>
      AdminRoleActionResult._(true, messageAr);

  factory AdminRoleActionResult.rejected(String messageAr) =>
      AdminRoleActionResult._(false, messageAr);
}

/// المدير المسؤول عن كل ما يخص حساب الأدمن على مستوى منظومة Lifex-AI
/// كاملة: من يملك أي دور، من يحق له منح دور لغيره، وحالة مفاتيح الأحداث
/// الدقيقة (Feature toggles) التي يتحكم بها الأدمن دون الحاجة لتحديث
/// التطبيق.
class GlobalAdminManager {
  GlobalAdminManager._internal();
  static final GlobalAdminManager instance = GlobalAdminManager._internal();

  /// دور كل مستخدم، مفهرَس بمعرّف الهوية الصحية (Lifex-ID) وليس رقم
  /// الهاتف أو البريد مباشرة، اتساقاً مع بقية النظام الذي يعتمد Lifex-ID
  /// كمعرّف موحّد في التراسل والتبرعات.
  final Map<String, GlobalAdminRole> _rolesByLifexId = {};

  /// مفاتيح الأحداث الدقيقة القابلة للتحكم من لوحة الأدمن — القيم
  /// الافتراضية هنا هي الحالة الآمنة عند أول تشغيل للنظام.
  final Map<String, bool> _systemEventToggles = {
    'blood_network_flash_alerts_enabled': true,
    'emergency_silent_light_mode_enabled': true,
    'ai_gateway_enabled': true,
    'remote_health_camera_monitoring_enabled': true,
  };

  GlobalAdminRole roleOf(String lifexId) =>
      _rolesByLifexId[lifexId] ?? GlobalAdminRole.none;

  bool hasPermission(String lifexId, GlobalAdminPermission permission) {
    final role = roleOf(lifexId);
    return defaultGlobalRolePermissions[role]?.contains(permission) ?? false;
  }

  /// كل صلاحيات الدور الحالي — للمالك = مجموعة كاملة من الخريطة.
  Set<GlobalAdminPermission> permissionsOf(String lifexId) {
    final role = roleOf(lifexId);
    return Set.unmodifiable(
      defaultGlobalRolePermissions[role] ?? const <GlobalAdminPermission>{},
    );
  }

  bool get hasFullOperationalControlAsOwner => true;

  bool isOwner(String lifexId) => roleOf(lifexId) == GlobalAdminRole.owner;

  /// قائمة العاملين الإداريين المحليين (مالك/أدمن/مشرف).
  Map<String, GlobalAdminRole> listStaffRoles() {
    return Map.unmodifiable(
      Map.fromEntries(
        _rolesByLifexId.entries.where((e) => e.value != GlobalAdminRole.none),
      ),
    );
  }

  /// يُستدعى مرة عند كل تسجيل دخول/إنشاء هوية — إن تطابق البريد أو
  /// الهاتف تماماً مع بيانات المالك الثابتة في AppConstants، يُفعَّل دور
  /// المالك تلقائياً دون أي تدخل بشري. لا يوجد أي مسار آخر للحصول على
  /// دور owner.
  GlobalAdminRole autoActivateOwnerIfMatches({
    required String lifexId,
    String? email,
    String? phoneNumber,
  }) {
    const policy = OwnerIdentityPolicy();
    if (policy.isInventorOwnerContact(
      email: email,
      phoneNumber: phoneNumber,
    )) {
      _rolesByLifexId[lifexId] = GlobalAdminRole.owner;
    }
    return roleOf(lifexId);
  }

  /// منح دور لمستخدم آخر. يتحقق أن صاحب الطلب (granterLifexId) يملك
  /// الصلاحية المناسبة للدور المطلوب منحه، وفق قاعدة صارمة:
  /// - دور admin: للمالك (owner) فقط.
  /// - دور moderator: للمالك أو أي أدمن.
  /// - لا يجوز لأي دور منح دور owner على الإطلاق (يُفعَّل تلقائياً فقط).
  AdminRoleActionResult grantRole({
    required String granterLifexId,
    required String targetLifexId,
    required GlobalAdminRole role,
  }) {
    if (role == GlobalAdminRole.owner) {
      return AdminRoleActionResult.rejected(
        'دور المالك يُفعَّل تلقائياً فقط عبر بريد/هاتف المالك المسجَّلين '
        'مسبقاً، ولا يمكن منحه يدوياً.',
      );
    }

    final requiredPermission = role == GlobalAdminRole.admin
        ? GlobalAdminPermission.grantAdminRole
        : GlobalAdminPermission.grantModeratorRole;

    if (!hasPermission(granterLifexId, requiredPermission)) {
      ErrorHandler.instance.report(
        'ADMIN_GRANT_DENIED',
        'محاولة منح دور ${role.name} من مستخدم ($granterLifexId) لا يملك '
        'الصلاحية اللازمة.',
        sourceModule: 'admin_manager',
        severity: ErrorSeverity.warning,
      );
      return AdminRoleActionResult.rejected(
        'لا تملك الصلاحية اللازمة لمنح دور ${role.name}.',
      );
    }

    _rolesByLifexId[targetLifexId] = role;
    return AdminRoleActionResult.ok('تم منح دور ${role.name} بنجاح.');
  }

  /// سحب أي دور إداري عن مستخدم (إعادته إلى none) — تخضع لنفس قاعدة
  /// الصلاحيات في [grantRole]، مع استثناء: لا يمكن لأي طرف سحب دور
  /// المالك عن نفسه أو عن غيره.
  AdminRoleActionResult revokeRole({
    required String granterLifexId,
    required String targetLifexId,
  }) {
    final currentRole = roleOf(targetLifexId);
    if (currentRole == GlobalAdminRole.owner) {
      return AdminRoleActionResult.rejected('لا يمكن سحب دور المالك.');
    }
    if (currentRole == GlobalAdminRole.none) {
      return AdminRoleActionResult.ok('المستخدم لا يملك أي دور أصلاً.');
    }

    final requiredPermission = currentRole == GlobalAdminRole.admin
        ? GlobalAdminPermission.grantAdminRole
        : GlobalAdminPermission.grantModeratorRole;

    if (!hasPermission(granterLifexId, requiredPermission)) {
      return AdminRoleActionResult.rejected(
        'لا تملك الصلاحية اللازمة لسحب دور ${currentRole.name}.',
      );
    }

    _rolesByLifexId[targetLifexId] = GlobalAdminRole.none;
    return AdminRoleActionResult.ok('تم سحب الدور بنجاح.');
  }

  // ---------------------------------------------------------------
  // مفاتيح الأحداث الدقيقة (Granular system event toggles)
  // ---------------------------------------------------------------

  bool isEventEnabled(String eventKey) => _systemEventToggles[eventKey] ?? false;

  Map<String, bool> get allEventToggles => Map.unmodifiable(_systemEventToggles);

  AdminRoleActionResult setEventToggle({
    required String actorLifexId,
    required String eventKey,
    required bool enabled,
  }) {
    if (!hasPermission(actorLifexId, GlobalAdminPermission.manageSystemEventToggles)) {
      return AdminRoleActionResult.rejected(
        'لا تملك صلاحية التحكم بمفاتيح الأحداث الدقيقة.',
      );
    }
    if (!_systemEventToggles.containsKey(eventKey)) {
      return AdminRoleActionResult.rejected('مفتاح الحدث "$eventKey" غير معروف.');
    }

    _systemEventToggles[eventKey] = enabled;
    return AdminRoleActionResult.ok(
      'تم ${enabled ? "تفعيل" : "تعطيل"} "$eventKey" بنجاح.',
    );
  }

  /// إعادة كل شيء لحالته الأولية — للاختبارات فقط.
  void resetForTesting() {
    _rolesByLifexId.clear();
    _systemEventToggles
      ..clear()
      ..addAll({
        'blood_network_flash_alerts_enabled': true,
        'emergency_silent_light_mode_enabled': true,
        'ai_gateway_enabled': true,
        'remote_health_camera_monitoring_enabled': true,
      });
  }
}
