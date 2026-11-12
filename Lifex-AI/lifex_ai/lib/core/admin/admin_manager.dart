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

  static const rolesStorageKey = 'lifex_global_admin_roles_v1';
  static const ownerQuarantineStorageKey =
      'lifex_global_admin_owner_quarantine_v1';
  static const ownerQuarantineReason = 'no-independent-authenticator';
  static const remoteCameraEventKey =
      'remote_health_camera_monitoring_enabled';
  static const _eventTogglesStorageKey = 'lifex_global_admin_event_toggles_v1';
  static const engagementStorageKey = 'lifex_global_admin_engagement_v1';
  SharedPreferences? _preferences;
  Future<void> _pendingPersistence = Future<void>.value();
  final List<String> _quarantinedOwnerIds = [];

  /// يربطه الإقلاع بهوية Lifex. الغياب يعني رفض المنح، لا منحاً مفتوحاً.
  bool Function(String actorId)? _actorIsOperationalLifexId;

  List<String> get quarantinedOwnerIds =>
      List.unmodifiable(_quarantinedOwnerIds);

  void bindActorLookup(bool Function(String actorId) lookup) {
    _actorIsOperationalLifexId = lookup;
  }

  /// دور كل مستخدم، مفهرَس بمعرّف الهوية الصحية (Lifex-ID) وليس رقم
  /// الهاتف أو البريد مباشرة، اتساقاً مع بقية النظام الذي يعتمد Lifex-ID
  /// كمعرّف موحّد في التراسل والتبرعات.
  final Map<String, GlobalAdminRole> _rolesByLifexId = {};
  final Map<String, StaffEngagement> _engagementByLifexId = {};

  /// تحميل سجل الأدوار من التخزين المحلي قبل إعادة ربط الملفات الصحية.
  Future<void> initialize(SharedPreferences preferences) async {
    _preferences = preferences;
    _pendingPersistence = Future<void>.value();
    _rolesByLifexId.clear();
    _engagementByLifexId.clear();
    _quarantinedOwnerIds
      ..clear()
      ..addAll(_readQuarantine(preferences));

    final rawRoles = preferences.getString(rolesStorageKey);
    if (rawRoles != null && rawRoles.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawRoles);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.key is! String || entry.value is! String) continue;
            final role = GlobalAdminRole.values.where(
              (candidate) => candidate.name == entry.value,
            );
            if (role.isEmpty || role.first == GlobalAdminRole.none) continue;
            final lifexId = entry.key as String;
            if (role.first == GlobalAdminRole.owner) {
              if (!_quarantinedOwnerIds.contains(lifexId)) {
                _quarantinedOwnerIds.add(lifexId);
              }
              continue;
            }
            _rolesByLifexId[lifexId] = role.first;
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

    final rawEngagement = preferences.getString(engagementStorageKey);
    if (rawEngagement != null && rawEngagement.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawEngagement);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.key is! String || entry.value is! String) continue;
            final lifexId = entry.key as String;
            if (!_rolesByLifexId.containsKey(lifexId)) continue;
            final engagement = StaffEngagement.values.where(
              (candidate) => candidate.name == entry.value,
            );
            if (engagement.isEmpty) continue;
            _engagementByLifexId[lifexId] = engagement.first;
          }
        }
      } on FormatException catch (error) {
        ErrorHandler.instance.report(
          'ADMIN_ENGAGEMENT_STORAGE_INVALID',
          'تعذّرت قراءة صفة التعيين: $error',
          sourceModule: 'admin_manager',
          severity: ErrorSeverity.warning,
        );
      }
    }

    if (_quarantinedOwnerIds.isNotEmpty) {
      _persistQuarantine();
      _persistRoles();
    }
  }

  List<String> _readQuarantine(SharedPreferences preferences) {
    final raw = preferences.getString(ownerQuarantineStorageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      final ids = decoded is Map ? decoded['lifexIds'] : null;
      if (ids is! List) return const [];
      return ids.map((item) => item.toString()).where((id) => id.isNotEmpty).toList();
    } on FormatException {
      return const [];
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
      await preferences.setString(rolesStorageKey, snapshot);
    }).catchError((Object error) {
      ErrorHandler.instance.report(
        'ADMIN_ROLE_STORAGE_FAILED',
        'تعذّر حفظ سجل الأدوار: $error',
        sourceModule: 'admin_manager',
        severity: ErrorSeverity.warning,
      );
    });
  }

  void _persistQuarantine() {
    final preferences = _preferences;
    if (preferences == null) return;
    final snapshot = jsonEncode({
      'reason': ownerQuarantineReason,
      'lifexIds': _quarantinedOwnerIds,
    });
    _pendingPersistence = _pendingPersistence.then((_) async {
      await preferences.setString(ownerQuarantineStorageKey, snapshot);
    }).catchError((Object error) {
      ErrorHandler.instance.report(
        'ADMIN_OWNER_QUARANTINE_FAILED',
        'تعذّر حفظ سجل تعليق دور المالك: $error',
        sourceModule: 'admin_manager',
        severity: ErrorSeverity.warning,
      );
    });
  }

  void _persistEngagement() {
    final preferences = _preferences;
    if (preferences == null) return;
    final snapshot = jsonEncode({
      for (final entry in _engagementByLifexId.entries)
        entry.key: entry.value.name,
    });
    _pendingPersistence = _pendingPersistence.then((_) async {
      await preferences.setString(engagementStorageKey, snapshot);
    }).catchError((Object error) {
      ErrorHandler.instance.report(
        'ADMIN_ENGAGEMENT_STORAGE_FAILED',
        'تعذّر حفظ صفة التعيين: $error',
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

  /// كل صلاحيات الدور الحالي — للمالك = مجموعة كاملة من الخريطة.
  Set<GlobalAdminPermission> permissionsOf(String lifexId) {
    final role = roleOf(lifexId);
    return Set.unmodifiable(
      defaultGlobalRolePermissions[role] ?? const <GlobalAdminPermission>{},
    );
  }

  bool get hasFullOperationalControlAsOwner =>
      _rolesByLifexId.containsValue(GlobalAdminRole.owner);

  StaffEngagement? engagementOf(String lifexId) => _engagementByLifexId[lifexId];

  bool isOwner(String lifexId) => roleOf(lifexId) == GlobalAdminRole.owner;

  bool hasFullSystemAccess(String lifexId) {
    final role = roleOf(lifexId);
    return role == GlobalAdminRole.owner || role == GlobalAdminRole.admin;
  }

  /// قائمة العاملين الإداريين المحليين (مالك/أدمن/مشرف).
  Map<String, GlobalAdminRole> listStaffRoles() {
    return Map.unmodifiable(
      Map.fromEntries(
        _rolesByLifexId.entries.where((e) => e.value != GlobalAdminRole.none),
      ),
    );
  }

  /// لا يمنح owner من نص يمرَّر مباشرة. التفعيل يمر عبر الهوية المربوطة.
  GlobalAdminRole autoActivateOwnerIfMatches({
    required String lifexId,
    String? email,
    String? phoneNumber,
  }) {
    return roleOf(lifexId);
  }

  /// يفتح دور المالك لهوية تشغيلية مربوطة إذا طابق بريدها أو هاتفها
  /// الوسيلة المعتمدة تطابقاً كاملاً. ذيل الرقم والاسم لا يكفيان.
  /// إن زال التطابق يُسحب الدور. سجل المالك على القرص وحده يبقى معلّقاً
  /// حتى تعيد هذه الدالة إثباته.
  GlobalAdminRole activateOwnerForBoundIdentity({
    required String lifexId,
    required String linkedProfileId,
    String? email,
    String? phoneNumber,
  }) {
    final lookup = _actorIsOperationalLifexId;
    if (lookup == null || !lookup(lifexId)) return roleOf(lifexId);
    if (lifexId.trim().isEmpty || lifexId == linkedProfileId) {
      return roleOf(lifexId);
    }
    const policy = OwnerIdentityPolicy();
    final matched = policy.matchesOwnerEmail(email) ||
        policy.matchesOwnerPhone(phoneNumber);
    if (!matched) {
      if (_rolesByLifexId[lifexId] == GlobalAdminRole.owner) {
        _rolesByLifexId.remove(lifexId);
        _engagementByLifexId.remove(lifexId);
        _persistRoles();
        _persistEngagement();
      }
      return roleOf(lifexId);
    }
    _rolesByLifexId[lifexId] = GlobalAdminRole.owner;
    _engagementByLifexId.remove(lifexId);
    _quarantinedOwnerIds.remove(lifexId);
    _persistRoles();
    _persistEngagement();
    _persistQuarantine();
    return GlobalAdminRole.owner;
  }

  String? _rejectUnboundActor(String actorId) {
    final lookup = _actorIsOperationalLifexId;
    if (lookup == null || !lookup(actorId)) {
      return 'العملية مغلقة: المعرّف ليس Lifex-ID مربوطاً بهوية، '
          'أو أنه معرّف ملف.';
    }
    return null;
  }

  /// منح دور لمستخدم آخر. يتحقق أن صاحب الطلب (granterLifexId) يملك
  /// الصلاحية المناسبة للدور المطلوب منحه، وفق قاعدة صارمة:
  /// - دور admin: لمن يملك grantAdminRole، والمالك فقط في هذه الخريطة.
  /// - دور moderator: للمالك أو الأدمن.
  /// - دور owner لا يُمنح من هنا ولا من تطابق نص.
  AdminRoleActionResult grantRole({
    required String granterLifexId,
    required String targetLifexId,
    required GlobalAdminRole role,
    StaffEngagement engagement = StaffEngagement.volunteer,
  }) {
    final unbound = _rejectUnboundActor(granterLifexId);
    if (unbound != null) {
      return AdminRoleActionResult.rejected(unbound);
    }
    if (role == GlobalAdminRole.owner || role == GlobalAdminRole.none) {
      return AdminRoleActionResult.rejected(
        'دور المالك لا يُمنح يدوياً. يُفتح فقط بتطابق وسيلة الاتصال على الهوية المربوطة.',
      );
    }
    if (targetLifexId.trim().isEmpty || targetLifexId == granterLifexId) {
      return AdminRoleActionResult.rejected(
        'عيّن معرّف Lifex لشخص آخر، لا لحسابك.',
      );
    }

    final requiredPermission = switch (role) {
      GlobalAdminRole.admin => GlobalAdminPermission.grantAdminRole,
      GlobalAdminRole.employee => GlobalAdminPermission.grantStaffRole,
      GlobalAdminRole.moderator => GlobalAdminPermission.grantModeratorRole,
      GlobalAdminRole.owner || GlobalAdminRole.none =>
        GlobalAdminPermission.grantAdminRole,
    };

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
    _engagementByLifexId[targetLifexId] = engagement;
    _persistRoles();
    _persistEngagement();
    final engagementAr =
        engagement == StaffEngagement.paid ? 'مأجور' : 'متطوع';
    return AdminRoleActionResult.ok(
      'تم التعيين: ${_roleNameAr(role)}، $engagementAr.',
    );
  }

  String _roleNameAr(GlobalAdminRole role) {
    return switch (role) {
      GlobalAdminRole.owner => 'مالك',
      GlobalAdminRole.admin => 'مدير',
      GlobalAdminRole.employee => 'موظف',
      GlobalAdminRole.moderator => 'مشرف',
      GlobalAdminRole.none => 'مستخدم',
    };
  }

  /// سحب أي دور إداري عن مستخدم (إعادته إلى none) — تخضع لنفس قاعدة
  /// الصلاحيات في [grantRole]، مع استثناء: لا يمكن لأي طرف سحب دور
  /// المالك عن نفسه أو عن غيره.
  AdminRoleActionResult revokeRole({
    required String granterLifexId,
    required String targetLifexId,
  }) {
    final unbound = _rejectUnboundActor(granterLifexId);
    if (unbound != null) {
      return AdminRoleActionResult.rejected(unbound);
    }
    final currentRole = roleOf(targetLifexId);
    if (currentRole == GlobalAdminRole.owner) {
      return AdminRoleActionResult.rejected('لا يمكن سحب دور المالك.');
    }
    if (currentRole == GlobalAdminRole.none) {
      return AdminRoleActionResult.ok('المستخدم لا يملك أي دور أصلاً.');
    }

    final requiredPermission = switch (currentRole) {
      GlobalAdminRole.admin => GlobalAdminPermission.grantAdminRole,
      GlobalAdminRole.employee => GlobalAdminPermission.grantStaffRole,
      GlobalAdminRole.moderator => GlobalAdminPermission.grantModeratorRole,
      GlobalAdminRole.owner || GlobalAdminRole.none =>
        GlobalAdminPermission.grantAdminRole,
    };

    if (!hasPermission(granterLifexId, requiredPermission)) {
      return AdminRoleActionResult.rejected(
        'لا تملك الصلاحية اللازمة لسحب دور ${currentRole.name}.',
      );
    }

    _rolesByLifexId.remove(targetLifexId);
    _engagementByLifexId.remove(targetLifexId);
    _persistRoles();
    _persistEngagement();
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
    final unbound = _rejectUnboundActor(actorLifexId);
    if (unbound != null) {
      return AdminRoleActionResult.rejected(unbound);
    }
    if (eventKey == remoteCameraEventKey &&
        !hasPermission(
          actorLifexId,
          GlobalAdminPermission.manageRemoteCameraMonitoring,
        )) {
      return AdminRoleActionResult.rejected(
        'مفتاح مراقبة الكاميرا عن بُعد ليس من صلاحيات هذا الدور.',
      );
    }
    if (!hasPermission(actorLifexId, GlobalAdminPermission.manageSystemEventToggles)) {
      return AdminRoleActionResult.rejected(
        'لا تملك صلاحية التحكم بمفاتيح الأحداث الدقيقة.',
      );
    }
    if (!_systemEventToggles.containsKey(eventKey)) {
      return AdminRoleActionResult.rejected('مفتاح الحدث "$eventKey" غير معروف.');
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
    _engagementByLifexId.clear();
    _quarantinedOwnerIds.clear();
    _actorIsOperationalLifexId = null;
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
