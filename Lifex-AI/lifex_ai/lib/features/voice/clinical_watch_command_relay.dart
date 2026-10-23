/// =============================================================
/// Lifex-AI — المراقبة الصحية
/// استماع للأوامر ما دام إشعار المراقبة ظاهراً وموافقة المستخدم قائمة.
/// إيقاف الإشعار يوقف الحلقة. لا تصنيف تنفس أو سقوط.
/// =============================================================
library lifex_ai.features.voice.clinical_watch_command_relay;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_navigator.dart';
import '../../screens/voice_control_screen.dart';
import 'voice_engine.dart';

class ClinicalWatchCommandRelay {
  ClinicalWatchCommandRelay._();

  static final ClinicalWatchCommandRelay instance =
      ClinicalWatchCommandRelay._();

  bool _run = false;
  bool _busy = false;

  bool get running => _run;

  void start() {
    if (_run) return;
    _run = true;
    unawaited(_pump());
  }

  Future<void> stop() async {
    _run = false;
    await VoiceEngine.instance.stopListening();
  }

  Future<void> _pump() async {
    if (_busy) return;
    _busy = true;
    try {
      while (_run) {
        final state = VoiceEngine.instance.state;
        if (state == VoiceEngineState.listening ||
            state == VoiceEngineState.speaking) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          continue;
        }
        final result = await VoiceEngine.instance.startListening();
        if (!_run) break;
        final heard = result.textResult?.trim() ?? '';
        if (heard.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          continue;
        }
        if (VoiceControlScreen.offerHeardText(heard)) {
          continue;
        }
        final nav = LifexNavigator.key.currentState;
        if (nav == null) {
          await VoiceEngine.instance.speak('سمعت: $heard');
          continue;
        }
        await nav.push(
          MaterialPageRoute(
            builder: (_) => VoiceControlScreen(seedText: heard),
          ),
        );
      }
    } finally {
      _busy = false;
    }
  }
}
