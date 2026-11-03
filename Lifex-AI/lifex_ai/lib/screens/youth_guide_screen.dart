/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: youth_guide_screen.dart
/// دليل اليافعين: فهرس، بحث، نطق، ميثاق. ليس علاجاً نفسياً.
/// =============================================================
library lifex_ai.screens.youth_guide_screen;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_constants.dart';
import '../features/education/youth_guide_book.dart';
import '../features/network_box/profile_box_store.dart';
import '../features/profile/active_profile_controller.dart';
import '../features/reports/stamped_report.dart';
import '../features/voice/voice_engine.dart';
import '../widgets/honesty_banner.dart';
import '../widgets/lifex_text.dart';
import '../core/i18n/lifex_runtime_translator.dart';

class YouthGuideScreen extends StatefulWidget {
  const YouthGuideScreen({super.key});

  @override
  State<YouthGuideScreen> createState() => _YouthGuideScreenState();
}

class _YouthGuideScreenState extends State<YouthGuideScreen> {
  static const _book = YouthGuideBook();
  String _query = '';
  bool _english = false;
  double _textScale = 1;

  Future<void> _speak(YouthChapter chapter) async {
    await VoiceEngine.instance.speak(chapter.spoken(english: _english));
  }

  void _savePact() {
    final controller = context.read<ActiveProfileController>();
    final profile = controller.activeProfile;
    if (profile == null) return;
    final pact = _book.chapters().firstWhere((c) => c.id == 'pact');
    ProfileBoxStore(profile).setString(BoxKeys.youthPact, pact.bodyAr);
    controller.saveActiveProfileChanges();
    final stamped = StampedReport(
      profile: profile,
      bodyAr: '${pact.titleAr}\n${pact.bodyAr}\n\n${YouthGuideBook.disclaimerAr}',
    ).toPlainText();
    Clipboard.setData(ClipboardData(text: stamped));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: LifexText('حُفظ ميثاق اليافع في الملف ونُسخ مختوماً.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapters = _book.search(_query);
    return Scaffold(
      appBar: AppBar(
        title: const LifexText('دليل اليافعين'),
        actions: [
          IconButton(
            tooltip: tr(_english ? 'العربية' : 'English'),
            onPressed: () => setState(() => _english = !_english),
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
          const HonestyBanner(messageAr: YouthGuideBook.disclaimerAr),
          Slider(
            value: _textScale,
            min: 0.9,
            max: 1.3,
            onChanged: (value) => setState(() => _textScale = value),
          ),
          TextField(
            decoration: InputDecoration(
              labelText: tr('بحث داخل الدليل'),
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
          const SizedBox(height: 12),
          LifexText('الفهرس', style: Theme.of(context).textTheme.titleMedium),
          Wrap(
            spacing: 8,
            children: [
              for (final chapter in _book.chapters())
                ActionChip(
                  label: LifexText(chapter.kickerAr),
                  onPressed: () => _speak(chapter),
                ),
            ],
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
                            chapter.kickerAr,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          LifexText(
                            chapter.titleAr,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          LifexText(_english ? chapter.bodyEn : chapter.bodyAr),
                          TextButton.icon(
                            onPressed: () => _speak(chapter),
                            icon: const Icon(Icons.volume_up_outlined),
                            label: const LifexText('قراءة هذا القسم'),
                          ),
                        ],
                      ),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LifexText(
                          'خريطة المهارات',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        for (final row in _book.skillMap())
                          ListTile(
                            dense: true,
                            title: LifexText(row.domainAr),
                            subtitle: LifexText('${row.skillAr}\n${row.practiceAr}'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: _savePact,
            icon: const Icon(Icons.bookmark_added_outlined),
            label: const LifexText('حفظ ميثاق اليافع في الملف'),
          ),
        ],
      ),
    );
  }
}
