/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: optical_radar_screen.dart
/// المسار: lib/screens/optical_radar_screen.dart
/// الوصف: واجهة الرادار الضوئي للمكفوفين. لا تعرض مسافة وهمية.
/// =============================================================
library lifex_ai.screens.optical_radar_screen;

import 'package:flutter/material.dart';

import '../features/vision/optical_radar_engine.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/accessible_widgets.dart';
import 'permission_transparency_screen.dart';
import '../widgets/lifex_text.dart';

class OpticalRadarScreen extends StatefulWidget {
  const OpticalRadarScreen({super.key});

  @override
  State<OpticalRadarScreen> createState() => _OpticalRadarScreenState();
}

class _OpticalRadarScreenState extends State<OpticalRadarScreen> {
  String _statusAr = 'اضغط للقياس. لن أعلن أمتاراً إن لم يتوفر حسّاس زمن الرحلة.';

  Future<void> _probe() async {
    final result = OpticalRadarEngine.instance.probe();
    setState(() => _statusAr = result.messageAr);
    announceForScreenReader(context, result.messageAr);
    await VoiceEngine.instance.speak(result.messageAr);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const LifexText('الرادار الضوئي')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const LifexText(
              'وميض الفلاش هنا لمساعدة المكفوفين ضمن إطار موافقة الكاميرا. '
              'ليس بديلاً عن العصا البيضاء، ولا يشخص حالة طبية.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _probe,
              icon: const Icon(Icons.flash_on_outlined),
              label: const LifexText('وميض وقياس إن توفّر العتاد'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PermissionTransparencyScreen(),
                  ),
                );
              },
              child: const LifexText('إدارة موافقة الكاميرا'),
            ),
            const SizedBox(height: 24),
            LifexText(_statusAr, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
