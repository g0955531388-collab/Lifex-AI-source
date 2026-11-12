/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: choice_mirror_screen.dart
/// كتاب مرآة الاختيار: قراءة ونطق ودرجات تأمل محلية.
/// =============================================================
library lifex_ai.screens.choice_mirror_screen;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_config.dart';
import '../core/app_constants.dart';
import '../features/education/choice_mirror_book.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/reports/stamped_report.dart';
import '../features/voice/voice_engine.dart';
import '../features/voice/voice_locale_policy.dart';
import '../widgets/honesty_banner.dart';
import '../widgets/lifex_text.dart';
import '../core/i18n/lifex_runtime_translator.dart';

class ChoiceMirrorScreen extends StatefulWidget {
  const ChoiceMirrorScreen({super.key});

  @override
  State<ChoiceMirrorScreen> createState() => _ChoiceMirrorScreenState();
}

class _ChoiceMirrorScreenState extends State<ChoiceMirrorScreen> {
  static const _book = ChoiceMirrorBook();
  String _query = '';
  bool _english = false;
  bool _languagePinned = false;
  double _textScale = 1;
  final _strength = TextEditingController();
  final _weekly = TextEditingController();

  @override
  void initState() {
    super.initState();
    final profile = context.read<ActiveProfileController>().activeProfile;
    if (profile == null) return;
    final journal = ProfileBoxStore(profile).map(BoxKeys.choiceMirrorJournal);
    _strength.text = journal['strengthAr']?.toString() ?? '';
    _weekly.text = journal['weeklyAr']?.toString() ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_languagePinned) return;
    final appCode =
        AppConfig.instance.defaultLanguage == AppLanguage.english ? 'en' : 'ar';
    final device = const VoiceLocalePolicy().deviceLocale().languageCode;
    final next = ChoiceMirrorBook.usesEnglish(
      appLanguageCode: appCode,
      deviceLanguageCode: device,
    );
    if (next != _english) {
      _english = next;
    }
  }

  @override
  void dispose() {
    _strength.dispose();
    _weekly.dispose();
    super.dispose();
  }

  Map<String, int> _marks() {
    final profile = context.read<ActiveProfileController>().activeProfile;
    if (profile == null) return {};
    final raw =
        ProfileBoxStore(profile).map(BoxKeys.choiceMirrorJournal)['marks'];
    if (raw is! Map) return {};
    return raw.map(
      (key, value) => MapEntry(key.toString(), int.tryParse('$value') ?? 0),
    );
  }

  void _setMark(String id, int value) {
    final controller = context.read<ActiveProfileController>();
    final profile = controller.activeProfile;
    if (profile == null) return;
    final store = ProfileBoxStore(profile);
    final journal = Map<String, dynamic>.from(store.map(BoxKeys.choiceMirrorJournal));
    final marks = Map<String, dynamic>.from(
      journal['marks'] is Map ? journal['marks'] as Map : {},
    );
    marks[id] = value.clamp(0, 4);
    journal['marks'] = marks;
    store.setMap(BoxKeys.choiceMirrorJournal, journal);
    controller.saveActiveProfileChanges();
    setState(() {});
  }

  void _saveJournal() {
    final controller = context.read<ActiveProfileController>();
    final profile = controller.activeProfile;
    if (profile == null) return;
    final store = ProfileBoxStore(profile);
    final journal = Map<String, dynamic>.from(store.map(BoxKeys.choiceMirrorJournal));
    journal['strengthAr'] = _strength.text.trim();
    journal['weeklyAr'] = _weekly.text.trim();
    store.setMap(BoxKeys.choiceMirrorJournal, journal);
    controller.saveActiveProfileChanges();
    final marks = _marks();
    final total = _book.totalScore(marks);
    final stamped = StampedReport(
      profile: profile,
      bodyAr:
          '${ChoiceMirrorBook.titleAr}\n${ChoiceMirrorBook.authorsAr}\n'
          'درجة التأمل: $total من ${_book.maxScore()}\n${_book.readingAr(total)}\n'
          'قوة: ${_strength.text.trim()}\nخطوة الأسبوع: ${_weekly.text.trim()}\n\n'
          '${ChoiceMirrorBook.disclaimerAr}',
    ).toPlainText();
    Clipboard.setData(ClipboardData(text: stamped));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: LifexText('حُفظ دفتر المرآة في الملف ونُسخ مختوماً. ليست شهادة توافق.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapters = _book.search(_query);
    final marks = _marks();
    final total = _book.totalScore(marks);
    return Scaffold(
      appBar: AppBar(
        title: const LifexText(ChoiceMirrorBook.titleAr),
        actions: [
          IconButton(
            tooltip: tr(_english ? 'العربية' : 'English'),
            onPressed: () => setState(() {
              _languagePinned = true;
              _english = !_english;
            }),
            icon: const Icon(Icons.translate),
          ),
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
          LifexText(
            AppConstants.studioBannerCredit,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          const LifexText(
            ChoiceMirrorBook.authorsAr,
            textAlign: TextAlign.center,
          ),
          LifexText(
            ChoiceMirrorBook.imprintAr,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          HonestyBanner(
            messageAr: ChoiceMirrorBook.shownDisclaimer(english: _english),
          ),
          Slider(
            value: _textScale,
            min: 0.9,
            max: 1.3,
            onChanged: (value) => setState(() => _textScale = value),
          ),
          TextField(
            decoration: InputDecoration(
              labelText: tr(_english ? 'Search this book' : 'بحث داخل الكتاب'),
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
          const SizedBox(height: 8),
          LifexText(
            _english
                ? 'Reflection score: $total of ${_book.maxScore()} — ${_book.reading(total: total, english: true)}'
                : 'درجة التأمل: $total من ${_book.maxScore()} — ${_book.reading(total: total, english: false)}',
          ),
          const SizedBox(height: 12),
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(_textScale),
            ),
            child: Column(
              children: [
                for (final chapter in chapters)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LifexText(
                            'الفصل ${chapter.kickerAr}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          LifexText(
                            chapter.titleAr,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          LifexText(chapter.subtitleAr),
                          const SizedBox(height: 8),
                          LifexText(chapter.shownBody(english: _english)),
                          TextButton.icon(
                            onPressed: () => VoiceEngine.instance.speak(
                              chapter.spoken(english: _english),
                            ),
                            icon: const Icon(Icons.volume_up_outlined),
                            label: LifexText(
                              _english ? 'Read this chapter' : 'قراءة هذا الفصل',
                            ),
                          ),
                          LifexText(
                            _english
                                ? 'Mirror items (0 to 4)'
                                : 'اختبار المرآة (0 إلى 4)',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          for (final prompt in chapter.prompts) ...[
                            LifexText(prompt.shown(english: _english)),
                            Slider(
                              value: (marks[prompt.id] ?? 0).clamp(0, 4).toDouble(),
                              min: 0,
                              max: 4,
                              divisions: 4,
                              label: '${marks[prompt.id] ?? 0}',
                              onChanged: (value) =>
                                  _setMark(prompt.id, value.round()),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          TextField(
            controller: _strength,
            decoration: InputDecoration(
              labelText: tr(_english
                  ? 'My strongest point'
                  : 'أكثر نقطة قوة أتمتع بها'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _weekly,
            decoration: InputDecoration(
              labelText: tr(_english
                  ? 'Practical change this week'
                  : 'السلوك العملي للتغيير هذا الأسبوع'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saveJournal,
            icon: const Icon(Icons.bookmark_added_outlined),
            label: LifexText(
              _english
                  ? 'Save the journal and copy a stamped note'
                  : 'حفظ دفتر المرآة ونسخه مختوماً',
            ),
          ),
        ],
      ),
    );
  }
}
