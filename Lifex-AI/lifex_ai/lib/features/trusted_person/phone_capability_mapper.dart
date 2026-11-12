/// =============================================================
/// Lifex-AI — خريطة القدرة الهاتفية
/// الملف: phone_capability_mapper.dart
/// المسار: lib/features/trusted_person/phone_capability_mapper.dart
/// الوصف: Lifex Permission → Platform Capability → Android path → State.
/// لا يُعلَن READ_CALL_LOG / READ_SMS في البيان لمجرد «الراحة».
/// =============================================================
library lifex_ai.features.trusted_person.phone_capability_mapper;

import 'lifex_phone_permission.dart';

class PhoneCapabilityAssessment {
  const PhoneCapabilityAssessment({
    required this.lifexPermission,
    required this.platformCapability,
    required this.androidPath,
    required this.state,
    required this.reasonAr,
    required this.playPolicyNoteAr,
    this.declaredInManifest = false,
    this.defaultHandlerRequired = false,
  });

  final LifexPhonePermission lifexPermission;
  final String platformCapability;
  final String androidPath;
  final PlatformCapabilityState state;
  final String reasonAr;
  final String playPolicyNoteAr;
  final bool declaredInManifest;
  final bool defaultHandlerRequired;

  bool get pretendsAccessAvailable =>
      state == PlatformCapabilityState.granted &&
      (lifexPermission == LifexPhonePermission.phoneCallLogRead ||
          lifexPermission == LifexPhonePermission.phoneSmsRead);
}

/// يقيّم القدرات بصدق — بدون افتراض منح أذونات Play المحظورة.
class PhoneCapabilityMapper {
  const PhoneCapabilityMapper({
    this.isAndroid = true,
    this.hasSystemContactPicker = true,
    this.isDefaultSmsHandler = false,
    this.isDefaultDialer = false,
    this.isDefaultAssistant = false,
    this.callLogPermissionGranted = false,
    this.smsReadPermissionGranted = false,
    this.callLogDeclaredInManifest = false,
    this.smsReadDeclaredInManifest = false,
  });

  final bool isAndroid;
  final bool hasSystemContactPicker;
  final bool isDefaultSmsHandler;
  final bool isDefaultDialer;
  final bool isDefaultAssistant;
  final bool callLogPermissionGranted;
  final bool smsReadPermissionGranted;
  final bool callLogDeclaredInManifest;
  final bool smsReadDeclaredInManifest;

  bool get _eligibleSensitivePhoneRole =>
      isDefaultDialer || isDefaultSmsHandler || isDefaultAssistant;

