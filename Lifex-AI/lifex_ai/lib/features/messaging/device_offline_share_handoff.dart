/// يفتح ورقة مشاركة الجهاز. النجاح يعني أن الورقة فُتحت، لا أن الطرف استلم.
library lifex_ai.features.messaging.device_offline_share_handoff;

import 'package:flutter/services.dart';

class DeviceOfflineShareHandoff {
  DeviceOfflineShareHandoff({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('lifex_ai/share');

  final MethodChannel _channel;

  Future<bool> openText(String text) async {
    if (text.trim().isEmpty) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('shareText', {
        'text': text,
      });
      return ok == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
