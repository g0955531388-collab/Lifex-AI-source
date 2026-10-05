/// =============================================================
/// Lifex-AI — أذونات الهاتف الداخلية
/// الملف: lifex_phone_permission.dart
/// المسار: lib/features/trusted_person/lifex_phone_permission.dart
/// الوصف: أذونات Lifex منفصلة عن Android runtime. Admin/Owner لا يمنحها.
/// =============================================================
library lifex_ai.features.trusted_person.lifex_phone_permission;

enum LifexPhonePermission {
  phoneContactsSelect,
  phoneContactsRead,
  phoneCallLogSelect,
  phoneCallLogRead,
  phoneSmsSelect,
  phoneSmsRead,
  lifexDirectorySearch,
  trustedPersonCreate,
  trustedPersonUpdate,
  trustedPersonRevoke,
  emergencyContactCreate,
  emergencyContactUpdate,
}

extension LifexPhonePermissionWire on LifexPhonePermission {
  String get wireName {
    switch (this) {
      case LifexPhonePermission.phoneContactsSelect:
        return 'PHONE_CONTACTS_SELECT';
      case LifexPhonePermission.phoneContactsRead:
        return 'PHONE_CONTACTS_READ';
      case LifexPhonePermission.phoneCallLogSelect:
        return 'PHONE_CALL_LOG_SELECT';
      case LifexPhonePermission.phoneCallLogRead:
        return 'PHONE_CALL_LOG_READ';
      case LifexPhonePermission.phoneSmsSelect:
        return 'PHONE_SMS_SELECT';
      case LifexPhonePermission.phoneSmsRead:
        return 'PHONE_SMS_READ';
      case LifexPhonePermission.lifexDirectorySearch:
        return 'LIFEX_DIRECTORY_SEARCH';
      case LifexPhonePermission.trustedPersonCreate:
        return 'TRUSTED_PERSON_CREATE';
      case LifexPhonePermission.trustedPersonUpdate:
        return 'TRUSTED_PERSON_UPDATE';
      case LifexPhonePermission.trustedPersonRevoke:
        return 'TRUSTED_PERSON_REVOKE';
      case LifexPhonePermission.emergencyContactCreate:
        return 'EMERGENCY_CONTACT_CREATE';
      case LifexPhonePermission.emergencyContactUpdate:
        return 'EMERGENCY_CONTACT_UPDATE';
    }
  }

  String get titleAr {
    switch (this) {
      case LifexPhonePermission.phoneContactsSelect:
        return 'اختيار جهة اتصال';
      case LifexPhonePermission.phoneContactsRead:
        return 'قراءة دفتر الهاتف';
      case LifexPhonePermission.phoneCallLogSelect:
        return 'اختيار من سجل المكالمات';
      case LifexPhonePermission.phoneCallLogRead:
        return 'قراءة سجل المكالمات';
      case LifexPhonePermission.phoneSmsSelect:
        return 'اختيار من الرسائل';
      case LifexPhonePermission.phoneSmsRead:
        return 'قراءة الرسائل';
      case LifexPhonePermission.lifexDirectorySearch:
        return 'بحث دليل Lifex';
      case LifexPhonePermission.trustedPersonCreate:
        return 'إنشاء شخص موثوق';
      case LifexPhonePermission.trustedPersonUpdate:
        return 'تحديث شخص موثوق';
      case LifexPhonePermission.trustedPersonRevoke:
        return 'إلغاء ثقة';
      case LifexPhonePermission.emergencyContactCreate:
        return 'إنشاء جهة طوارئ';
      case LifexPhonePermission.emergencyContactUpdate:
        return 'تحديث جهة طوارئ';
    }
  }
}

/// حالة القدرة الفعلية بعد ربط إذن Lifex بمنصة Android.
enum PlatformCapabilityState {
  unavailable,
  notRequested,
  denied,
  granted,
  limited,
  systemPicker,
  defaultHandlerRequired,
  restricted,
  requiresUserAction,
}

extension PlatformCapabilityStateLabel on PlatformCapabilityState {
  String get wireName {
    switch (this) {
      case PlatformCapabilityState.unavailable:
        return 'UNAVAILABLE';
      case PlatformCapabilityState.notRequested:
        return 'NOT_REQUESTED';
      case PlatformCapabilityState.denied:
        return 'DENIED';
      case PlatformCapabilityState.granted:
        return 'GRANTED';
      case PlatformCapabilityState.limited:
        return 'LIMITED';
      case PlatformCapabilityState.systemPicker:
        return 'SYSTEM_PICKER';
      case PlatformCapabilityState.defaultHandlerRequired:
        return 'DEFAULT_HANDLER_REQUIRED';
      case PlatformCapabilityState.restricted:
        return 'RESTRICTED';
      case PlatformCapabilityState.requiresUserAction:
        return 'REQUIRES_USER_ACTION';
    }
  }

  String get labelAr {
    switch (this) {
      case PlatformCapabilityState.unavailable:
        return 'غير متاح على هذا الجهاز';
      case PlatformCapabilityState.notRequested:
        return 'لم يُطلب بعد';
      case PlatformCapabilityState.denied:
        return 'مرفوض';
      case PlatformCapabilityState.granted:
        return 'ممنوح (نطاق محدود حسب السياسة)';
      case PlatformCapabilityState.limited:
        return 'محدود';
      case PlatformCapabilityState.systemPicker:
        return 'منتقي النظام (بدون قراءة كاملة)';
      case PlatformCapabilityState.defaultHandlerRequired:
        return 'يتطلب معالج افتراضي معتمد';
      case PlatformCapabilityState.restricted:
        return 'مقيّد بسياسة Google Play / Android';
      case PlatformCapabilityState.requiresUserAction:
        return 'يتطلب إجراءً من المستخدم';
    }
  }

  /// GRANTED لا يعني تلقائياً قراءة كاملة.
  bool get allowsFullAddressBookRead => false;

  bool get canSelectViaSystemPicker =>
      this == PlatformCapabilityState.systemPicker ||
      this == PlatformCapabilityState.granted ||
      this == PlatformCapabilityState.limited;
}
