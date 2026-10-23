/// إعداد صوتي واحد بعد منح الميكروفون. نجاح الاستدعاء لا يثبت أن الصوت سُمع.
library lifex_ai.features.voice.first_run_voice;

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../accessibility/access_mode_preference.dart';
import 'voice_engine.dart';

class FirstRunVoice {
  const FirstRunVoice._();

  static const prefKey = 'lifex_voice_intro_v1';

  static const introAr =
      'مرحباً في Lifex-AI. أقرأ بالعربية وأستمع عندما تطلب. '
      'الشريط الأيسر مقسوم: أعلاه المساعد البصري بالكاميرا الخلفية، وأسفله الكاميرا الأمامية. اللمسة الأولى تنطق والثانية على نفس المكان تفتح. '
      'الاستماع لا يعمل من شاشة القفل ولا عندما تكون الشاشة مطفأة.';

  static const blindEntryKey = 'lifex_blind_home_voice_v1';

  static const blindEntryAr =
      'كاميرا المكفوفين هي المدخل الأول. أعلى الشريط الأيسر يشغّل المساعد البصري بالكاميرا الخلفية، وأسفله الكاميرا الأمامية، بعد اللمسة الثانية على نفس المكان. '
      'أربع ضغطات على رفع الصوت تشغّلها وواجهة التطبيق في الأمام.';

  static Future<void> offerBlindEntryIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(AccessModePreference.enabledKey) != true) return;
    if (prefs.getBool(blindEntryKey) == true) return;
    final spoken = await VoiceEngine.instance.speak(blindEntryAr);
    if (spoken.success) {
      await prefs.setBool(blindEntryKey, true);
    }
  }

  static bool shouldOffer({
    required bool alreadyOffered,
    required bool microphoneGranted,
  }) {
    return !alreadyOffered && microphoneGranted;
  }

  static Future<void> offerIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final already = prefs.getBool(prefKey) == true;
    final granted = await Permission.microphone.status;
    if (!shouldOffer(
      alreadyOffered: already,
      microphoneGranted: granted.isGranted,
    )) {
      return;
    }
    final spoken = await VoiceEngine.instance.speak(introAr);
    if (spoken.success) {
      await prefs.setBool(prefKey, true);
    }
  }
}

class FirstRunVoiceHook extends StatefulWidget {
  const FirstRunVoiceHook({super.key});

  @override
  State<FirstRunVoiceHook> createState() => _FirstRunVoiceHookState();
}

class _FirstRunVoiceHookState extends State<FirstRunVoiceHook> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirstRunVoice.offerIfNeeded();
      FirstRunVoice.offerBlindEntryIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
