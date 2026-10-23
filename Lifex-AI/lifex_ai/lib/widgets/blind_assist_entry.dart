/// دخول المساعد البصري من الشريط المقسوم: اللمسة الأولى تنطق، والثانية على نفس القسم تفتح.
library lifex_ai.widgets.blind_assist_entry;

import 'dart:async';

import 'package:flutter/material.dart';

import '../features/accessibility/blind_assist_gate.dart';
import '../features/voice/voice_engine.dart';
import 'blind_camera_rail.dart';

class BlindAssistEntry extends StatefulWidget {
  const BlindAssistEntry({
    super.key,
    required this.onOpenBack,
    required this.onOpenFront,
  });

  final Future<void> Function() onOpenBack;
  final Future<void> Function() onOpenFront;

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
        : BlindAssistGate.frontAskAr;
    await VoiceEngine.instance.speak(line);
    if (!mounted || !_gate.armed || _busy) return;
    final heard = await VoiceEngine.instance.listenFresh();
    if (!mounted || !_gate.armed || _busy) return;
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
      if (zone == BlindRailZone.front) {
        await widget.onOpenFront();
      } else {
        await widget.onOpenBack();
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
