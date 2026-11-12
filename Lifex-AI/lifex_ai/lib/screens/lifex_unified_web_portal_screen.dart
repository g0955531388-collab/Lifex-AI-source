/// مضيف بوابة Lifex-AI. الأزرار تفتح الشاشات الموجودة.
library lifex_ai.screens.lifex_unified_web_portal_screen;

import 'package:flutter/material.dart';

import '../core/ui/lifex_unified_web_portal.dart';
import '../features/voice/voice_engine.dart';
import 'device_center_screen.dart';
import 'emergency_contacts_screen.dart';
import 'live_sight_screen.dart';
import 'system_search_screen.dart';

class LifexUnifiedWebPortalScreen extends StatelessWidget {
  const LifexUnifiedWebPortalScreen({super.key, required this.profileId});

  final String profileId;

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return LifexUnifiedWebPortal(
      onListen: () async {
        final heard = await VoiceEngine.instance.listenFresh();
        if (!heard.success) {
          return PortalListenResult.failure(
            heard.errorMessageAr ?? 'تعذّر الاستماع. لم يُنفَّذ أمر.',
          );
        }
        return PortalListenResult.success(heard.textResult);
      },
      onStopListen: VoiceEngine.instance.stopListening,
      onOpenCamera: () => _push(
        context,
        LiveSightScreen(profileId: profileId, ask: BlindCameraAsk.scene),
      ),
      onOpenDevices: () => _push(context, const DeviceCenterScreen()),
      onOpenEmergency: () => _push(context, const EmergencyContactsScreen()),
      onOpenSearch: () => _push(context, const SystemSearchScreen()),
    );
  }
}
