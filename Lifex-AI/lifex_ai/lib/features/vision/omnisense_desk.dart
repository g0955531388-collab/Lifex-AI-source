/// بوابة OmniSense داخل Flutter. لا عمق ولا كتلة ولا تشخيص من صورة عادية،
/// ولا إرسال إطار بلا موافقة وخادم رمز قصير العمر.
library lifex_ai.features.vision.omnisense_desk;

import '../accessibility/blind_scene_brief.dart';

enum PhysicalReadingState { unknown, measured }

/// قراءة فيزيائية. [measured] لا تُستخدم في هذا البناء: لا حسّاس عمق ولا ميزان.
class PhysicalReading {
  const PhysicalReading({
    required this.state,
    required this.spokenAr,
    this.value,
  });

  final PhysicalReadingState state;
  final String spokenAr;
  final double? value;

  bool get announcedAsMeasurement =>
      state == PhysicalReadingState.measured && value != null;
}

enum OmniSenseLinkPhase {
  unconfigured,
  awaitingConsent,
  connected,
  failed,
  unavailable,
}

class OmniSenseLink {
  const OmniSenseLink({
    required this.phase,
    required this.spokenAr,
    required this.framesLeaveDevice,
    required this.attributedToGemini,
  });

  final OmniSenseLinkPhase phase;
  final String spokenAr;
  final bool framesLeaveDevice;
  final bool attributedToGemini;
}

/// لون أو تباين. يبقى ملاحظة، والتشخيص السريري فارغ.
class AppearanceObservation {
  const AppearanceObservation({
    required this.spokenAr,
    this.redRatio,
    this.contrast,
    this.clinicalDiagnosis,
  });

  final String spokenAr;
  final double? redRatio;
  final double? contrast;
  final String? clinicalDiagnosis;
}

class OmniSenseDesk {
  const OmniSenseDesk._();

  /// خادم يصدر رمزاً قصير العمر خارج التطبيق. غير موجود في هذا البناء.
  static const tokenServerRequiredAr =
      'إرسال الإطار يحتاج خادماً يصدر رمزاً قصير العمر ولا يخزّن مفتاحاً داخل التطبيق. '
      'هذا الخادم غير مربوط، فالصورة تبقى على الجهاز.';

  static const absentDepthSpokenAr =
      'المسافة Unknown. لا حسّاس عمق ولا زمن رحلة من العتاد على هذا المسار. '
      'وميض الفلاش (GFRS، اختراع غازي سليم بكفلاوي) ليس قياساً، '
      'وفرق الإضاءة لا يُعلن مسافة. يمكنك استخدام كشف العوائق مع العصا البيضاء.';

  static const absentMassSpokenAr =
      'الكتلة Unknown. لا ميزان ولا قياس كثافة على هذا المسار. '
      'اللون لا يتحول إلى قياس.';

  static PhysicalReading absentDepth() {
    return const PhysicalReading(
      state: PhysicalReadingState.unknown,
      spokenAr: absentDepthSpokenAr,
    );
  }

  /// [hardwareSensorAvailable] يبقى false إلى أن يقرأ مسارٌ زمن رحلة من حسّاس.
  /// معادلة الزمن ليست ذلك الحسّاس، وصورة RGB ليست عمقاً.
  static PhysicalReading depth({
    double? meters,
    required bool hardwareSensorAvailable,
  }) {
    if (!hardwareSensorAvailable ||
        meters == null ||
        !meters.isFinite ||
        meters < 0) {
      return absentDepth();
    }
    return PhysicalReading(
      state: PhysicalReadingState.measured,
      value: meters,
      spokenAr: 'قراءة عمق من الحسّاس: $meters.',
    );
  }

  static PhysicalReading mass({
    double? kilograms,
    required bool scaleAvailable,
  }) {
    if (!scaleAvailable ||
        kilograms == null ||
        !kilograms.isFinite ||
        kilograms < 0) {
      return const PhysicalReading(
        state: PhysicalReadingState.unknown,
        spokenAr: absentMassSpokenAr,
      );
    }
    return PhysicalReading(
      state: PhysicalReadingState.measured,
      value: kilograms,
      spokenAr: 'قراءة الميزان: $kilograms.',
    );
  }

  static AppearanceObservation appearance({
    double? redRatio,
    double? contrast,
  }) {
    return AppearanceObservation(
      redRatio: redRatio,
      contrast: contrast,
      spokenAr:
          'ملاحظة بصرية: لون أو تباين في الإطار. هذه ليست تشخيصاً.',
    );
  }

  /// فلاش الهاتف لا يُضمَّن عند 3000 أو 3500 هرتز. الشريط المعلن ليس قدرة.
  static bool phoneFlashHzAvailable(double hertz) => false;

  static String flashHzSpokenAr(double hertz) {
    return 'تردد ${hertz.toStringAsFixed(0)} هرتز غير متاح على فلاش هذا الهاتف.';
  }

  static String failureSpeech() => BlindSceneBrief.noAnalysisAr;

  static String localWhenCloudOff(Iterable<SceneHit> hits) {
    final line = BlindSceneBrief.classificationSpeech(hits);
    if (line.isEmpty) return BlindSceneBrief.noAnalysisAr;
    return 'تصنيف صورة لا كشف أجسام: $line';
  }

  /// كشف الأجسام، والنص المقروء، والرمز تبقى ثلاث قنوات.
  static String composeLocalSpeech({
    required String scene,
    required String recognizedText,
    List<String> barcodes = const [],
  }) {
    final spoken = [scene, recognizedText]
        .where((part) => part.trim().isNotEmpty)
        .join('\n');
    final codes = [
      for (final code in barcodes)
        if (code.trim().isNotEmpty) code.trim(),
    ];
    if (codes.isEmpty) return spoken;
    final codesLine =
        'الرموز: ${codes.join('، ')}. هذا نص الرمز وليس تفسيراً لدواء.';
    if (spoken.isEmpty) return codesLine;
    return '$spoken\n$codesLine';
  }

  /// لا جلسة Gemini في هذا البناء. نص ثابت أو علم من المستدعي لا يُنسب إليها.
  static OmniSenseLink link({
    required bool endpointConfigured,
    required bool frameLeaveConsent,
    bool? online,
  }) {
    if (!frameLeaveConsent) {
      return const OmniSenseLink(
        phase: OmniSenseLinkPhase.awaitingConsent,
        spokenAr:
            'الإطار لم يُرسل. مغادرة الصورة للجهاز تحتاج موافقة محددة. '
            'الوصف المحلي مستمر.',
        framesLeaveDevice: false,
        attributedToGemini: false,
      );
    }
    if (online == false) {
      return const OmniSenseLink(
        phase: OmniSenseLinkPhase.unavailable,
        spokenAr:
            'لا اتصال. لم تُرسل صورة، ولا رد سحابي. الوصف المحلي مستمر.',
        framesLeaveDevice: false,
        attributedToGemini: false,
      );
    }
    if (!endpointConfigured) {
      return const OmniSenseLink(
        phase: OmniSenseLinkPhase.unconfigured,
        spokenAr:
            'المسار السحابي غير مربوط بمفتاح أو خادم. لم تُرسل صورة. '
            'الوصف المحلي مستمر.',
        framesLeaveDevice: false,
        attributedToGemini: false,
      );
    }
    return const OmniSenseLink(
      phase: OmniSenseLinkPhase.unavailable,
      spokenAr: tokenServerRequiredAr,
      framesLeaveDevice: false,
      attributedToGemini: false,
    );
  }
}
