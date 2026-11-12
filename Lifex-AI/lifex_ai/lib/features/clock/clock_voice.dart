/// ردود أوامر الساعة الصوتية. الوقت من ساعة الجهاز، والإيقاف يُتحقق منه قبل إعلانه.
library lifex_ai.features.clock.clock_voice;

import '../../widgets/device_wall_clock.dart';
import '../voice/voice_reply.dart';
import 'clock_chime.dart';
import 'clock_display.dart';
import 'speaking_alarm_book.dart';

class ClockVoice {
  const ClockVoice();

  VoiceReply timeReply(DateTime now) {
    const clock = DeviceWallClock();
    final local = now.toLocal();
    return VoiceReply(
      ar: '${naturalTimeArabic(local)}. ${clock.dateLabel(local)}',
      en: "It's ${naturalTimeEnglish(local)}.",
    );
  }

  static const openAlarmsReply = VoiceReply(
    ar: 'سأفتح منبهات الساعة.',
    en: 'Opening the clock alarms.',
  );

  /// لا يقول «أوقفت» إلا إذا لم يبقَ منبه يرن ولا نغمة تعمل بعد الإيقاف.
  Future<VoiceReply> stopAlarm({
    SpeakingAlarmWatch? watch,
    ClockTonePlayer? player,
  }) async {
    final alarms = watch ?? SpeakingAlarmWatch.instance;
    final tones = player ?? ClockTonePlayer.instance;
    final wasRinging = alarms.ringing.value != null || tones.playing;
    if (!wasRinging) {
      return const VoiceReply(
        ar: 'لا منبه يرن الآن.',
        en: 'No alarm is ringing now.',
      );
    }
    await alarms.stopRinging();
    if (tones.playing) await tones.stop();
    final stopped = alarms.ringing.value == null && !tones.playing;
    return stopped
        ? const VoiceReply(ar: 'أوقفت المنبه.', en: 'The alarm is stopped.')
        : const VoiceReply(
            ar: 'تعذّر إيقاف المنبه. اضغط زر إيقاف التنبيه على الشاشة.',
            en: 'The alarm could not be stopped. Press the Stop alarm button on the screen.',
          );
  }
}
