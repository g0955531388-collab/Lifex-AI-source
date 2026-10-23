/// يقطع النطق عند تغيير الشاشة. لا يشغّل الميكروفون.
library lifex_ai.features.voice.voice_route_observer;

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'voice_engine.dart';

class VoiceRouteObserver extends NavigatorObserver {
  VoiceRouteObserver._();

  static final VoiceRouteObserver instance = VoiceRouteObserver._();

  void _interrupt() {
    unawaited(VoiceEngine.instance.interruptIfSpeaking());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _interrupt();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _interrupt();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _interrupt();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _interrupt();
}
