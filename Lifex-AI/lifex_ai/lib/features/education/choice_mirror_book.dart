/// =============================================================
/// Lifex-AI — التأهيل
/// الملف: choice_mirror_book.dart
/// كتاب «مَرآةُ الاختيار»: دليل توعوي لنضج الشراكة. ليس علاجاً زوجياً.
/// =============================================================
library lifex_ai.features.education.choice_mirror_book;

class ChoiceMirrorPrompt {
  const ChoiceMirrorPrompt({
    required this.id,
    required this.textAr,
    required this.textEn,
  });

  final String id;
  final String textAr;
  final String textEn;

  String shown({required bool english}) => english ? textEn : textAr;
}

class ChoiceMirrorChapter {
  const ChoiceMirrorChapter({
    required this.id,
    required this.kickerAr,
    required this.titleAr,
    required this.subtitleAr,
    required this.bodyAr,
    required this.bodyEn,
    required this.prompts,
  });

  final String id;
  final String kickerAr;
  final String titleAr;
  final String subtitleAr;
  final String bodyAr;
  final String bodyEn;
  final List<ChoiceMirrorPrompt> prompts;

  String spoken({required bool english}) {
    final test =
        prompts.map((p) => p.shown(english: english)).join(' ');
    if (english) {
      return '$titleAr. $bodyEn Mirror items: $test';
    }
    return '$kickerAr. $titleAr. $subtitleAr. $bodyAr. اختبار المرآة: $test';
  }

  String shownBody({required bool english}) => english ? bodyEn : bodyAr;
}

class ChoiceMirrorBook {
  const ChoiceMirrorBook();

  static const titleAr = 'مَرآةُ الاختيار';
  static const authorsAr =
      'المرشدة رباب الحايك | الكاتب غازي سليم بكفلاوي';
  static const imprintAr =
      'AlrohAcademy999 – Lifex-AI. صياغة توعوية داخل رواق المعرفة.';

  static const disclaimerAr =
      'دليل توعوي لنضج العلاقات على هذا الجهاز. ليس علاجاً زوجياً ولا '
      'تشخيصاً نفسياً ولا حكماً على شريك. الدرجات تأمل ذاتي من صفر إلى أربعة، '
      'وليست مقياساً سريرياً. عند الخطر أو العنف اطلب جهة حماية حقيقية فوراً.';

  static const disclaimerEn =
      'An educational partnership guide on this device. Not couples therapy, '
      'not a clinical diagnosis, not a verdict on a partner. Scores are self-reflection '
      'from 0 to 4. Violence needs real-world protection, not this screen.';

  /// العربية مصدر الكتاب. الإنجليزية مضمّنة. لا ترجمة آلية للغات الأخرى.
  static bool usesEnglish({
    required String appLanguageCode,
    required String deviceLanguageCode,
  }) {
    final app = appLanguageCode.toLowerCase();
    final device = deviceLanguageCode.toLowerCase();
    if (app.startsWith('en') || device.startsWith('en')) return true;
    return false;
  }

  static String shownDisclaimer({required bool english}) =>
      english ? disclaimerEn : disclaimerAr;

