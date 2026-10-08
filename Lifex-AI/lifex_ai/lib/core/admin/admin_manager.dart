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

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../app_constants.dart';
import '../error_handler.dart';
import 'admin_permissions.dart';

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

  static const _rolesStorageKey = 'lifex_global_admin_roles_v1';
  static const _eventTogglesStorageKey = 'lifex_global_admin_event_toggles_v1';
  SharedPreferences? _preferences;
  Future<void> _pendingPersistence = Future<void>.value();

  /// دور كل مستخدم، مفهرَس بمعرّف الهوية الصحية (Lifex-ID) وليس رقم
  /// الهاتف أو البريد مباشرة، اتساقاً مع بقية النظام الذي يعتمد Lifex-ID
  /// كمعرّف موحّد في التراسل والتبرعات.
  final Map<String, GlobalAdminRole> _rolesByLifexId = {};

  /// تحميل سجل الأدوار من التخزين المحلي قبل إعادة ربط الملفات الصحية.
  Future<void> initialize(SharedPreferences preferences) async {
    _preferences = preferences;
    _pendingPersistence = Future<void>.value();
    _rolesByLifexId.clear();

    final rawRoles = preferences.getString(_rolesStorageKey);
    if (rawRoles != null && rawRoles.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawRoles);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.key is! String || entry.value is! String) continue;
            final role = GlobalAdminRole.values.where(
              (candidate) => candidate.name == entry.value,
            );
            if (role.isNotEmpty && role.first != GlobalAdminRole.none) {
              _rolesByLifexId[entry.key as String] = role.first;
            }
          }
        }
      } on FormatException catch (error) {
        ErrorHandler.instance.report(
          'ADMIN_ROLE_STORAGE_INVALID',
          'تعذّرت قراءة سجل الأدوار المحفوظ: $error',
          sourceModule: 'admin_manager',
          severity: ErrorSeverity.warning,
        );
      }
    }

    final rawToggles = preferences.getString(_eventTogglesStorageKey);
    if (rawToggles != null && rawToggles.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawToggles);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.key is String &&
                entry.value is bool &&
                _systemEventToggles.containsKey(entry.key)) {
              _systemEventToggles[entry.key as String] = entry.value as bool;
            }
          }
        }
      } on FormatException catch (error) {
        ErrorHandler.instance.report(
          'ADMIN_TOGGLE_STORAGE_INVALID',
          'تعذّرت قراءة إعدادات مفاتيح الأحداث: $error',
          sourceModule: 'admin_manager',
          severity: ErrorSeverity.warning,
        );
      }
    }
  }

  Future<void> flushPersistence() => _pendingPersistence;

  void _persistRoles() {
    final preferences = _preferences;
    if (preferences == null) return;
    final snapshot = jsonEncode({
      for (final entry in _rolesByLifexId.entries) entry.key: entry.value.name,
    });
    _pendingPersistence = _pendingPersistence.then((_) async {
      await preferences.setString(_rolesStorageKey, snapshot);
    }).catchError((Object error) {
      ErrorHandler.instance.report(
        'ADMIN_ROLE_STORAGE_FAILED',
        'تعذّر حفظ سجل الأدوار: $error',
        sourceModule: 'admin_manager',
        severity: ErrorSeverity.warning,
      );
    });
  }

  void _persistEventToggles() {
    final preferences = _preferences;
    if (preferences == null) return;
    final snapshot = jsonEncode(_systemEventToggles);
    _pendingPersistence = _pendingPersistence.then((_) async {
      await preferences.setString(_eventTogglesStorageKey, snapshot);
    }).catchError((Object error) {
      ErrorHandler.instance.report(
        'ADMIN_TOGGLE_STORAGE_FAILED',
        'تعذّر حفظ إعدادات مفاتيح الأحداث: $error',
        sourceModule: 'admin_manager',
        severity: ErrorSeverity.warning,
      );
    });
  }

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

  bool hasFullSystemAccess(String lifexId) {
    final role = roleOf(lifexId);
    return role == GlobalAdminRole.owner || role == GlobalAdminRole.admin;
  }

  String _normalizeOwnerPhone(String value) {
    final westernDigits = value.replaceAllMapped(
      RegExp(r'[٠-٩۰-۹]'),
      (match) {
        final code = match[0]!.codeUnitAt(0);
        final zero = code >= 0x06f0 ? 0x06f0 : 0x0660;
        return String.fromCharCode(0x30 + code - zero);
      },
    );
    var digits = westernDigits.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('00')) digits = digits.substring(2);
    if (digits.startsWith('963')) return digits;
    if (digits.startsWith('0')) return '963${digits.substring(1)}';
    if (digits.startsWith('9')) return '963$digits';
    return digits;
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
    final isOwnerEmail = email != null &&
        AppConstants.ownerEmails
            .map((e) => e.trim().toLowerCase())
            .contains(email.trim().toLowerCase());
    final isOwnerPhone = phoneNumber != null &&
        _normalizeOwnerPhone(phoneNumber) ==
            _normalizeOwnerPhone(AppConstants.ownerPhoneNumber);

    if (isOwnerEmail || isOwnerPhone) {
      _rolesByLifexId[lifexId] = GlobalAdminRole.owner;
      _persistRoles();
    }
    return roleOf(lifexId);
  }

  /// منح دور لمستخدم آخر. يتحقق أن صاحب الطلب (granterLifexId) يملك
  /// الصلاحية المناسبة للدور المطلوب منحه، وفق قاعدة صارمة:
  /// - دور admin: للمالك أو الأدمن المفوض.
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
    _persistRoles();
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
    _persistRoles();
    return AdminRoleActionResult.ok('تم سحب الدور بنجاح.');
  }

  // ---------------------------------------------------------------
  // مفاتيح الأحداث الدقيقة (Granular system event toggles)
  // ---------------------------------------------------------------

  bool isEventEnabled(String eventKey) =>
      _systemEventToggles[eventKey] ?? false;

  Map<String, bool> get allEventToggles =>
      Map.unmodifiable(_systemEventToggles);

  AdminRoleActionResult setEventToggle({
    required String actorLifexId,
    required String eventKey,
    required bool enabled,
  }) {
    if (!hasPermission(
        actorLifexId, GlobalAdminPermission.manageSystemEventToggles)) {
      return AdminRoleActionResult.rejected(
        'لا تملك صلاحية التحكم بمفاتيح الأحداث الدقيقة.',
      );
    }
    if (!_systemEventToggles.containsKey(eventKey)) {
      return AdminRoleActionResult.rejected(
          'مفتاح الحدث "$eventKey" غير معروف.');
    }

    _systemEventToggles[eventKey] = enabled;
    _persistEventToggles();
    return AdminRoleActionResult.ok(
      'تم ${enabled ? "تفعيل" : "تعطيل"} "$eventKey" بنجاح.',
    );
  }

  /// إعادة كل شيء لحالته الأولية — للاختبارات فقط.
  void resetForTesting() {
    _preferences = null;
    _pendingPersistence = Future<void>.value();
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
