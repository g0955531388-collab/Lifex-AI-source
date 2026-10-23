/// =============================================================
/// Lifex-AI — وحدة الصوت
/// الملف: hardware_cue_host.dart
/// يفتح الاستماع من الزر المعاير عبر الملاح الموحّد. بلا Device Admin.
/// =============================================================
library lifex_ai.features.voice.hardware_cue_host;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_navigator.dart';
import '../../screens/live_sight_screen.dart';
import '../../screens/voice_control_screen.dart';
import '../accessibility/blind_volume_shortcut.dart';
import '../profile/active_profile_controller.dart';
import 'hardware_cue_bridge.dart';
import 'start_listen_signal.dart';
import 'voice_engine.dart';

class HardwareCueHost {
  HardwareCueHost._();

  static const _shortcut = MethodChannel('lifex_ai/assistant_shortcut');
  static var _shortcutBound = false;

  static void bind() {
    HardwareCueBridge.instance.onCueFired = fire;
    if (_shortcutBound) return;
    _shortcutBound = true;
    _shortcut.setMethodCallHandler((call) async {
      if (call.method == 'open') fire();
    });
  }

  static Future<void> consumeLauncherShortcut() async {
    try {
      final value = await _shortcut.invokeMethod<String>('consume');
      if (value == 'visual_assistant') fire();
    } on MissingPluginException {
      return;
    } catch (_) {
      return;
    }
  }

  static void fire() {
    unawaited(_fire());
  }

  static DateTime? _lastBlindFire;

  static Future<void> _fire() async {
    final bridge = HardwareCueBridge.instance;
    final calibrator = bridge.calibrator;
    if (calibrator.powerButtonIsSystemOwned) {
      return;
    }
    if (bridge.blindArmed) {
      final now = DateTime.now();
      if (_lastBlindFire != null &&
          now.difference(_lastBlindFire!) < const Duration(seconds: 3)) {
        return;
      }
      _lastBlindFire = now;
      final nav = LifexNavigator.key.currentState;
      final ctx = LifexNavigator.key.currentContext;
      String? profileId;
      if (ctx != null) {
        try {
          profileId = ctx.read<ActiveProfileController>().activeProfileId;
        } catch (_) {
          profileId = null;
        }
      }
      await HapticFeedback.heavyImpact();
      await VoiceEngine.instance.speak(BlindVolumeShortcut.confirmationAr);
      if (LiveSightScreen.isOpen) return;
      if (nav == null || ctx == null) return;
      if (profileId == null || profileId.isEmpty) {
        await VoiceEngine.instance.speak('لم يُحفظ ملف صحي بعد.');
        return;
      }
      await nav.push(
        MaterialPageRoute(
          builder: (_) => LiveSightScreen(profileId: profileId!),
        ),
      );
      return;
    }
    await const StartListenSignal().play(
      kind: calibrator.startSignal,
      arabic: true,
    );
    if (VoiceControlScreen.requestListenIfOpen()) {
      return;
    }
    final nav = LifexNavigator.key.currentState;
    if (nav == null) return;
    await nav.push(
      MaterialPageRoute(
        builder: (_) => const VoiceControlScreen(listenOnOpen: true),
      ),
    );
  }
}
