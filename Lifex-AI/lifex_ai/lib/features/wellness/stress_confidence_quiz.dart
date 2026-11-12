/// =============================================================
/// Lifex-AI — أدوات الرفاهية الذاتية
/// الملف: stress_confidence_quiz.dart
/// المسار: lib/features/wellness/stress_confidence_quiz.dart
/// الوصف: أداة ترفيهية للتأمل الذاتي — تقيّم مستوى التوتر أو الثقة أثناء
/// الإجابة عن 4 أسئلة (نصاً أو صوتاً)، وتعطي ملاحظة مبسّطة وودودة.
///
/// ⚠️ توضيح صريح وإلزامي: هذه الأداة **ليست كاشف كذب** ولا أداة تشخيص
/// نفسي، ولا تدّعي قياس "الصدق" علمياً. كشف الكذب عبر الصوت أو الأسئلة
/// السريعة غير موثوق علمياً (حتى أجهزة كشف الكذب الاحترافية مثيرة
/// للجدل في دقتها)، واستخدام هذه الأداة للحكم على صدق شخص آخر (كأحد
/// أفراد العائلة) قد يُسبب ضرراً حقيقياً في العلاقات دون أي أساس علمي
/// كافٍ. هذه الأداة مخصصة فقط لتأمل المستخدم في مشاعره الخاصة، بروح
/// خفيفة، وليست حكماً على أي شخص آخر.
/// =============================================================
library;

/// نمط الإدخال المستخدم في هذه الجلسة.
enum QuizInputMode { textAnswers, voiceRecording }

/// سؤال واحد من الأسئلة الأربعة القياسية.
class SelfReflectionQuestion {
  final String id;
  final String promptAr;

  const SelfReflectionQuestion({required this.id, required this.promptAr});
}

/// الأسئلة الأربعة الثابتة — أسئلة عامة عن الشعور الحالي، مصاغة بحيث
/// لا تُفسَّر كأداة استجواب أو اتهام لأي طرف.
const List<SelfReflectionQuestion> standardQuestions = [
  SelfReflectionQuestion(
    id: 'q1',
    promptAr: 'كيف تشعر الآن بشكل عام؟ (مرتاح / متوتر قليلاً / متوتر جداً)',
  ),
  SelfReflectionQuestion(
    id: 'q2',
    promptAr: 'هل تشعر بثقة فيما ستقوله الآن؟',
  ),
  SelfReflectionQuestion(
    id: 'q3',
    promptAr: 'هل نمت جيداً الليلة الماضية؟',
  ),
  SelfReflectionQuestion(
    id: 'q4',
    promptAr: 'هل هناك شيء يشغل تفكيرك حالياً؟',
  ),
];

/// إجابة نصية واحدة على أحد الأسئلة (مقياس بسيط 1-5 بدلاً من نص حر،
/// لتفادي أي إيحاء بتحليل لغوي عميق غير موجود فعلياً).
class TextAnswer {
  final String questionId;
  final int selfRatedLevel; // 1 (منخفض) إلى 5 (مرتفع)

  const TextAnswer({required this.questionId, required this.selfRatedLevel});
}

/// خصائص صوتية سطحية للغاية (وليست تحليلاً نفسياً) تُستخرَج من تسجيل
/// اختياري — تُستخدم فقط لإثراء التجربة الترفيهية، وليست مؤشراً علمياً.
class VoiceSurfaceFeatures {
  final double averagePitchVariance; // تفاوت نبرة الصوت (0.0 - 1.0)
  final double speakingPaceScore; // سرعة الكلام النسبية (0.0 - 1.0)
  final int pauseCount; // عدد التوقفات الملحوظة أثناء الحديث

  const VoiceSurfaceFeatures({
    required this.averagePitchVariance,
    required this.speakingPaceScore,
    required this.pauseCount,
  });
}

abstract class VoiceSurfaceFeatureExtractor {
  Future<VoiceSurfaceFeatures> extractFeatures(List<int> audioBytes);
}

/// نتيجة الجلسة الترفيهية — ملاحظة ودودة وليست حكماً نهائياً.
class SelfReflectionResult {
  final String friendlySummaryAr;
  final String disclaimer;

  const SelfReflectionResult({
    required this.friendlySummaryAr,
    this.disclaimer =
        'هذه أداة ترفيهية للتأمل الذاتي فقط وليست كاشف كذب ولا أداة '
        'تشخيص نفسي أو علمي. لا تستخدمها للحكم على صدق أي شخص آخر — '
        'العلم لا يدعم كشف الكذب بهذه الطريقة، وقد يسبب ذلك أذى حقيقياً '
        'للعلاقات الإنسانية. إن كنت تشعر بتوتر مستمر يزعجك، قد يكون من '
        'المفيد التحدث مع شخص تثق به أو مختص.',
  });
}

/// محرك الجلسة الترفيهية — يقبل إما 4 إجابات نصية مقيَّمة ذاتياً، أو
/// خصائص صوتية سطحية اختيارية، وينتج ملاحظة ودودة واحدة.
class StressConfidenceQuiz {
  StressConfidenceQuiz({this.voiceFeatureExtractor});

  final VoiceSurfaceFeatureExtractor? voiceFeatureExtractor;

  /// تحليل الجلسة اعتماداً على إجابات نصية (تقييم ذاتي 1-5 لكل سؤال).
  SelfReflectionResult analyzeTextAnswers(List<TextAnswer> answers) {
    if (answers.isEmpty) {
      return const SelfReflectionResult(
        friendlySummaryAr: 'لم تُقدَّم أي إجابات بعد.',
      );
    }

    final average =
        answers.map((a) => a.selfRatedLevel).reduce((a, b) => a + b) /
            answers.length;

    final summary = average >= 4
        ? 'يبدو أن مستوى التوتر لديك مرتفع نسبياً الآن حسب تقييمك الذاتي. '
            'خذ نفساً عميقاً، وامنح نفسك لحظة راحة قصيرة إن استطعت.'
        : average >= 2.5
            ? 'تقييمك الذاتي يشير لمستوى توتر معتدل — أمر طبيعي جداً في '
                'كثير من الأحيان.'
            : 'يبدو أنك تشعر بارتياح نسبي الآن حسب إجاباتك. أخبار جيدة!';

    return SelfReflectionResult(friendlySummaryAr: summary);
  }

  /// تحليل الجلسة اعتماداً على تسجيل صوتي اختياري — خصائص سطحية فقط
  /// (نبرة/سرعة/توقفات)، وليست تحليلاً علمياً لمصداقية الكلام.
  Future<SelfReflectionResult> analyzeVoiceRecording(
    List<int> audioBytes,
  ) async {
    if (voiceFeatureExtractor == null) {
      return const SelfReflectionResult(
        friendlySummaryAr: 'ميزة تحليل الصوت غير مفعّلة حالياً.',
      );
    }

    final features = await voiceFeatureExtractor!.extractFeatures(audioBytes);

    final energeticSpeech = features.speakingPaceScore > 0.6 ||
        features.averagePitchVariance > 0.6;

    final summary = energeticSpeech
        ? 'صوتك بدا نشيطاً ومتغيّر النبرة أثناء الحديث — قد يعكس ذلك '
            'حماساً أو قليلاً من التوتر، وكلاهما طبيعي تماماً.'
        : 'صوتك بدا هادئاً ومستقراً أثناء الحديث. تجربة لطيفة!';

    return SelfReflectionResult(friendlySummaryAr: summary);
  }
}
