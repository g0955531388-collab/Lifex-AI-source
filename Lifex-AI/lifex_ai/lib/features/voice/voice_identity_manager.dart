/// =============================================================
/// Lifex-AI — وحدة الصوت والذكاء اللغوي
/// الملف: voice_identity_manager.dart
/// المسار: lib/features/voice/voice_identity_manager.dart
/// الوصف: إدارة "بصمة الصوت" لكل مستخدم داخل الحساب العائلي المتعدد
/// (multi_profile_engine.dart)، لتمييز من يتحدث حالياً دون طلب تسجيل
/// دخول يدوي في كل مرة — مفيد خصوصاً لكبار السن أو الأطفال.
///
/// ⚠️ هذه بيانات بيومترية حساسة. يجب الحصول على موافقة صريحة ومنفصلة
/// من كل مستخدم قبل تسجيل بصمة صوته، وشرح أنها تُستخدم فقط للتمييز
/// المحلي على الجهاز، مع توضيح إمكانية حذفها في أي وقت من الإعدادات.
/// =============================================================
library;

import '../../core/error_handler.dart';

/// نتيجة عملية مطابقة صوت بملف صوتي مسجَّل مسبقاً.
class VoiceMatchResult {
  final bool matched;
  final String? matchedProfileId;
  final double confidence;

  const VoiceMatchResult({
    required this.matched,
    this.matchedProfileId,
    required this.confidence,
  });
}

/// عقد أي مزوّد بصمة صوتية فعلي (Voice biometrics provider) — سيُنفَّذ
/// لاحقاً عبر مكتبة متخصصة؛ هذا الملف يوفر العقد والمنطق التنظيمي فقط.
abstract class VoiceBiometricsProvider {
  /// استخراج بصمة صوتية (Embedding) من عيّنة صوت خام.
  Future<List<double>> extractVoicePrint(List<int> audioBytes);

  /// حساب درجة تشابه بين بصمتين صوتيتين (0.0 إلى 1.0).
  double compareVoicePrints(List<double> a, List<double> b);
}

/// سجل بصمة صوت مرتبطة بملف صحي معيّن ضمن الحساب العائلي.
class VoicePrintRecord {
  final String profileId;
  final List<double> voicePrint;
  final DateTime enrolledAt;

  const VoicePrintRecord({
    required this.profileId,
    required this.voicePrint,
    required this.enrolledAt,
  });
}

/// المدير المسؤول عن تسجيل ومطابقة بصمات الصوت داخل الحساب العائلي
/// الواحد فقط (لا يقارن أبداً مع أصوات من خارج نفس الجهاز/الحساب).
class VoiceIdentityManager {
  VoiceIdentityManager({required this.biometricsProvider});

  final VoiceBiometricsProvider biometricsProvider;

  final List<VoicePrintRecord> _enrolledPrints = [];

  /// أدنى درجة تشابه لاعتبار الصوت مطابقاً لملف مسجَّل مسبقاً.
  static const double _matchConfidenceThreshold = 0.75;

  List<VoicePrintRecord> get enrolledPrints => List.unmodifiable(_enrolledPrints);

  /// تسجيل بصمة صوت جديدة لملف صحي — يتطلب أن يكون المستخدم قد وافق
  /// صراحة على هذه الميزة قبل استدعاء هذه الدالة (التحقق من الموافقة
  /// يجب أن يحدث في طبقة الواجهة قبل الوصول لهذا المدير).
  Future<bool> enrollVoice({
    required String profileId,
    required List<int> audioSample,
  }) async {
    try {
      final voicePrint = await biometricsProvider.extractVoicePrint(audioSample);

      _enrolledPrints.removeWhere((record) => record.profileId == profileId);
      _enrolledPrints.add(VoicePrintRecord(
        profileId: profileId,
        voicePrint: voicePrint,
        enrolledAt: DateTime.now(),
      ));
      return true;
    } catch (e, stackTrace) {
      ErrorHandler.instance.report(
        'VOICE_ENROLLMENT_FAILED',
        'فشل تسجيل بصمة الصوت للملف: $profileId',
        sourceModule: 'voice_identity_manager',
        exception: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// مطابقة عيّنة صوت جديدة مع كل البصمات المسجَّلة داخل نفس الحساب،
  /// وإرجاع أفضل مطابقة إن تجاوزت عتبة الثقة.
  Future<VoiceMatchResult> identifySpeaker(List<int> audioSample) async {
    if (_enrolledPrints.isEmpty) {
      return const VoiceMatchResult(matched: false, confidence: 0.0);
    }

    final candidatePrint = await biometricsProvider.extractVoicePrint(audioSample);

    String? bestProfileId;
    double bestScore = 0.0;

    for (final record in _enrolledPrints) {
      final score = biometricsProvider.compareVoicePrints(
        candidatePrint,
        record.voicePrint,
      );
      if (score > bestScore) {
        bestScore = score;
        bestProfileId = record.profileId;
      }
    }

    if (bestScore >= _matchConfidenceThreshold) {
      return VoiceMatchResult(
        matched: true,
        matchedProfileId: bestProfileId,
        confidence: bestScore,
      );
    }

    return VoiceMatchResult(matched: false, confidence: bestScore);
  }

  /// حذف بصمة صوت مستخدم معيّن (يجب توفير هذا كخيار واضح في الإعدادات
  /// امتثالاً لمبدأ التحكم الكامل للمستخدم ببياناته البيومترية).
  bool removeVoicePrint(String profileId) {
    final before = _enrolledPrints.length;
    _enrolledPrints.removeWhere((record) => record.profileId == profileId);
    return _enrolledPrints.length < before;
  }
}
