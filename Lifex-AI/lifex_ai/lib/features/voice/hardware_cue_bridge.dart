/// =============================================================
/// Lifex-AI — وحدة الصوت
/// الملف: hardware_cue_bridge.dart
/// جسر الضغطات من النشاط الأصلي، وحفظ المعايرة.
/// =============================================================
library lifex_ai.features.voice.hardware_cue_bridge;

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../accessibility/access_mode_preference.dart';
import '../accessibility/blind_volume_shortcut.dart';
import 'hardware_cue_calibrator.dart';

class HardwareCueBridge {
  HardwareCueBridge._();
  static final HardwareCueBridge instance = HardwareCueBridge._();

  static const _channel = MethodChannel('lifex_ai/hardware_cue');
  static const _prefsKey = 'lifex_hardware_cue_v1';

  final HardwareCueCalibrator calibrator = HardwareCueCalibrator();
  void Function()? onCueFired;
  bool blindArmed = false;

  Future<void> attach() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.contains(':')) {
      // stored as kind|taps|window|signal
      final parts = raw.split('|');
      if (parts.length >= 4) {
        calibrator.applyMap({
          'kind': parts[0],
          'tapCount': int.tryParse(parts[1]) ?? 2,
          'windowMs': int.tryParse(parts[2]) ?? 480,
          'startSignal': parts[3],
        });
      }
    }
    _channel.setMethodCallHandler(_onNative);
    await refreshBlindArm();
  }

  /// أربع ضغطات للمكفوف لا تستبدل معايرة الضغطتين المحفوظة.
  Future<void> refreshBlindArm() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getBool(AccessModePreference.enabledKey) ?? false;
    final chosen = prefs.getBool(BlindVolumeShortcut.prefsKey) ?? false;
    blindArmed = BlindVolumeShortcut.armed(
      accessModeEnabled: access,
      shortcutChosen: chosen,
    );
    if (blindArmed) {
      await _pushCounts(
        kind: HardwareCueKind.volumeUpDouble.name,
        tapCount: BlindVolumeShortcut.taps,
        windowMs: BlindVolumeShortcut.windowMs,
      );
      return;
    }
    await _pushToNative();
  }

  Future<void> _pushCounts({
    required String kind,
    required int tapCount,
    required int windowMs,
  }) async {
    try {
      await _channel.invokeMethod<void>('configure', {
        'kind': kind,
        'tapCount': tapCount,
        'windowMs': windowMs,
      });
    } on MissingPluginException {
      // الاختبارات والمنصات بلا جسر تبقى المعايرة محلية.
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      '${calibrator.kind.name}|${calibrator.tapCount}|${calibrator.windowMs}|${calibrator.startSignal.name}',
    );
    if (blindArmed) {
      await refreshBlindArm();
      return;
    }
    await _pushToNative();
  }

  Future<void> _pushToNative() async {
    try {
      await _channel.invokeMethod<void>('configure', {
        'kind': calibrator.kind.name,
        'tapCount': calibrator.tapCount,
        'windowMs': calibrator.windowMs,
      });
    } on MissingPluginException {
      // الاختبارات والمنصات بلا جسر تبقى المعايرة محلية.
    }
  }

  Future<dynamic> _onNative(MethodCall call) async {
    if (call.method == 'fired') {
      onCueFired?.call();
    }
  }
}
