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
  /// ProjectAttribution: الملكية والشراكة مناصفة بين غازي سليم بكفلاوي ورباب الحايك.
  owner,

  /// أدمن النظام — يملك صلاحيات التشغيل ويستطيع تفويض أدمنين ومشرفين.
  admin,

  /// مشرف بصلاحيات محدودة (إشراف على المحتوى/التراسل دون التحكم المالي
  /// أو صلاحيات النظام الحساسة).
  moderator,

  /// موظف تشغيل. بلا منح أدوار وبلا فوترة وبلا ملفات مرضى.
  employee,

  /// مستخدم عادي — لا يملك أي صلاحية إدارية.
  none,
}

/// صفة التعيين. لا تمنح وصولاً صحياً.
enum StaffEngagement {
  paid,
  volunteer,
}

/// الصلاحيات الدقيقة القابلة للمنح على مستوى المنظومة كاملة.
enum GlobalAdminPermission {
  /// منح أو سحب دور "مشرف" (moderator) من مستخدم آخر.
  grantModeratorRole,

  /// منح أو سحب دور "أدمن" (admin) من مستخدم آخر — للمالك.
  grantAdminRole,

  /// منح أو سحب دور الموظف — للمالك.
  grantStaffRole,

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

  /// مفتاح مراقبة الكاميرا عن بُعد. للمالك فقط بعد مصادقة مستقلة.
  manageRemoteCameraMonitoring,
}

/// خريطة الصلاحيات الافتراضية لكل دور — صريحة وثابتة (Role-Based Access
/// Control)، بنفس أسلوب _defaultRolePermissions في
/// hospital_roles_permissions.dart حفاظاً على اتساق النمط عبر المشروع.
const Map<GlobalAdminRole, Set<GlobalAdminPermission>>
    defaultGlobalRolePermissions = {
  GlobalAdminRole.owner: {
    GlobalAdminPermission.grantModeratorRole,
    GlobalAdminPermission.grantAdminRole,
    GlobalAdminPermission.grantStaffRole,
    GlobalAdminPermission.manageSystemEventToggles,
    GlobalAdminPermission.manageUsers,
    GlobalAdminPermission.moderateContent,
    GlobalAdminPermission.viewSectorStatistics,
    GlobalAdminPermission.manageBilling,
    GlobalAdminPermission.manageEmergencyPolicy,
    GlobalAdminPermission.manageRemoteCameraMonitoring,
  },
  GlobalAdminRole.admin: {
    GlobalAdminPermission.grantModeratorRole,
    GlobalAdminPermission.manageSystemEventToggles,
    GlobalAdminPermission.manageUsers,
    GlobalAdminPermission.moderateContent,
    GlobalAdminPermission.viewSectorStatistics,
  },
  GlobalAdminRole.moderator: {
    GlobalAdminPermission.moderateContent,
  },
  GlobalAdminRole.employee: {
    GlobalAdminPermission.moderateContent,
    GlobalAdminPermission.viewSectorStatistics,
  },
  GlobalAdminRole.none: {},
};
