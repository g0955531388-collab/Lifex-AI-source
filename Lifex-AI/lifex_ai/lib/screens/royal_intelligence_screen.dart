/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: royal_intelligence_screen.dart
/// تمرين ملكي: وضع، مؤقّت، نطق، تصحيح محلي. ليس مقياس ذكاء.
/// =============================================================
library lifex_ai.screens.royal_intelligence_screen;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../features/education/royal_intelligence.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/reports/stamped_report.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/honesty_banner.dart';
import '../widgets/lifex_text.dart';
import '../core/i18n/lifex_runtime_translator.dart';

class RoyalIntelligenceScreen extends StatefulWidget {
  const RoyalIntelligenceScreen({super.key});

  @override
  State<RoyalIntelligenceScreen> createState() =>
      _RoyalIntelligenceScreenState();
}

class _RoyalIntelligenceScreenState extends State<RoyalIntelligenceScreen> {
  bool _childMode = false;
  bool _shuffle = false;
  bool _useTimer = false;
  RoyalIntelligenceSession? _session;
  RoyalScore? _score;
  int _current = 0;
  Timer? _tick;
  String _clock = 'بدون مؤقّت';

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _say(String text) async {
    await VoiceEngine.instance.speak(text);
  }

  void _start() {
    _tick?.cancel();
    setState(() {
      _session = RoyalIntelligenceSession.start(
        childMode: _childMode,
        shuffle: _shuffle,
        useTimer: _useTimer,
      );
      _score = null;
      _current = 0;
      _clock = _session!.clockLabel(DateTime.now());
    });
    _say(
      _childMode
          ? 'بدأ تمرين الأطفال في المنصة الملكية.'
          : 'بدأ تمرين الكبار في المنصة الملكية.',
    );
    if (_useTimer) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        final session = _session;
        if (session == null) return;
        final now = DateTime.now();
        setState(() => _clock = session.clockLabel(now));
        if (session.timedOut(now) && _score == null) {
          _grade(speakTimeout: true);
        }
      });
    }
  }

  void _reset() {
    _tick?.cancel();
    setState(() {
      _session = null;
      _score = null;
      _clock = _useTimer ? '15:00' : 'بدون مؤقّت';
    });
    _say('أُعيد التمرين.');
  }

  void _grade({bool speakTimeout = false}) {
    final session = _session;
    if (session == null) return;
    _tick?.cancel();
    final score = session.grade();
    setState(() => _score = score);
    final controller = context.read<ActiveProfileController>();
    final profile = controller.activeProfile;
    if (profile != null) {
      ProfileBoxStore(profile).setString(
        BoxKeys.royalIntelligenceLast,
        '${score.correct}/${score.total} ${score.percent}%',
      );
      controller.saveActiveProfileChanges();
    }
    _say(
      speakTimeout
          ? 'انتهى الوقت. ${score.labelAr}'
          : 'النتيجة ${score.correct} من ${score.total}. ${score.labelAr}',
    );
  }

  void _save() {
    final session = _session;
    final controller = context.read<ActiveProfileController>();
    final profile = controller.activeProfile;
    if (session == null || profile == null) return;
    final stamped = StampedReport(
      profile: profile,
      bodyAr: session.reportAr(),
    ).toPlainText();
    Clipboard.setData(ClipboardData(text: stamped));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: LifexText('نُسخ التقرير المختوم. ليست شهادة ذكاء رسمية.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(
        title: const LifexText('المنصة الملكية'),
        actions: [
          IconButton(
            tooltip: tr('إيقاف النطق'),
            onPressed: () => VoiceEngine.instance.stopListening(),
            icon: const Icon(Icons.stop),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: () => _say(AppConstants.studioBannerCredit),
            child: LifexText(
              'اختبار ملكي — ${AppConstants.studioBannerCredit}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          const HonestyBanner(messageAr: RoyalIntelligenceBank.disclaimerAr),
          SwitchListTile(
            title: const LifexText('وضع الأطفال'),
            value: _childMode,
            onChanged: _session == null
                ? (value) => setState(() => _childMode = value)
                : null,
          ),
          SwitchListTile(
            title: const LifexText('خلط الأسئلة'),
            value: _shuffle,
            onChanged: _session == null
                ? (value) => setState(() => _shuffle = value)
                : null,
          ),
          SwitchListTile(
            title: const LifexText('مؤقّت ١٥ دقيقة'),
            value: _useTimer,
            onChanged: _session == null
                ? (value) => setState(() => _useTimer = value)
                : null,
          ),
          LifexText('الوقت: $_clock'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(onPressed: _start, child: const LifexText('بدء التمرين')),
              OutlinedButton(
                onPressed: session == null
                    ? null
                    : () => _say(session.speakItem(_current)),
                child: const LifexText('نطق السؤال'),
              ),
              OutlinedButton(
                onPressed: session == null ? null : () => _grade(),
                child: const LifexText('تصحيح'),
              ),
              OutlinedButton(onPressed: _reset, child: const LifexText('إعادة')),
              OutlinedButton(
                onPressed: session == null ? null : _save,
                child: const LifexText('نسخ النتيجة'),
              ),
            ],
          ),
          if (_score != null) ...[
            const SizedBox(height: 12),
            LifexText(
              'النتيجة: ${_score!.correct} من ${_score!.total} (${_score!.percent}%)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            LifexText(_score!.labelAr),
            LinearProgressIndicator(value: _score!.percent / 100),
          ],
          if (session != null) ...[
            const SizedBox(height: 16),
            for (var i = 0; i < session.items.length; i++) ...[
              if (i % RoyalIntelligenceBank.stageSize == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: LifexText(
                    'المرحلة ${(i ~/ RoyalIntelligenceBank.stageSize) + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              Card(
                color: _current == i
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LifexText('سؤال ${i + 1}: ${session.items[i].promptAr}'),
                      const SizedBox(height: 8),
                      for (var o = 0;
                          o < session.items[i].options.length;
                          o++)
                        RadioListTile<int>(
                          dense: true,
                          title: LifexText(session.items[i].options[o]),
                          value: o,
                          groupValue: session.picks[i],
                          onChanged: _score != null
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _current = i;
                                    session.pick(i, value);
                                  });
                                  _say(
                                    session.immediateCorrect(i)
                                        ? 'أحسنت. إجابة صحيحة.'
                                        : 'حاول مجدداً. إجابة غير المعتمدة في التمرين.',
                                  );
                                },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