  List<ChoiceMirrorChapter> chapters() => const [
        ChoiceMirrorChapter(
          id: 'ch1',
          kickerAr: '01',
          titleAr: 'فلسفة الاختيار والوعي بالذات',
          subtitleAr:
              'قبل أن تختار شخصاً، اختر أن تعرف نفسك، وافهم قيمك وحدودك واحتياجاتك النفسية.',
          bodyAr:
              'يدخل الإنسان العلاقة العاطفية أو الزوجية وهو يحمل تاريخاً كاملاً من '
              'الخبرات والتوقعات والمخاوف والترسبات القديمة. لذلك فإن اختيار الشريك '
              'ليس مجرد بحث عن شخص مناسب خارج الذات، بل هو في المقام الأول اكتشاف '
              'عميق للطريقة التي نختار بها نحن، والأسباب الدفينة التي تجعلنا ننجذب '
              'لطرف دون آخر. في كثير من الأحيان نخلط بين الانجذاب الأول والتوافق '
              'الحقيقي، وبين الغيرة والحب، وبين التضحية الحقيقية وإلغاء الذات. ولا '
              'تأتي المشكلة الجوهرية من وجود المشاعر، بل من منح هذه المشاعر وحدها '
              'سلطة اتخاذ القرارات المصيرية.',
          bodyEn:
              'Choosing a partner starts with knowing your values, limits, and '
              'needs. Attraction is not the same as fit. Feelings matter, but they '
              'must not be the only vote in a life decision. This is education, not therapy.',
          prompts: [
            ChoiceMirrorPrompt(
              id: 'ch1-1',
              textAr:
                  'أعرف القواعد والقيم الأساسية التي لا أتنازل عنها في العلاقة.',
              textEn:
                  'I know the core values I will not surrender in a relationship.',
            ),
            ChoiceMirrorPrompt(
              id: 'ch1-2',
              textAr: 'أميز بوضوح بين الحاجة النفسية الحقيقية والرغبة العابرة.',
              textEn:
                  'I can tell a real psychological need from a passing want.',
            ),
            ChoiceMirrorPrompt(
              id: 'ch1-3',
              textAr: 'أعرف كيف أسيطر على سلوكي وردود فعلي عند الغضب.',
              textEn: 'I can govern my behavior when I am angry.',
            ),
            ChoiceMirrorPrompt(
              id: 'ch1-4',
              textAr:
                  'لا أعتقد أن وجود الشريك هو الحل الوحيد للشعور بالوحدة.',
              textEn:
                  'I do not treat a partner as the only cure for loneliness.',
            ),
            ChoiceMirrorPrompt(
              id: 'ch1-5',
              textAr: 'أستطيع وضع حدود واضحة وبطريقة محترمة ودون صدام.',
              textEn: 'I can set clear limits respectfully, without a fight.',
            ),
          ],
        ),
        ChoiceMirrorChapter(
          id: 'ch2',
          kickerAr: '02',
          titleAr: 'حدس الروح وواقعية التجربة',
          subtitleAr:
              'الحدس إشارة تنبيهية قوية، لكنه ليس حكماً نهائياً؛ يحتاج دائماً إلى اختبار الواقع والبيانات الملموسة.',
          bodyAr:
              'الشعور الداخلي أو الحدس هو إشارة تنبيهية قوية تستحق الاستماع '
              'والاهتمام، لكنه ليس محكمة قضائية ولا حقائق مطلقة. في بعض الأحيان '
              'يكون الحدس قراءة خاطفة ومستبصرة لمؤشرات واقعية لم يستوعبها العقل '
              'الواعي بعد، وفي أحيان أخرى يكون مجرد انعكاس للخوف القديم أو التردد '
              'الذاتي.',
          bodyEn:
              'Intuition is a useful alarm, not a court. Check it against facts '
              'and time. Old fear can wear the mask of inner certainty.',
          prompts: [
            ChoiceMirrorPrompt(
              id: 'ch2-1',
              textAr:
                  'أبحث عن الوقائع والأدلة الملموسة عندما أشعر بالقلق الداخلي.',
              textEn: 'When I feel inner alarm, I look for concrete facts.',
            ),
            ChoiceMirrorPrompt(
              id: 'ch2-2',
              textAr: 'أميز بين مشاعر الحاضر وأثر تجارب الماضي الأليمة.',
              textEn:
                  'I can separate present feeling from old painful history.',
            ),
            ChoiceMirrorPrompt(
              id: 'ch2-3',
              textAr:
                  'لا أعتبر الانجذاب العاطفي الأول دليلاً كافياً على التوافق.',
              textEn: 'First attraction is not enough proof of fit.',
            ),
          ],
        ),
        ChoiceMirrorChapter(
          id: 'ch3',
          kickerAr: '03',
          titleAr: 'تأثير المرآة وانعكاس الذات',
          subtitleAr:
              'ما يزعجك في الآخر قد يكون ضوءاً على موضع لم تُصلحه فيك بعد، وقد يكون حداً لا يجوز كسره.',
          bodyAr:
              'العلاقة مرآة لا قاعة محكمة. الغضب المتكرر من صفة في الشريك يستحق '
              'سؤالاً: أهذه صفة تمسّ قيمة لا أتنازل عنها، أم جرحاً قديماً يبحث عن '
              'شاهد؟ الانعكاس لا يُبرّر الإساءة ولا يلغي الفرق بين حدٍّ صحي وتسامح '
              'يُلغي الذات. المرآة تُظهر، وأنت تختار ماذا تُصلح في سلوكك وماذا ترفض '
              'في العلاقة بلا تجميل.',
          bodyEn:
              'A partner can reflect unfinished work in you, and can also cross '
              'a real boundary. Reflection is not an excuse for harm.',
          prompts: [
            ChoiceMirrorPrompt(
              id: 'ch3-1',
              textAr: 'أسأل نفسي ماذا يثيره فيّ سلوك الشريك قبل أن أُدينه.',
              textEn:
                  'I ask what a partner’s behavior stirs in me before I condemn.',
            ),
            ChoiceMirrorPrompt(
              id: 'ch3-2',
              textAr: 'أفرّق بين حدّ لا يُكسر وبين تفضيل قابل للتفاوض.',
              textEn: 'I tell a hard boundary from a negotiable preference.',
            ),
            ChoiceMirrorPrompt(
              id: 'ch3-3',
              textAr: 'لا أستخدم «أنت سببي» لإعفاء نفسي من مسؤوليتي.',
              textEn: 'I do not use “you made me” to drop my own responsibility.',
            ),
          ],
        ),
        ChoiceMirrorChapter(
          id: 'ch4',
          kickerAr: '04',
          titleAr: 'تشخيص المشكلات الزوجية',
          subtitleAr:
              'وصف المشكلة بدقة أرحم من الاتهام العام. الوقت والمال والأسرة واللغة والجسد ميادين منفصلة.',
          bodyAr:
              'المشكلة الزوجية تُسمّى بما يحدث لا بما نخشاه. صمتٌ بعد خلاف غير '
              'خيانة، وضغط مال غير رفض حب، وتدخل أهل غير حكم نهائي على النية. '
              'التشخيص التوعوي هنا يعني: ميدان واحد في كل مرة، مثال ملموس، طلب '
              'واضح، وزمن للمراجعة. بلا لصق مرض على الشريك وبلا محاكمة ليلية.',
          bodyEn:
              'Name the actual field: money, time, family, speech, body. One '
              'concrete example and one request beat a night of accusations. '
              'This is not a clinical diagnosis.',
          prompts: [
            ChoiceMirrorPrompt(
              id: 'ch4-1',
              textAr: 'أصف الخلاف بمثال واحد واضح لا بصفة شاملة.',
              textEn: 'I describe conflict with one clear example, not a blanket label.',
            ),
            ChoiceMirrorPrompt(
              id: 'ch4-2',
              textAr: 'أفصل بين ميدان المال وميدان العاطفة عند النقاش.',
              textEn: 'I keep money talk separate from affection talk.',
            ),
            ChoiceMirrorPrompt(
              id: 'ch4-3',
              textAr: 'أطلب تغييراً قابلاً للرصد لا اعتذاراً مفتوحاً.',
              textEn: 'I ask for a visible change, not an open-ended apology.',
            ),
          ],
        ),
        ChoiceMirrorChapter(
          id: 'ch5',
          kickerAr: '05',
          titleAr: 'التشخيص الحقيقي وأسباب الفشل',
          subtitleAr:
              'الفشل ليس قدراً غامضاً. يتكرر حين يُدار الخلاف بالكتمان أو بالإذلال أو بانتظار أن يتغيّر الآخر وحده.',
          bodyAr:
              'أسباب التآكل المتكرر أوضح من الأساطير: وعود بلا مواعيد، إنكار '
              'الأذى، استخدام الأطفال أو المال سلاحاً، ورفض طلب العون حين يتجاوز '
              'الخلاف طاقة البيت. التشخيص الحقيقي هنا توعوي: نمط يتكرر رغم التنبيه، '
              'لا اسم مرض يُلصق بالشريك. إن وُجد عنف أو تهديد فالخطوة ليست تأملاً '
              'في هذا الكتاب بل جهة حماية ومختص خارج الشاشة.',
          bodyEn:
              'Repeated harm, broken promises, and using children or money as '
              'weapons are patterns, not fate. Violence needs real protection, '
              'not a chapter score.',
          prompts: [
            ChoiceMirrorPrompt(
              id: 'ch5-1',
              textAr: 'ألاحظ إن كان الأذى نفسه يتكرر بعد الاعتذار.',
              textEn: 'I notice whether the same harm returns after an apology.',
            ),
            ChoiceMirrorPrompt(
              id: 'ch5-2',
              textAr: 'لا أنتظر أن يتحمّل الشريك وحده إصلاح ما نكسره معاً.',
              textEn: 'I do not wait for my partner alone to repair what we both break.',
            ),
            ChoiceMirrorPrompt(
              id: 'ch5-3',
              textAr:
                  'أعرف متى ينتهي التأمل ويبدأ طلب حماية أو مختص خارج التطبيق.',
              textEn:
                  'I know when reflection ends and real-world protection or a specialist begins.',
            ),
          ],
        ),
      ];

