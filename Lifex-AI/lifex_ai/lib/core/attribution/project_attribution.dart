/// =============================================================
/// Lifex-AI — الإسناد الرسمي للمشروع
/// الملف: project_attribution.dart
/// المسار: lib/core/attribution/project_attribution.dart
/// الوصف: المصدر الوحيد المعتمد لنص الإسناد والملكية. أي شاشة أو تذييل
/// أو رسالة رسمية يجب أن تقرأ من هنا (عبر AppConstants) دون إعادة صياغة.
///
/// قواعد ملزمة:
/// - المالك والمخترع: غازي سليم بكفلاوي فقط.
/// - المرشدة رباب الحايك: صفة إرشاد فقط، وليست مالكة ولا مخترعة ولا
///   شريكة في الملكية ما لم يصدر توجيه صريح من المالك.
/// - ممنوع: ورثة، مواريث، خلفاء، شركاء مفترضون، مالكون سابقون، أسماء
///   مولّدة آلياً، أو أي إضافة مستنتَجة من Git أو الحساب أو الاشتراك.
/// - الإسناد لا يتغيّر بالاشتراك ولا بالحساب الإداري ولا بالذكاء الاصطناعي.
/// =============================================================
library lifex_ai.core.attribution.project_attribution;

/// إسناد مشروع Lifex-AI — ثابت، قابل للتدقيق، وغير قابل للتغيير من
/// طبقات التشغيل (اشتراك، أدوار إدارية، AI، بيانات عائلية، جهاز، Git).
abstract final class ProjectAttribution {
  ProjectAttribution._();

  static const String inventorOwnerAr = 'غازي سليم بكفلاوي';
  static const String inventorOwnerEn = 'Ghazi Salim Bekfalawi';
  static const String inventorTitleAr = 'خبير الهندسة الطبية الحيوية';
  static const String inventorTitleEn = 'Biomedical Engineering Expert';
  static const String guideAr = 'رباب الحايك';
  static const String guideEn = 'Rabab Al-Hayek';
  static const String guideRoleAr = 'المرشدة';
  static const String guideRoleEn = 'Guide';

  /// الصيغة العربية الرسمية الوحيدة للإسناد.
  static const String officialStatementAr =
      'Lifex-AI\n'
      'المالك والمخترع: غازي سليم بكفلاوي\n'
      'خبير الهندسة الطبية الحيوية\n'
      'المرشدة: رباب الحايك';

  /// الصيغة الإنجليزية الرسمية الوحيدة للإسناد.
  static const String officialStatementEn =
      'Lifex-AI\n'
      'Inventor & Owner: Ghazi Salim Bekfalawi\n'
      'Biomedical Engineering Expert\n'
      'Guide: Rabab Al-Hayek';

  /// صيغة سطر واحد للأماكن الضيقة — نفس المعنى الرسمي بلا أسماء إضافية.
  static const String officialStatementShortAr =
      'Lifex-AI — المالك والمخترع: غازي سليم بكفلاوي | المرشدة: رباب الحايك';

  static const String officialStatementShortEn =
      'Lifex-AI — Inventor & Owner: Ghazi Salim Bekfalawi | Guide: Rabab Al-Hayek';

  /// كلمات/صيغ محظورة في نص الإسناد الرسمي (حراسة اختبارات).
  static const List<String> forbiddenAttributionFragments = [
    'ورثته',
    'ورثة',
    'مواريث',
    'خلفاء',
    'وأسرته',
    'رنا ناعسة',
    'فاطمة غازي',
    'هادي غازي',
    'مريم غازي',
    'المالك الفعلي لهذا النظام كل من',
    'حقوق الملكية الفكرية للسيد غازي سليم بكفلاوي والسيدة',
    'شركاء مفترضون',
    'مالكون سابقون',
    'مؤسسون إضافيون',
  ];

  /// يتحقق أن النص لا يحتوي صيغ إسناد محظورة.
  static bool containsForbiddenFragment(String text) {
    for (final fragment in forbiddenAttributionFragments) {
      if (text.contains(fragment)) return true;
    }
    return false;
  }
}
