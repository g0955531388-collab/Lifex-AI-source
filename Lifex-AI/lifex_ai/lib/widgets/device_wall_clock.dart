/// ساعة الجهاز المحلية. الوقت من DateTime.now، بلا نشاط أندرويد.
library lifex_ai.widgets.device_wall_clock;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/i18n/lifex_i18n.dart';
import '../features/clock/clock_announcer.dart';
import '../features/clock/clock_display.dart';
import '../features/clock/speaking_alarm_book.dart';
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

  /// نطق طبيعي: «الساعة الواحدة والربع مساءً» لا «13:15».
  String spokenLabel(DateTime now) {
    if (AppConfig.instance.defaultLanguage == AppLanguage.english) {
      return "It's ${naturalTimeEnglish(now)}.";
    }
    return '${naturalTimeArabic(now)}. ${dateLabel(now)}';
  }

  String dateLabel(DateTime now) {
    final local = now.toLocal();
    final day = weekdaysAr[local.weekday - 1];
    final month = monthsAr[local.month - 1];
    final date = local.day.toString().padLeft(2, '0');
    return '$day، $date $month ${local.year}';
  }
}

bool _arabicUi() => AppConfig.instance.defaultLanguage != AppLanguage.english;

/// أرقام الساعة بنفس النمط في الشريط وفي الشاشة الكاملة.
class ClockDigits extends StatelessWidget {
  const ClockDigits({
    super.key,
    required this.now,
    required this.settings,
    required this.fontSize,
  });

  final DateTime now;
  final ClockDisplaySettings settings;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final arabic = _arabicUi();
    final palette = ClockPalette.of(settings.mode);
    final label = clockFaceLabel(
      now,
      use24h: settings.use24h,
      seconds: settings.showSeconds,
      eastern: settings.easternDigits(arabicUi: arabic),
      arabicUi: arabic,
    );
    final style = TextStyle(
      color: palette.digit,
      fontFamily: 'monospace',
      fontSize: fontSize,
      fontWeight: settings.mode == ClockFaceMode.lowVision
          ? FontWeight.w900
          : FontWeight.w700,
      height: 1.1,
      letterSpacing: 2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          LifexText(
            label.digits,
            textDirection: TextDirection.ltr,
            maxLines: 1,
            softWrap: false,
            style: style,
          ),
          if (label.suffix.isNotEmpty) ...[
            SizedBox(width: fontSize * 0.2),
            LifexText(
              label.suffix,
              maxLines: 1,
              softWrap: false,
              style: style.copyWith(fontSize: fontSize * 0.45, letterSpacing: 0),
            ),
          ],
        ],
      ),
    );
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
  Timer? _tick;
  DateTime _now = DateTime.now();
  var _alarmOn = false;
  var _display = const ClockDisplaySettings();
  late final AnimationController _bell;

  @override
  void initState() {
    super.initState();
    _bell = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    unawaited(_loadAlarms());
    unawaited(_loadDisplay());
  }

  Future<void> _loadDisplay() async {
    final display = await ClockDisplaySettings.load();
    if (mounted) setState(() => _display = display);
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

  Future<void> _openAlarms() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SpeakingAlarmScreen()),
    );
    await _loadAlarms();
    await _loadDisplay();
  }

  Future<void> _openFullScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ClockFullScreen()),
    );
    await _loadDisplay();
  }

  @override
  Widget build(BuildContext context) {
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    _sync(visible);
    final palette = ClockPalette.of(_display.mode);
    final face = ValueListenableBuilder<bool>(
      valueListenable: ClockAnnouncer.instance.chiming,
      builder: (context, chiming, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: palette.face,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: chiming ? palette.digit : palette.border,
            width: chiming ? 2.5 : 1.5,
          ),
        ),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: SizedBox(
          height: 32,
          child: Center(
            child: ClockDigits(now: _now, settings: _display, fontSize: 28),
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
            hint: lifexUi(
              'المس لسماع الوقت، والمس مطولاً لفتح الساعة بملء الشاشة',
              'Tap to hear the time, long-press for the full-screen clock',
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => unawaited(ClockAnnouncer.instance.toggle()),
                onLongPress: () => unawaited(_openFullScreen()),
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

/// الساعة بملء الشاشة: لمس أي مكان ينطق، لمستان تكبّران حتى 3x، اللمس المطوّل ينطق المنبه التالي.
class ClockFullScreen extends StatefulWidget {
  const ClockFullScreen({super.key});

  @override
  State<ClockFullScreen> createState() => _ClockFullScreenState();
}

class _ClockFullScreenState extends State<ClockFullScreen> {
  static const _clock = DeviceWallClock();
  Timer? _tick;
  DateTime _now = DateTime.now();
  var _display = const ClockDisplaySettings();
  var _zoom = 1;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    final display = await ClockDisplaySettings.load();
    if (mounted) setState(() => _display = display);
  }

  @override
  void dispose() {
    _tick?.cancel();
    unawaited(ClockAnnouncer.instance.stop());
    super.dispose();
  }

  void _cycleZoom() {
    setState(() => _zoom = _zoom >= 3 ? 1 : _zoom + 1);
  }

  @override
  Widget build(BuildContext context) {
    final palette = ClockPalette.of(_display.mode);
    final base = _display.mode == ClockFaceMode.lowVision ? 96.0 : 72.0;
    return Scaffold(
      backgroundColor: palette.face,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Semantics(
                button: true,
                label: tr(_clock.spokenLabel(_now)),
                hint: lifexUi(
                  'المس لسماع الوقت، لمستان للتكبير، واللمس المطوّل للمنبه التالي',
                  'Tap to hear the time, double-tap to zoom, long-press for the next alarm',
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(ClockAnnouncer.instance.toggle()),
                  onDoubleTap: _cycleZoom,
                  onLongPress: () =>
                      unawaited(ClockAnnouncer.instance.speakNextAlarm()),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ClockDigits(
                        now: _now,
                        settings: _display,
                        fontSize: base * _zoom,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: 4,
              start: 4,
              child: IconButton(
                tooltip: lifexUi('إغلاق الساعة', 'Close the clock'),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                color: palette.digit,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
