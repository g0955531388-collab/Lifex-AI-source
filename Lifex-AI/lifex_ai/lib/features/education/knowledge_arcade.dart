/// =============================================================
/// Lifex-AI — التأهيل
/// الملف: knowledge_arcade.dart
/// رواق المعرفة: مكتبات باسم واضح. كتب مقروءة محلياً، ورفّ تنزيل صادق.
/// =============================================================
library lifex_ai.features.education.knowledge_arcade;

enum ArcadeVolumeKind {
  bundledRead,
  bundledPlay,
  downloadShelf,
}

class ArcadeVolume {
  const ArcadeVolume({
    required this.id,
    required this.titleAr,
    required this.blurbAr,
    required this.kind,
  });

  final String id;
  final String titleAr;
  final String blurbAr;
  final ArcadeVolumeKind kind;

  bool get readableNow => kind != ArcadeVolumeKind.downloadShelf;
}

class ArcadeLibrary {
  const ArcadeLibrary({
    required this.id,
    required this.titleAr,
    required this.subtitleAr,
    required this.volumes,
  });

  final String id;
  final String titleAr;
  final String subtitleAr;
  final List<ArcadeVolume> volumes;
}

/// اسم القسم والمكتبات كما تظهر في الصندوق.
class KnowledgeArcade {
  const KnowledgeArcade();

  static const nameAr = 'رواق المعرفة';
  static const nameEn = 'Lifex Knowledge Arcade';
  static const mottoAr =
      'بعض الكتب تُقرأ هنا فوراً. بعضها يُستدعى من الإنترنت ويُنزَّل إلى جهازك، '
      'فيصير جزءاً من مكتبتك حتى تبقيه أو تحذفه.';
  static const disclaimerAr =
      'الرواق توعوي محلي. ليس مكتبة جامعية ولا تشخيصاً ولا فتوى. '
      'التنزيل يحفظ ملفاً نصياً على جهازك فقط بعد نجاح الاتصال. لا نجاح وهمي.';

  List<ArcadeLibrary> libraries() => const [
        ArcadeLibrary(
          id: 'family',
          titleAr: 'مكتبة الأسرة',
          subtitleAr: 'حقوق الطفل وميثاق البيت',
          volumes: [
            ArcadeVolume(
              id: 'childRights',
              titleAr: 'كتاب حقوق الطفل',
              blurbAr: 'من قبل الحمل إلى الشباب. قراءة محلية واستماع.',
              kind: ArcadeVolumeKind.bundledRead,
            ),
            ArcadeVolume(
              id: 'choiceMirror',
              titleAr: 'مَرآةُ الاختيار',
              blurbAr:
                  'دليل توعوي لنضج الشراكة. إعداد المرشدة رباب الحايك والكاتب غازي سليم بكفلاوي. عرض عربي أو إنجليزي حسب لغة الجهاز أو التطبيق. ليس علاجاً زوجياً ولا إسناداً لملكية Lifex-AI.',
              kind: ArcadeVolumeKind.bundledRead,
            ),
          ],
        ),
        ArcadeLibrary(
          id: 'youth',
          titleAr: 'مكتبة اليافعين',
          subtitleAr: 'من وعي الذات إلى خطوة المستقبل',
          volumes: [
            ArcadeVolume(
              id: 'youthGuide',
              titleAr: 'دليل اليافعين',
              blurbAr: 'هوية، انفعال، رقم، أسرة، وطلب مساعدة. قصص مركّبة لا ملفات مرضى.',
              kind: ArcadeVolumeKind.bundledRead,
            ),
          ],
        ),
        ArcadeLibrary(
          id: 'royal',
          titleAr: 'منصة الذكاء الملكي',
          subtitleAr: 'تمرين أنماط للكبار والصغار',
          volumes: [
            ArcadeVolume(
              id: 'royalQuiz',
              titleAr: 'الاختبار الملكي',
              blurbAr: 'خمسون سؤالاً محلياً. ليس مقياس ذكاء سريري.',
              kind: ArcadeVolumeKind.bundledPlay,
            ),
          ],
        ),
        ArcadeLibrary(
          id: 'empower',
          titleAr: 'موسوعة التمكين',
          subtitleAr: 'قيمة وعمل محلي',
          volumes: [
            ArcadeVolume(
              id: 'empowerLab',
              titleAr: 'فصول التمكين',
              blurbAr: 'استماع وميثاق على الجهاز. ليست استشارة مالية.',
              kind: ArcadeVolumeKind.bundledRead,
            ),
          ],
        ),
        ArcadeLibrary(
          id: 'shelf',
          titleAr: 'رفّ التحميل الشخصي',
          subtitleAr: 'استدعاء كتاب من رابط آمن إلى الجهاز',
          volumes: [
            ArcadeVolume(
              id: 'personalShelf',
              titleAr: 'تنزيل أو حذف',
              blurbAr: 'https فقط، نص مقروء، يبقى عندك أو يُمسح بطلبك.',
              kind: ArcadeVolumeKind.downloadShelf,
            ),
          ],
        ),
      ];

  ArcadeLibrary? byId(String id) {
    for (final library in libraries()) {
      if (library.id == id) return library;
    }
    return null;
  }

  int bundledReadableCount() => libraries()
      .expand((library) => library.volumes)
      .where((volume) => volume.readableNow)
      .length;
}
