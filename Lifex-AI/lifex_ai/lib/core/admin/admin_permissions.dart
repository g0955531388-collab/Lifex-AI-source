/// =============================================================
/// Lifex-AI — النواة الأساسية للنظام
/// الملف: admin_permissions.dart
/// المسار: lib/core/admin/admin_permissions.dart
/// الوصف: تعريف أدوار وصلاحيات "حساب الأدمن" على مستوى المنظومة كاملة
/// (وليس داخل وحدة واحدة كالمستشفى — قارن مع
/// features/hospital/hospital_roles_permissions.dart الذي يبقى مسؤولاً
/// حصراً عن أدوار الطاقم داخل وحدة المستشفى فقط). هذا الملف هو مصدر
/// الحقيقة الوحيد لأدوار الإدارة العالمية؛ يمنع تكرار هذا المفهوم تحت
/// اسم مختلف في أي وحدة أخرى.
/// =============================================================
library lifex_ai.core.admin.admin_permissions;

/// المستويات الإدارية العالمية، من الأعلى صلاحية إلى المستخدم العادي.
enum GlobalAdminRole {
  /// مالك النظام (System Owner) — تفويض إداري تشغيلي عبر Bootstrap آمن.
  /// هذا الدور ليس إسناد ملكية فكرية للمشروع؛ الإسناد الرسمي في
  /// ProjectAttribution فقط: المالك والمخترع غازي سليم بكفلاوي.
  owner,

  /// أدمن كامل الصلاحيات باستثناء منح دور "أدمن" لغيره (حصراً للمالك).
  admin,

  /// مشرف بصلاحيات محدودة (إشراف على المحتوى/التراسل دون التحكم المالي
  /// أو صلاحيات النظام الحساسة).
  moderator,

  /// مستخدم عادي — لا يملك أي صلاحية إدارية.
  none,
}

/// الصلاحيات الدقيقة القابلة للمنح على مستوى المنظومة كاملة.
enum GlobalAdminPermission {
  /// منح أو سحب دور "مشرف" (moderator) من مستخدم آخر.
  grantModeratorRole,

  /// منح أو سحب دور "أدمن" (admin) من مستخدم آخر — للمالك فقط.
  grantAdminRole,

  /// التحكم بمفاتيح الأحداث الدقيقة على مستوى النظام (تفعيل/تعطيل ميزة
  /// بعينها لكل المستخدمين، مثل تنبيهات شبكة الدم أو الوضع الصامت للطوارئ).
  manageSystemEventToggles,

  /// إدارة حسابات المستخدمين (تعليق، استعادة، حذف بيانات بطلب رسمي).
  manageUsers,

  /// الإشراف على المحتوى والتراسل داخل المنصة (بلاغات، حظر رسائل مسيئة).
  moderateContent,

  /// الاطلاع على لوحة الإحصاء الشاملة للقطاع الصحي (القسم 14 من الوثيقة
  /// الرئيسية) دون الوصول لملفات المرضى الفردية.
  viewSectorStatistics,

  /// إدارة الفوترة والمحفظة المالية على مستوى المنصة (وليس محفظة فرد
  /// بعينه) — رسوم، إعفاءات، مراجعة معاملات التبرع.
  manageBilling,

  /// التحكم بإعدادات نظام الطوارئ على مستوى المنصة (لا تشمل تفعيل/إلغاء
  /// طوارئ فرد بعينه، بل السياسات العامة كعدد الأرقام الموثوقة الافتراضي).
  manageEmergencyPolicy,
}

/// خريطة الصلاحيات الافتراضية لكل دور — صريحة وثابتة (Role-Based Access
/// Control)، بنفس أسلوب _defaultRolePermissions في
/// hospital_roles_permissions.dart حفاظاً على اتساق النمط عبر المشروع.
const Map<GlobalAdminRole, Set<GlobalAdminPermission>>
    defaultGlobalRolePermissions = {
  GlobalAdminRole.owner: {
    GlobalAdminPermission.grantModeratorRole,
    GlobalAdminPermission.grantAdminRole,
    GlobalAdminPermission.manageSystemEventToggles,
    GlobalAdminPermission.manageUsers,
    GlobalAdminPermission.moderateContent,
    GlobalAdminPermission.viewSectorStatistics,
    GlobalAdminPermission.manageBilling,
    GlobalAdminPermission.manageEmergencyPolicy,
  },
  GlobalAdminRole.admin: {
    GlobalAdminPermission.grantModeratorRole,
    GlobalAdminPermission.manageSystemEventToggles,
    GlobalAdminPermission.manageUsers,
    GlobalAdminPermission.moderateContent,
    GlobalAdminPermission.viewSectorStatistics,
    GlobalAdminPermission.manageBilling,
    GlobalAdminPermission.manageEmergencyPolicy,
  },
  GlobalAdminRole.moderator: {
    GlobalAdminPermission.moderateContent,
  },
  GlobalAdminRole.none: {},
};
