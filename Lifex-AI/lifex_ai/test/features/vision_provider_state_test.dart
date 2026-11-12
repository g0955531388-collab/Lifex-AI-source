import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifex_ai/features/accessibility/local_object_detector.dart';
import 'package:lifex_ai/features/accessibility/vision_provider_state.dart';

VisionProviderState _state({
  bool cameraGranted = true,
  bool cameraInitFailed = false,
  bool localModelLoaded = false,
  bool cloudRequested = false,
  bool cloudConsent = false,
  bool? online = true,
  bool cloudConnecting = false,
  bool cloudStreaming = false,
  bool lowConfidence = false,
}) =>
    resolveVisionProviderState(
      cameraGranted: cameraGranted,
      cameraInitFailed: cameraInitFailed,
      localModelLoaded: localModelLoaded,
      cloudRequested: cloudRequested,
      cloudConsent: cloudConsent,
      online: online,
      cloudConnecting: cloudConnecting,
      cloudStreaming: cloudStreaming,
      lowConfidence: lowConfidence,
    );

void main() {
  test('each state is reachable in the stated order', () {
    expect(_state(cameraGranted: false), VisionProviderState.needsPermission);
    expect(_state(cameraInitFailed: true), VisionProviderState.initFailed);
    expect(_state(cloudRequested: true), VisionProviderState.needsCloudConsent);
    expect(
      _state(cloudRequested: true, cloudConsent: true, cloudConnecting: true),
      VisionProviderState.connecting,
    );
    expect(
      _state(localModelLoaded: true, lowConfidence: true),
      VisionProviderState.lowConfidence,
    );
    expect(_state(localModelLoaded: true), VisionProviderState.ready);
    expect(_state(cloudStreaming: true), VisionProviderState.ready);
    expect(_state(online: false), VisionProviderState.offline);
    expect(_state(), VisionProviderState.localModelUnavailable);
  });

  test('no consent means no connecting, even when the user asks for cloud', () {
    expect(
      _state(cloudRequested: true, cloudConnecting: true),
      VisionProviderState.needsCloudConsent,
    );
  });

  test('offline does not claim connecting', () {
    expect(
      _state(cloudConsent: true, cloudConnecting: true, online: false),
      VisionProviderState.offline,
    );
  });

  test('without the native detector the boot check reports not loaded', () async {
    final check = await LocalObjectDetector.checkModel();
    expect(check.ran, isFalse);
    expect(check.loaded, isFalse);
    expect(check.reason, isNotEmpty);
    expect(LocalObjectDetector.lastCheck, same(check));
  });

  test('every state line has an English entry in the shared dictionary', () {
    final table = (jsonDecode(
      File('assets/i18n/ui_en.json').readAsStringSync(),
    ) as Map)
        .cast<String, dynamic>();
    for (final line in [
      VisionStateSpeech.checkingModel,
      ...VisionStateSpeech.lines.values,
    ]) {
      expect(table.containsKey(line), isTrue, reason: line);
    }
  });
}
