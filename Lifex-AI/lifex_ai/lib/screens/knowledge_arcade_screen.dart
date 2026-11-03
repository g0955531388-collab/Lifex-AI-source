/// =============================================================
/// Lifex-AI — واجهات التطبيق
/// الملف: knowledge_arcade_screen.dart
/// رواق المعرفة: مكتبات للقراءة المحلية ورفّ تنزيل شخصي.
/// =============================================================
library lifex_ai.screens.knowledge_arcade_screen;

import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../features/education/knowledge_arcade.dart';
import '../widgets/honesty_banner.dart';
import 'child_rights_book_screen.dart';
import 'choice_mirror_screen.dart';
import 'empowerment_lab_screen.dart';
import 'personal_shelf_screen.dart';
import 'royal_intelligence_screen.dart';
import 'youth_guide_screen.dart';
import '../widgets/lifex_text.dart';

class KnowledgeArcadeScreen extends StatelessWidget {
  const KnowledgeArcadeScreen({super.key});

  void _openVolume(BuildContext context, ArcadeVolume volume) {
    final Widget page;
    switch (volume.id) {
      case 'childRights':
        page = const ChildRightsBookScreen();
        break;
      case 'choiceMirror':
        page = const ChoiceMirrorScreen();
        break;
      case 'youthGuide':
        page = const YouthGuideScreen();
        break;
      case 'royalQuiz':
        page = const RoyalIntelligenceScreen();
        break;
      case 'empowerLab':
        page = const EmpowermentLabScreen();
        break;
      case 'personalShelf':
        page = const PersonalShelfScreen();
        break;
      default:
        return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    const arcade = KnowledgeArcade();
    return Scaffold(
      appBar: AppBar(title: const LifexText(KnowledgeArcade.nameAr)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LifexText(
            AppConstants.studioBannerCredit,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          LifexText(
            KnowledgeArcade.mottoAr,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const HonestyBanner(messageAr: KnowledgeArcade.disclaimerAr),
          const SizedBox(height: 12),
          for (final library in arcade.libraries()) ...[
            LifexText(library.titleAr, style: Theme.of(context).textTheme.titleLarge),
            LifexText(library.subtitleAr, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            for (final volume in library.volumes)
              Card(
                child: ListTile(
                  leading: Icon(
                    volume.kind == ArcadeVolumeKind.downloadShelf
                        ? Icons.download_outlined
                        : volume.kind == ArcadeVolumeKind.bundledPlay
                            ? Icons.quiz_outlined
                            : Icons.menu_book_outlined,
                  ),
                  title: LifexText(volume.titleAr),
                  subtitle: LifexText(volume.blurbAr),
                  trailing: LifexText(
                    volume.readableNow ? 'اقرأ' : 'نزّل',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  onTap: () => _openVolume(context, volume),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}
