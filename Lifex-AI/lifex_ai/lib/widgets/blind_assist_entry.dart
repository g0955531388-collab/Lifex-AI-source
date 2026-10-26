/// دخول النظامين من الشريط: اللمسة الأولى تنطق، والثانية على نفس القسم تفتح.
/// SPOT ليس الكاميرا الأمامية. فتح أحد النظامين مسؤولية الصفحة المستقبِلة لإغلاق الآخر.
library lifex_ai.widgets.blind_assist_entry;

import 'dart:async';

import 'package:flutter/material.dart';

import '../features/accessibility/blind_assist_gate.dart';
import '../features/spot/spot_speech.dart';
import '../features/voice/voice_engine.dart';
import 'blind_camera_rail.dart';

class BlindAssistEntry extends StatefulWidget {
  const BlindAssistEntry({
    super.key,
    required this.onOpenAssistant,
    required this.onOpenSpot,
  });

  final Future<void> Function() onOpenAssistant;
  final Future<void> Function() onOpenSpot;

  @override
  State<BlindAssistEntry> createState() => _BlindAssistEntryState();
}

class _BlindAssistEntryState extends State<BlindAssistEntry> {
  final BlindAssistGate _gate = BlindAssistGate();
  bool _busy = false;

  Future<void> _press(BlindRailZone zone) async {
    if (_busy) return;
    final step = _gate.press(zone);
    if (step == BlindAssistStep.open) {
      await _go(zone);
      return;
    }
    if (mounted) setState(() {});
    final line = zone == BlindRailZone.assistant
        ? BlindAssistGate.assistantAskAr
        : SpotSpeech.armAsk(SpotSpeech.deviceLanguage());
    await VoiceEngine.instance.speak(line);
    if (!mounted || !_gate.armed || _busy) return;
    final heard = await VoiceEngine.instance.listenFresh();
    if (!mounted || !_gate.armed || _busy) return;
    if (SpotSpeech.askedFor(heard.textResult)) {
      await _go(BlindRailZone.spot);
      return;
    }
    final armed = _gate.armedZone;
    if (armed != null &&
        _gate.hear(heard.textResult) == BlindAssistStep.open) {
      await _go(armed);
    }
  }

  Future<void> _go(BlindRailZone zone) async {
    _busy = true;
    if (mounted) setState(() {});
    await VoiceEngine.instance.stopListening();
    if (!mounted) return;
    try {
      if (zone == BlindRailZone.spot) {
        await widget.onOpenSpot();
      } else {
        await widget.onOpenAssistant();
      }
    } finally {
      _gate.reset();
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlindCameraRail(
      armedZone: _gate.armedZone,
      onZone: (zone) => unawaited(_press(zone)),
    );
  }
}
