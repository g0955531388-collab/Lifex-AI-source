/// شريط وصول عمودي مقسوم: أعلاه المساعد البصري بالكاميرا الخلفية، وأسفله الكاميرا الأمامية.
library lifex_ai.widgets.blind_camera_rail;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/studio_theme.dart';
import '../features/accessibility/blind_assist_gate.dart';

class BlindCameraRail extends StatelessWidget {
  const BlindCameraRail({
    super.key,
    required this.onZone,
    this.armedZone,
  });

  final void Function(BlindRailZone zone) onZone;
  final BlindRailZone? armedZone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Material(
        color: StudioTheme.teal,
        child: Column(
          children: [
            Expanded(
              child: _Half(
                zone: BlindRailZone.assistant,
                title: 'المساعد البصري',
                armed: armedZone == BlindRailZone.assistant,
                onZone: onZone,
              ),
            ),
            const ColoredBox(
              color: Colors.white,
              child: SizedBox(height: 3, width: double.infinity),
            ),
            Expanded(
              child: _Half(
                zone: BlindRailZone.front,
                title: 'الكاميرا الأمامية',
                armed: armedZone == BlindRailZone.front,
                onZone: onZone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Half extends StatelessWidget {
  const _Half({
    required this.zone,
    required this.title,
    required this.armed,
    required this.onZone,
  });

  final BlindRailZone zone;
  final String title;
  final bool armed;
  final void Function(BlindRailZone zone) onZone;

  String get _spoken => zone == BlindRailZone.assistant
      ? BlindAssistGate.assistantAskAr
      : BlindAssistGate.frontAskAr;

  @override
  Widget build(BuildContext context) {
    final label = armed ? '$_spoken. اللمسة التالية تفتح.' : _spoken;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: armed ? const Color(0xFF0E6E66) : StudioTheme.teal,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onZone(zone);
          },
          child: Center(
            child: RotatedBox(
              quarterTurns: 3,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