  PhoneCapabilityAssessment assess(LifexPhonePermission permission) {
    switch (permission) {
      case LifexPhonePermission.phoneContactsSelect:
        if (!isAndroid) {
          return PhoneCapabilityAssessment(
            lifexPermission: permission,
            platformCapability: 'contacts.select',
            androidPath: 'N/A',
            state: PlatformCapabilityState.unavailable,
            reasonAr: 'منتقي جهات الاتصال متاح على Android.',
            playPolicyNoteAr: 'لا قراءة كاملة لدفتر الهاتف.',
          );
        }
        if (hasSystemContactPicker) {
          return const PhoneCapabilityAssessment(
            lifexPermission: LifexPhonePermission.phoneContactsSelect,
            platformCapability: 'contacts.select',
            androidPath: 'Intent.ACTION_PICK / ContactsContract',
            state: PlatformCapabilityState.systemPicker,
            reasonAr:
                'اختيار جهة اتصال واحدة عبر منتقي النظام دون نسخ الدفتر.',
            playPolicyNoteAr:
                'لا يتطلب READ_CONTACTS لقراءة الدفتر كاملاً عند استخدام المنتقي.',
            declaredInManifest: false,
          );
        }
        return const PhoneCapabilityAssessment(
          lifexPermission: LifexPhonePermission.phoneContactsSelect,
          platformCapability: 'contacts.select',
          androidPath: 'unavailable',
          state: PlatformCapabilityState.unavailable,
          reasonAr: 'منتقي النظام غير متاح.',
          playPolicyNoteAr: 'استخدم الإدخال اليدوي أو دليل Lifex.',
        );

      case LifexPhonePermission.phoneContactsRead:
        return const PhoneCapabilityAssessment(
          lifexPermission: LifexPhonePermission.phoneContactsRead,
          platformCapability: 'contacts.read_all',
          androidPath: 'READ_CONTACTS (not requested by default)',
          state: PlatformCapabilityState.restricted,
          reasonAr:
              'Lifex لا يطلب قراءة دفتر الهاتف كاملاً. الاختيار عبر المنتقي فقط.',
          playPolicyNoteAr: 'تقليل البيانات: SELECT → MINIMUM → STORE.',
          declaredInManifest: false,
        );

      case LifexPhonePermission.phoneCallLogSelect:
      case LifexPhonePermission.phoneCallLogRead:
        if (callLogDeclaredInManifest && !_eligibleSensitivePhoneRole) {
          // Honesty: declaring without eligibility is a Play risk — we refuse
          // to treat it as available even if OS grants at runtime in sideload.
          return PhoneCapabilityAssessment(
            lifexPermission: permission,
            platformCapability: 'call_log',
            androidPath: 'READ_CALL_LOG',
            state: PlatformCapabilityState.restricted,
            reasonAr:
                'قراءة سجل المكالمات غير مؤهلة للنشر على Google Play لهذا التطبيق.',
            playPolicyNoteAr:
                'يتطلب دور Phone/SMS/Assistant افتراضي معتمد أو استثناء رسمي.',
            declaredInManifest: true,
            defaultHandlerRequired: true,
          );
        }
        if (!_eligibleSensitivePhoneRole) {
          return PhoneCapabilityAssessment(
            lifexPermission: permission,
            platformCapability: 'call_log',
            androidPath: 'READ_CALL_LOG (not declared)',
            state: PlatformCapabilityState.defaultHandlerRequired,
            reasonAr:
                'لا وصول مباشر لسجل المكالمات. استخدم جهات الاتصال أو الإدخال اليدوي.',
            playPolicyNoteAr:
                'Google Play يقيّد READ_CALL_LOG بشدة خارج معالجات الهاتف المعتمدة.',
            declaredInManifest: false,
            defaultHandlerRequired: true,
          );
        }
        if (!callLogPermissionGranted) {
          return PhoneCapabilityAssessment(
            lifexPermission: permission,
            platformCapability: 'call_log',
            androidPath: 'READ_CALL_LOG',
            state: PlatformCapabilityState.notRequested,
            reasonAr: 'الدور الافتراضي موجود لكن الإذن غير ممنوح بعد.',
            playPolicyNoteAr: 'يُطلب وقت الحاجة فقط إن كان الدور مؤهلاً.',
            declaredInManifest: callLogDeclaredInManifest,
            defaultHandlerRequired: false,
          );
        }
        return PhoneCapabilityAssessment(
          lifexPermission: permission,
          platformCapability: 'call_log',
          androidPath: 'READ_CALL_LOG',
          state: PlatformCapabilityState.granted,
          reasonAr: 'اختيار سجل واحد بمبادرة المستخدم — بلا أرشفة كاملة.',
          playPolicyNoteAr: 'Data minimization إلزامي.',
          declaredInManifest: callLogDeclaredInManifest,
        );

      case LifexPhonePermission.phoneSmsSelect:
      case LifexPhonePermission.phoneSmsRead:
        if (smsReadDeclaredInManifest && !_eligibleSensitivePhoneRole) {
          return PhoneCapabilityAssessment(
            lifexPermission: permission,
            platformCapability: 'sms',
            androidPath: 'READ_SMS / RECEIVE_SMS',
            state: PlatformCapabilityState.restricted,
            reasonAr:
                'قراءة SMS غير مؤهلة للنشر على Google Play لهذا التطبيق.',
            playPolicyNoteAr:
                'يتطلب معالج SMS/Assistant افتراضي أو مسار مشاركة نظامي.',
            declaredInManifest: true,
            defaultHandlerRequired: true,
          );
        }
        if (!_eligibleSensitivePhoneRole) {
          return PhoneCapabilityAssessment(
            lifexPermission: permission,
            platformCapability: 'sms',
            androidPath: 'READ_SMS (not declared)',
            state: PlatformCapabilityState.defaultHandlerRequired,
            reasonAr:
                'لا قراءة لمحتوى الرسائل. مسار بديل: مشاركة من تطبيق الرسائل أو إدخال يدوي.',
            playPolicyNoteAr:
                'ممنوع استخدام READ_SMS كحل شكلي دون أهلية Play.',
            declaredInManifest: false,
            defaultHandlerRequired: true,
          );
        }
        if (!smsReadPermissionGranted) {
          return PhoneCapabilityAssessment(
            lifexPermission: permission,
            platformCapability: 'sms',
            androidPath: 'READ_SMS',
            state: PlatformCapabilityState.notRequested,
            reasonAr: 'الدور الافتراضي موجود لكن إذن SMS غير ممنوح.',
            playPolicyNoteAr: 'لا قراءة كاملة للمحادثات — مرسل واحد فقط.',
            declaredInManifest: smsReadDeclaredInManifest,
          );
        }
        return PhoneCapabilityAssessment(
          lifexPermission: permission,
          platformCapability: 'sms',
          androidPath: 'READ_SMS',
          state: PlatformCapabilityState.limited,
          reasonAr: 'اختيار مرسل محادثة بمبادرة المستخدم فقط.',
          playPolicyNoteAr: 'لا أرشفة لصناديق الوارد.',
          declaredInManifest: smsReadDeclaredInManifest,
        );

      case LifexPhonePermission.lifexDirectorySearch:
        return const PhoneCapabilityAssessment(
          lifexPermission: LifexPhonePermission.lifexDirectorySearch,
          platformCapability: 'lifex.directory',
          androidPath: 'in-app',
          state: PlatformCapabilityState.granted,
          reasonAr: 'بحث محلي في هويات Lifex المعروفة على الجهاز.',
          playPolicyNoteAr:
              'العثور على شخص ≠ وصول صحي. يتطلب تفويضاً منفصلاً.',
        );

      case LifexPhonePermission.trustedPersonCreate:
      case LifexPhonePermission.trustedPersonUpdate:
      case LifexPhonePermission.trustedPersonRevoke:
      case LifexPhonePermission.emergencyContactCreate:
      case LifexPhonePermission.emergencyContactUpdate:
        return PhoneCapabilityAssessment(
          lifexPermission: permission,
          platformCapability: 'lifex.trusted_person',
          androidPath: 'in-app policy',
          state: PlatformCapabilityState.requiresUserAction,
          reasonAr: 'يتطلب موافقة صريحة من صاحب الملف — لا يُمنح للأدمن تلقائياً.',
          playPolicyNoteAr: 'Purpose limitation + Audit.',
        );
    }
  }

  List<PhoneCapabilityAssessment> settingsSnapshot() => [
        assess(LifexPhonePermission.phoneContactsSelect),
        assess(LifexPhonePermission.phoneContactsRead),
        assess(LifexPhonePermission.phoneCallLogSelect),
        assess(LifexPhonePermission.phoneSmsSelect),
        assess(LifexPhonePermission.lifexDirectorySearch),
      ];
}
