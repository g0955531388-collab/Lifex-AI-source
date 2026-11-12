/// إعلان الوقت باللمس من أي واجهة للساعة، ونطق المنبه التالي. إعلان واحد في كل مرة.
library lifex_ai.features.clock.clock_announcer;

import 'package:flutter/foundation.dart';

import '../../core/app_config.dart';
import '../../widgets/device_wall_clock.dart';
import '../voice/voice_engine.dart';
import '../voice/voice_reply.dart';
import 'clock_chime.dart';
import 'clock_display.dart';
import 'speaking_alarm_book.dart';

class ClockAnnouncer {
  ClockAnnouncer._();

  static final ClockAnnouncer instance = ClockAnnouncer._();

  final ValueNotifier<bool> chiming = ValueNotifier<bool>(false);
  int _epoch = 0;

  /// لمسة أثناء الإعلان توقفه؛ لمسة أخرى تبدأ إعلاناً جديداً.
  Future<void> toggle() async {
    if (chiming.value) {
      await stop();
      return;
    }
    final settings = await ClockChimeSettings.load();
    if (settings.order == ChimeOrder.off) return;
    final epoch = ++_epoch;
    chiming.value = true;
    await runChime(
      order: settings.order,
      cancelled: () => epoch != _epoch,
      tone: () => ClockTonePlayer.instance
          .play(settings.toneRef, volume: settings.volume),
      speak: () async {
        final result = await VoiceEngine.instance
            .speak(const DeviceWallClock().spokenLabel(DateTime.now()));
        return result.success;
      },
    );
    if (epoch == _epoch) chiming.value = false;
  }

  Future<void> stop() async {
    _epoch++;
    chiming.value = false;
    await ClockTonePlayer.instance.stop();
    await VoiceEngine.instance.interruptIfSpeaking();
  }

  Future<void> speakNextAlarm() async {
    final alarms = await const SpeakingAlarmBook().load();
    final reply = nextAlarmReply(alarms, DateTime.now());
    final english = AppConfig.instance.defaultLanguage == AppLanguage.english;
    await VoiceEngine.instance.speak(english ? reply.en : reply.ar);
  }
}

DateTime? nextAlarmAt(SpeakingAlarm alarm, DateTime now) {
  if (!alarm.enabled) return null;
  final local = now.toLocal();
  var at = DateTime(local.year, local.month, local.day, alarm.hour, alarm.minute);
  if (!at.isAfter(local)) at = at.add(const Duration(days: 1));
  return at;
}

VoiceReply nextAlarmReply(List<SpeakingAlarm> alarms, DateTime now) {
  SpeakingAlarm? best;
  DateTime? bestAt;
  for (final alarm in alarms) {
    final at = nextAlarmAt(alarm, now);
    if (at == null) continue;
    if (bestAt == null || at.isBefore(bestAt)) {
      best = alarm;
      bestAt = at;
    }
  }
  if (best == null || bestAt == null) {
    return const VoiceReply(ar: 'لا منبه مفعّل.', en: 'No alarm is on.');
  }
  return VoiceReply(
    ar: 'المنبه التالي ${best.name}، ${naturalTimeArabic(bestAt)}.',
    en: 'Next alarm: ${best.name}, ${naturalTimeEnglish(bestAt)}.',
  );
}