  List<ChoiceMirrorPrompt> allPrompts() =>
      [for (final chapter in chapters()) ...chapter.prompts];

  int maxScore() => allPrompts().length * 4;

  int totalScore(Map<String, int> marks) {
    var sum = 0;
    for (final prompt in allPrompts()) {
      final raw = marks[prompt.id] ?? 0;
      sum += raw.clamp(0, 4);
    }
    return sum;
  }

  String reading({required int total, required bool english}) {
    final max = maxScore();
    if (max <= 0) return english ? 'No score.' : 'لا درجة.';
    final ratio = total / max;
    if (ratio < 0.35) {
      return english
          ? 'Early reflection. The score is not a verdict on the relationship or the partner.'
          : 'تأمل أوّلي. الدرجة ليست حكماً على العلاقة ولا على الشريك.';
    }
    if (ratio < 0.7) {
      return english
          ? 'Mid-range awareness. Review one item this week only.'
          : 'وعي متوسط في المرآة. راجع بنداً واحداً هذا الأسبوع فقط.';
    }
    return english
        ? 'Clearer limits and naming. This remains education, not a compatibility certificate.'
        : 'وضوح أعلى في الحدود والوصف. يبقى الدليل توعوياً لا شهادة توافق.';
  }

  String readingAr(int total) => reading(total: total, english: false);

  List<ChoiceMirrorChapter> search(String query) {
    final needle = query.trim();
    if (needle.isEmpty) return chapters();
    return chapters()
        .where(
          (chapter) =>
              chapter.titleAr.contains(needle) ||
              chapter.bodyAr.contains(needle) ||
              chapter.subtitleAr.contains(needle) ||
              chapter.bodyEn.toLowerCase().contains(needle.toLowerCase()),
        )
        .toList();
  }
}
