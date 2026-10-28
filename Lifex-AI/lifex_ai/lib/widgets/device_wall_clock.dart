/// ساعة الجهاز المحلية. الوقت من DateTime.now، بلا نشاط أندرويد.
library lifex_ai.widgets.device_wall_clock;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/i18n/lifex_i18n.dart';
import '../features/clock/clock_chime.dart';
import '../features/clock/speaking_alarm_book.dart';
import '../features/voice/voice_engine.dart';
import '../screens/speaking_alarm_screen.dart';
import 'lifex_text.dart';
import '../core/i18n/lifex_runtime_translator.dart';

class DeviceWallClock {
  const DeviceWallClock();

  static const weekdaysAr = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  static const monthsAr = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  String timeLabel(DateTime now) {
    final local = now.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  String spokenLabel(DateTime now) {
    final local = now.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    final time = '${two(local.hour)}:${two(local.minute)}';
    if (AppConfig.instance.defaultLanguage == AppLanguage.english) {
      return 'The time is $time.';
    }
    return 'الساعة $time. ${dateLabel(now)}';
  }

  String dateLabel(DateTime now) {
    final local = now.toLocal();
    final day = weekdaysAr[local.weekday - 1];
    final month = monthsAr[local.month - 1];
    final date = local.day.toString().padLeft(2, '0');
    return '$day، $date $month ${local.year}';
  }
}

class DeviceWallClockView extends StatefulWidget {
  const DeviceWallClockView({super.key, this.showAlarms = true});

  final bool showAlarms;

  @override
  State<DeviceWallClockView> createState() => _DeviceWallClockViewState();
}

class _DeviceWallClockViewState extends State<DeviceWallClockView>
    with SingleTickerProviderStateMixin {
  static const _clock = DeviceWallClock();
  static const _night = Color(0xFF07111F);
  static const _digit = Color(0xFF7AD7FF);
  Timer? _tick;
  DateTime _now = DateTime.now();
  var _alarmOn = false;
  var _chiming = false;
  var _chimeEpoch = 0;
  late final AnimationController _bell;

  @override
  void initState() {
    super.initState();
    _bell = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    unawaited(_loadAlarms());
  }

  Future<void> _loadAlarms() async {
    final alarms = await const SpeakingAlarmBook().load();
    if (!mounted) return;
    final on = alarms.any((alarm) => alarm.enabled);
    setState(() => _alarmOn = on);
    if (on) {
      _bell.repeat(reverse: true);
    } else {
      _bell.stop();
      _bell.value = 0;
    }
  }

  void _sync(bool visible) {
    if (!visible) {
      _tick?.cancel();
      _tick = null;
      return;
    }
    if (_tick != null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _bell.dispose();
    super.dispose();
  }

  Future<void> _announce() async {
    if (_chiming) {
      _chimeEpoch++;
      await ClockTonePlayer.instance.stop();
      await VoiceEngine.instance.interruptIfSpeaking();
      if (mounted) setState(() => _chiming = false);
      return;
    }
    final settings = await ClockChimeSettings.load();
    if (settings.order == ChimeOrder.off || !mounted) return;
    final epoch = ++_chimeEpoch;
    setState(() => _chiming = true);
    await runChime(
      order: settings.order,
      cancelled: () => epoch != _chimeEpoch,
      tone: () => ClockTonePlayer.instance
          .play(settings.toneRef, volume: settings.volume),
      speak: () async {
        final result =
            await VoiceEngine.instance.speak(_clock.spokenLabel(DateTime.now()));
        return result.success;
      },
    );
    if (mounted && epoch == _chimeEpoch) setState(() => _chiming = false);
  }

  Future<void> _openAlarms() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SpeakingAlarmScreen()),
    );
    await _loadAlarms();
  }

  @override
  Widget build(BuildContext context) {
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    _sync(visible);
    final label = _clock.timeLabel(_now);
    final face = DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0C1C31), _night],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _chiming ? _digit : const Color(0xFF1F4A73),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SizedBox(
          height: 32,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: LifexText(
              label,
              textDirection: TextDirection.ltr,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: _digit,
                fontFamily: 'monospace',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1.1,
                letterSpacing: 2,
                fontFeatures: [FontFeature.tabularFigures()],
                shadows: [Shadow(color: Color(0x803DB7FF), blurRadius: 4)],
              ),
            ),
          ),
        ),
      ),
    );
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: tr(_clock.spokenLabel(_now)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => unawaited(_announce()),
                child: face,
              ),
            ),
          ),
        ),
        if (widget.showAlarms) ...[
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: context.nav('nav.clockAlarms'),
            child: IconButton(
              tooltip: context.nav('nav.clockAlarms'),
              onPressed: () => unawaited(_openAlarms()),
              icon: AnimatedBuilder(
                animation: _bell,
                builder: (context, _) {
                  final color = _alarmOn
                      ? Color.lerp(
                          const Color(0xFFFF5A5A),
                          const Color(0xFFB00020),
                          _bell.value,
                        )!
                      : const Color(0xFF4FC3FF);
                  return Transform.scale(
                    scale: _alarmOn ? 1 + (_bell.value * 0.2) : 1,
                    child: Icon(Icons.notifications, color: color),
                  );
                },
              ),
              style: IconButton.styleFrom(
                backgroundColor: _night,
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
