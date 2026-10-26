/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: accessibility_assistant_screen.dart
/// المسار: lib/screens/accessibility_assistant_screen.dart
/// الوصف: واجهة مساعدة المكفوفين وضعاف البصر. البث الحي هو المسار،
/// واللقطة الواحدة اختيار داخل صفحة العدسة. كشف العوائق يبقى غير متاح.
/// =============================================================
library lifex_ai.screens.accessibility_assistant_screen;

import 'package:flutter/material.dart';

import '../features/voice/voice_engine.dart';
import '../widgets/accessible_widgets.dart';
import 'live_sight_screen.dart';
import 'medical_reference_screen.dart';
import 'optical_radar_screen.dart';

class AccessibilityAssistantScreen extends StatefulWidget {
  const AccessibilityAssistantScreen({super.key, required this.profileId});

  final String profileId;

  @override
  State<AccessibilityAssistantScreen> createState() =>
      _AccessibilityAssistantScreenState();
}

class _AccessibilityAssistantScreenState
    extends State<AccessibilityAssistantScreen> {
  String? _lastResultAr;

  void _openLens({
    BlindCameraDelivery delivery = BlindCameraDelivery.liveStream,
    BlindCameraAsk ask = BlindCameraAsk.both,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveSightScreen(
          profileId: widget.profileId,
          delivery: delivery,
          ask: ask,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenArrival(
      message:
          'المساعد البصري. البث الحي يشرح المشهد أو النص بلغة الجهاز. المسافة تبقى للعصا البيضاء.',
      child: Scaffold(
      appBar: AppBar(title: const Text('المساعد البصري')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Semantics(
              label: 'هذه أداة مساعدة إضافية. العصا البيضاء أو كلب الإرشاد '
                  'يبقى وسيلة السلامة، خصوصاً عند عبور الطرق.',
              child: const ExcludeSemantics(
                child: Text(
                  'هذه أداة مساعدة إضافية. العصا البيضاء أو كلب الإرشاد '
                  'يبقى وسيلة السلامة، خصوصاً عند عبور الطرق.',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _FeatureButton(
              icon: Icons.videocam_outlined,
              label: 'البث الحي على هذه الشاشة',
              onTap: () => _openLens(),
            ),
            _FeatureButton(
              icon: Icons.remove_red_eye_outlined,
              label: 'صف لي المكان',
              onTap: () => _openLens(ask: BlindCameraAsk.scene),
            ),
            _FeatureButton(
              icon: Icons.warning_amber_outlined,
              label: 'هل يوجد عائق أمامي؟',
              hint: BlindNavigationCopy.obstacleUnavailableText,
              onTap: () {
                      setState(() {
                        _lastResultAr = BlindNavigationCopy.obstacleUnavailableText;
                      });
                      announceForScreenReader(
                        context,
                        BlindNavigationCopy.obstacleUnavailableText,
                      );
                      VoiceEngine.instance.speak(
                        BlindNavigationCopy.obstacleUnavailableText,
                      );
                    },
            ),
            _FeatureButton(
              icon: Icons.text_fields_outlined,
              label: 'اقرأ لي هذا النص',
              onTap: () => _openLens(ask: BlindCameraAsk.text),
            ),
            _FeatureButton(
              icon: Icons.flash_on_outlined,
              label: 'الرادار الضوئي',
              onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const OpticalRadarScreen(),
                        ),
                      );
                    },
            ),
            _FeatureButton(
              icon: Icons.biotech_outlined,
              label: 'مرجع العلامات البصرية',
              onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MedicalReferenceScreen(
                            kind: MedicalReferenceKind.cameraSigns,
                          ),
                        ),
                      );
                    },
            ),
            const SizedBox(height: 20),
            if (_lastResultAr != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _lastResultAr!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

class _FeatureButton extends StatelessWidget {
  const _FeatureButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.hint = 'زر في المساعد البصري',
  });

  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: Semantics(
          button: true,
          enabled: enabled,
          label: label,
          hint: enabled ? hint : 'انتظر انتهاء القراءة الحالية',
          onTap: onTap,
          child: ExcludeSemantics(
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(label, style: const TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
