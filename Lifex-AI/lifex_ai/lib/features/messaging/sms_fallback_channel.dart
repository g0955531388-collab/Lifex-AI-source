/// =============================================================
/// Lifex-AI — التراسل والاتصالات الاجتماعية
/// الملف: sms_fallback_channel.dart
/// المسار: lib/features/messaging/sms_fallback_channel.dart
/// الوصف: قناة احتياطية عبر SMS عند انقطاع الإنترنت — تُستخدم فقط
/// للرسائل الحرجة (طوارئ) وليس للدردشة العادية، لتجنّب تكاليف غير
/// متوقعة على المستخدم.
///
/// ⚠️ هذه القناة من ضمن alwaysActiveFeatures في survival_energy_mode.dart
/// ويجب ألا تُعطَّل أبداً حتى في أحرج ظروف البطارية أو انقطاع الشبكة.
/// =============================================================
library;

typedef SmsSendFunction = Future<bool> Function(String phoneNumber, String message);

class SmsFallbackRecord {
  final String recipientPhoneNumber;
  final String message;
  final DateTime sentAt;
  final bool success;

  SmsFallbackRecord({
    required this.recipientPhoneNumber,
    required this.message,
    required this.success,
    DateTime? sentAt,
  }) : sentAt = sentAt ?? DateTime.now();
}

/// القناة الاحتياطية عبر SMS.
class SmsFallbackChannel {
  SmsFallbackChannel({required this.sendFunction});

  final SmsSendFunction sendFunction;
  final List<SmsFallbackRecord> _log = [];

  /// إرسال رسالة طوارئ حرجة فقط عبر SMS — لا يُستخدم لأي غرض آخر.
  Future<bool> sendCriticalMessage({
    required String recipientPhoneNumber,
    required String message,
  }) async {
    final success = await sendFunction(recipientPhoneNumber, message);
    _log.add(SmsFallbackRecord(
      recipientPhoneNumber: recipientPhoneNumber,
      message: message,
      success: success,
    ));
    return success;
  }

  List<SmsFallbackRecord> get log => List.unmodifiable(_log);
}
