/// =============================================================
/// Lifex-AI — الطوارئ
/// الملف: emergency_message_manager.dart
/// المسار: lib/features/emergency/emergency_message_manager.dart
/// الوصف: تجهيز وإرسال رسائل الاستغاثة الفعلية لجهات الثقة والطوارئ
/// الرسمية، بمحتوى واضح ومباشر حسب مستوى الخطورة.
/// =============================================================

import '../../core/app_constants.dart';
import 'emergency_phone_contacts_registry.dart';

/// توقيع دالة الإرسال الفعلي (سيُربط لاحقاً بـ SMS/Push/مكالمة فعلية).
typedef EmergencySendFunction = Future<bool> Function(
  String recipientContact,
  String messageAr,
);

class EmergencyDispatchOutcome {
  const EmergencyDispatchOutcome({
    required this.localCaseOpened,
    required this.outboundSent,
    required this.contactCount,
    required this.messageAr,
  });

  final bool localCaseOpened;
  final bool outboundSent;
  final int contactCount;
  final String messageAr;
}

class EmergencyDispatchRecord {
  final String caseId;
  final String profileId;
  final String riskLevel;
  final DateTime dispatchedAt;

  EmergencyDispatchRecord({
    required this.caseId,
    required this.profileId,
    required this.riskLevel,
    DateTime? dispatchedAt,
  }) : dispatchedAt = dispatchedAt ?? DateTime.now();
}

/// مدير إرسال رسائل الاستغاثة.
class EmergencyMessageManager {
  EmergencyMessageManager({
    required this.emergencyContactsRegistry,
    this.sendFunction,
    this.draftHandoffFunction,
  });

  final EmergencyPhoneContactsRegistry emergencyContactsRegistry;
  final EmergencySendFunction? sendFunction;

  /// يفتح مسودة SMS فقط — لا يُعدّ إرسالاً ناجحاً أبداً.
  final EmergencySendFunction? draftHandoffFunction;
  final List<EmergencyDispatchRecord> _log = [];

  /// بناء نص الرسالة حسب مستوى الخطورة وإرسالها فعلياً لكل رقم في قائمة
  /// جهات الثقة الخاصة بالمستخدم (بحد أقصى عشرة أرقام — انظر
  /// emergency_phone_contacts_registry.dart)، وليس لنص عام ثابت كما كان سابقاً.
  /// التسجيل يتم دائماً حتى لو فشل الإرسال الفعلي، لأغراض التدقيق.
  Future<EmergencyDispatchOutcome> dispatchEmergencyMessage({
    required String profileId,
    required String caseId,
    required String riskLevel,
    required String reasonAr,
    double? latitude,
    double? longitude,
  }) async {
    _log.add(EmergencyDispatchRecord(
      caseId: caseId,
      profileId: profileId,
      riskLevel: riskLevel,
    ));

    final message = _buildMessage(riskLevel, reasonAr, latitude, longitude);
    final contacts = emergencyContactsRegistry.contactsFor(profileId);

    if (sendFunction != null) {
      var sent = 0;
      for (final contact in contacts) {
        final ok = await sendFunction!(contact.phoneNumber, message);
        if (ok) sent++;
      }
      return EmergencyDispatchOutcome(
        localCaseOpened: true,
        outboundSent: sent > 0 && sent == contacts.length,
        contactCount: contacts.length,
        messageAr: sent == 0
            ? 'سُجّلت الحالة محلياً. تعذّر إرسال الاستغاثة الخارجية.'
            : 'أُرسلت الاستغاثة إلى $sent من أصل ${contacts.length} جهة.',
      );
    }

    if (draftHandoffFunction != null && contacts.isNotEmpty) {
      var opened = 0;
      for (final contact in contacts) {
        final ok = await draftHandoffFunction!(contact.phoneNumber, message);
        if (ok) opened++;
      }
      return EmergencyDispatchOutcome(
        localCaseOpened: true,
        outboundSent: false,
        contactCount: contacts.length,
        messageAr: opened == 0
            ? 'سُجّلت الحالة محلياً. تعذّر فتح مسودات SMS على الجهاز.'
            : 'فُتحت $opened مسودة SMS على الجهاز لجهات الثقة. '
                'لم يُرسل تلقائياً — أكّد الإرسال من تطبيق الرسائل.',
      );
    }

    return EmergencyDispatchOutcome(
      localCaseOpened: true,
      outboundSent: false,
      contactCount: contacts.length,
      messageAr: contacts.isEmpty
          ? 'سُجّلت حالة طوارئ على هذا الجهاز. لا أرقام ثقة محفوظة، وقناة SMS/Push غير مربوطة.'
          : 'سُجّلت حالة طوارئ على هذا الجهاز لـ ${contacts.length} جهة. لم يُرسل SMS ولا إشعار دفع: القناة غير مربوطة بمفاتيح حقيقية.',
    );
  }

  String _buildMessage(
    String riskLevel,
    String reasonAr,
    double? latitude,
    double? longitude,
  ) {
    final urgencyPrefix = riskLevel == 'critical'
        ? '🚨 حالة طوارئ حرجة'
        : '⚠️ تنبيه صحي';
    final locationLine = (latitude != null && longitude != null)
        ? '\nالموقع الحالي: https://maps.google.com/?q=$latitude,$longitude'
        : '';
    // ملاحظة تصميم متعمَّدة: نستخدم نص الإسناد المختصر (وليس الكامل)
    // في رسائل الطوارئ تحديداً، لأن الرسالة يجب أن تبقى قصيرة ومباشرة
    // قدر الإمكان في حالة قد تكون فيها حياة إنسان على المحك؛ النص
    // الإسنادي الكامل يظهر في شاشة "حول التطبيق" والشاشة الافتتاحية.
    return '$urgencyPrefix: $reasonAr. يُرجى التواصل الفوري أو التوجه '
        'للموقع إن أمكن.$locationLine\n\n${AppConstants.ownershipStatementShort}';
  }

  List<EmergencyDispatchRecord> get log => List.unmodifiable(_log);
}
