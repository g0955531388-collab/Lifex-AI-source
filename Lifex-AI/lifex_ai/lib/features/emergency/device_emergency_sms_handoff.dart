/// =============================================================
/// Lifex-AI — تسليم مسودة SMS للطوارئ على الجهاز
/// يفتح تطبيق الرسائل بمسودة جاهزة. ليس إرسالاً تلقائياً ولا ادعاء وصول.
/// =============================================================
library lifex_ai.features.emergency.device_emergency_sms_handoff;

import 'package:flutter/services.dart';

/// يفتح مسودة SMS على الجهاز. النجاح = فُتحت المسودة، لا أن الرسالة وصلت.
class DeviceEmergencySmsHandoff {
  DeviceEmergencySmsHandoff({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('lifex_ai/emergency_sms');

  final MethodChannel _channel;

  /// يُرجع true فقط إذا فُتحت مسودة SMS. لا يعني الإرسال.
  Future<bool> openDraft({
    required String phoneNumber,
    required String messageAr,
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('openSmsDraft', {
        'phone': phoneNumber,
        'body': messageAr,
      });
      return ok == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
