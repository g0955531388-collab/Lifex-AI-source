/// =============================================================
/// Lifex-AI — نقطة تشغيل واحدة للمساعد.
/// عبارة الاستعداد تُنطق بعد نجاح النطق فقط، ومرة واحدة في العملية.
/// =============================================================
library lifex_ai.features.voice.assistant_session;

import 'voice_engine.dart';
import 'voice_turn_desk.dart';

class AssistantSession {
  AssistantSession._();

  static final AssistantSession instance = AssistantSession._();

  static const readyAr = 'تم تشغيل المساعد البصري. تفضل، أنا جاهز، Lifex-AI.';

  static const readyFallbackAr =
      'تعذر النطق. الأزرار وقارئ الشاشة يبقيان متاحين. '
      'تحقق من محرك النطق في إعدادات الجهاز.';

  bool announced = false;
  String? problemAr;
  double outputVolume = 1;
  double speechRate = 0.5;
  String? heldReading;

  /// يحفظ النص المعروض قبل الإيقاف حتى يعود أمر «تابع القراءة» إليه.
  void holdForResume(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.startsWith('أوقفت القراءة')) return;
    heldReading = trimmed;
  }

  String? takeHeldReading() {
    final text = heldReading?.trim();
    heldReading = null;
    if (text == null || text.isEmpty) return null;
    return text;
  }

  void slowSpeech() {
    final next = speechRate - 0.1;
    speechRate = next < 0.2 ? 0.2 : next;
  }

  void raiseSpeech() {
    final next = speechRate + 0.1;
    speechRate = next > 1 ? 1 : next;
  }

  void Function()? repeatSight;
  void Function()? pauseSight;
  void Function()? resumeSight;
  Future<void> Function(VoiceTurn turn)? applySightTurn;

  Future<void> announceReady(VoiceEngine engine) async {
    if (announced) return;
    final result = await engine.speak(readyAr);
    if (!result.success) {
      problemAr = result.errorMessageAr ?? readyFallbackAr;
      return;
    }
    announced = true;
    problemAr = null;
  }

  void raiseVolume() {
    final next = outputVolume + 0.25;
    outputVolume = next > 1 ? 1 : next;
  }

  void bindSight({
    void Function()? repeat,
    void Function()? pause,
    void Function()? resume,
    Future<void> Function(VoiceTurn turn)? applyTurn,
  }) {
    repeatSight = repeat;
    pauseSight = pause;
    resumeSight = resume;
    applySightTurn = applyTurn;
  }

  void unbindSight() {
    repeatSight = null;
    pauseSight = null;
    resumeSight = null;
    applySightTurn = null;
  }
}
