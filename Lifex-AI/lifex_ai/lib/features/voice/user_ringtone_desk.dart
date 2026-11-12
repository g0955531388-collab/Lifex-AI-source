/// نغمة يختارها المستخدم من نغمات الجهاز. الفشل يعيد النطق.
library lifex_ai.features.voice.user_ringtone_desk;

import 'package:flutter/services.dart';

class UserRingtoneChoice {
  const UserRingtoneChoice({required this.uri, required this.title});

  final String uri;
  final String title;
}

class UserRingtoneDesk {
  const UserRingtoneDesk();

  static const channelName = 'lifex_ai/user_ringtone';
  static const _channel = MethodChannel(channelName);

  Future<UserRingtoneChoice?> pick() async {
    try {
      final raw = await _channel.invokeMethod<Object?>('pick');
      if (raw is! Map) return null;
      final uri = raw['uri']?.toString().trim() ?? '';
      if (uri.isEmpty) return null;
      final title = raw['title']?.toString().trim() ?? '';
      return UserRingtoneChoice(
        uri: uri,
        title: title.isEmpty ? uri : title,
      );
    } catch (_) {
      return null;
    }
  }

  /// false يعني أن النغمة لم تُشغَّل، فيبقى النطق.
  Future<bool> play(String uri) async {
    final trimmed = uri.trim();
    if (trimmed.isEmpty) return false;
    try {
      final played = await _channel.invokeMethod<bool>('play', {'uri': trimmed});
      return played == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (_) {}
  }
}
