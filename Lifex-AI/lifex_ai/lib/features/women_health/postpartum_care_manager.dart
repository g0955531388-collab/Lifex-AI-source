/// =============================================================
/// Lifex-AI — رعاية النساء والحمل
/// الملف: postpartum_care_manager.dart
/// المسار: lib/features/women_health/postpartum_care_manager.dart
/// الوصف: متابعة فترة ما بعد الولادة (النفاس) — تعافي الأم جسدياً،
/// متابعة الرضاعة، ورصد مؤشرات اكتئاب ما بعد الولادة المحتملة لتوجيه
/// الأم لدعم متخصص دون تشخيصها.
///
/// ⚠️ حساسية خاصة: أي إشارة لاحتمال اكتئاب ما بعد الولادة يجب أن تُعرض
/// بلطف شديد مع توجيه فوري لأخصائي، دون استخدام ألفاظ تشخيصية قد تخيف
/// المستخدمة أو تُشعرها بالحكم عليها.
/// =============================================================
library;

import '../../core/health_event_manager.dart';
import 'women_health_manager.dart';

/// نوع الرضاعة الحالي.
enum FeedingMethod { exclusiveBreastfeeding, mixedFeeding, formulaFeeding }

/// سجل يومي بسيط لفترة ما بعد الولادة.
class PostpartumDailyLog {
  final DateTime recordedAt;
  final FeedingMethod? feedingMethod;

  /// إجابات مبسّطة (نعم/لا) على أسئلة استرشادية عامة حول المزاج — هذه
  /// ليست أداة تشخيصية رسمية (مثل مقياس إدنبرة)، بل مؤشر أولي بسيط.
  final bool? feelingOverwhelmed;
  final bool? feelingDisconnectedFromBaby;
  final bool? hasSupportAtHome;

  const PostpartumDailyLog({
    required this.recordedAt,
    this.feedingMethod,
    this.feelingOverwhelmed,
    this.feelingDisconnectedFromBaby,
    this.hasSupportAtHome,
  });
}

/// نتيجة تقييم لطيف لمؤشرات المزاج بعد الولادة.
class PostpartumMoodCheckResult {
  final bool suggestsProfessionalSupport;
  final String messageAr;

  const PostpartumMoodCheckResult({
    required this.suggestsProfessionalSupport,
    required this.messageAr,
  });
}

/// مدير متابعة فترة ما بعد الولادة.
class PostpartumCareManager {
  PostpartumCareManager({required this.womenHealthManager});

  final WomenHealthManager womenHealthManager;
  final Map<String, List<PostpartumDailyLog>> _logsByProfileId = {};

  /// تسجيل سجل يومي جديد وتقييم مؤشرات المزاج بلطف.
  PostpartumMoodCheckResult recordDailyLog({
    required String profileId,
    required PostpartumDailyLog log,
  }) {
    _logsByProfileId.putIfAbsent(profileId, () => []).add(log);

    final recentLogs = _logsByProfileId[profileId]!;
    final last7Days = recentLogs.length > 7
        ? recentLogs.sublist(recentLogs.length - 7)
        : recentLogs;

    final overwhelmedCount =
        last7Days.where((l) => l.feelingOverwhelmed == true).length;
    final disconnectedCount =
        last7Days.where((l) => l.feelingDisconnectedFromBaby == true).length;

    // إشارة لطيفة فقط، وليست تشخيصاً: تكرار مشاعر الإرهاق الشديد أو
    // الانفصال العاطفي لعدة أيام متتالية يستحق دعماً متخصصاً.
    final suggestsSupport = overwhelmedCount >= 4 || disconnectedCount >= 3;

    if (suggestsSupport) {
      HealthEventManager.instance.emitQuick(
        HealthEventType.profileUpdated,
        sourceModule: 'postpartum_care_manager',
        profileId: profileId,
        data: {'updateType': 'postpartum_support_suggested'},
      );

      return const PostpartumMoodCheckResult(
        suggestsProfessionalSupport: true,
        messageAr:
            'كثير من الأمهات يمررن بمشاعر مرهقة بعد الولادة، وهذا لا يعني '
            'أنك أم غير كافية. قد يكون من المفيد التحدث مع طبيبتك أو '
            'أخصائي دعم نفسي متخصص برعاية ما بعد الولادة — هذا اهتمام '
            'بصحتك أنتِ أيضاً، وليس فقط بصحة طفلك.',
      );
    }

    return const PostpartumMoodCheckResult(
      suggestsProfessionalSupport: false,
      messageAr: 'تم تسجيل بيانات اليوم. اعتني بنفسك كما تعتنين بطفلك.',
    );
  }

  /// إنهاء فترة النفاس والعودة لمتابعة الدورة الشهرية العادية (عادة بعد
  /// 6-8 أسابيع، يُحدَّد فعلياً بموعد طبيب المتابعة).
  void concludePostpartumPeriod(String profileId) {
    womenHealthManager.returnToCycleTracking(profileId);
  }

  List<PostpartumDailyLog> historyFor(String profileId) =>
      List.unmodifiable(_logsByProfileId[profileId] ?? const []);
}
