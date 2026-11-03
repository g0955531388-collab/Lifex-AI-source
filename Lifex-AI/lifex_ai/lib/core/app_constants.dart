/// =============================================================
/// Lifex-AI — النواة الأساسية للنظام
/// الملف: app_constants.dart
/// المسار: lib/core/app_constants.dart
/// الوصف: الثوابت العامة المستخدمة عبر كامل التطبيق. أي قيمة ثابتة
/// يحتاجها أكثر من ملف واحد يجب أن تُعرَّف هنا وليس مكررة محلياً.
/// =============================================================

class AppConstants {
  AppConstants._(); // منع إنشاء أي كائن من هذا الكلاس

  // ---------------------------------------------------------------
  // معلومات التطبيق
  // ---------------------------------------------------------------
  static const String appName = 'Lifex-AI';
  static const String packageName = 'lifex_ai';
  static const String appVersion = '0.1.0';

  /// الختم الرسمي الدائري كما اعتمده المالك — يُعرض في الشاشة الافتتاحية
  /// وحول التطبيق دون اختصار نصوص الملكية.
  static const String officialSealAsset = 'assets/branding/lifex_seal.jpg';
  static const String officialContactEmail = 'G095553388@gmail.com';
  static const String academyHandle = 'Ghazi_Rabab_AlrohAccademy999';
  static const String academyNameAr = 'أكاديمية الروح 999';
  static const String studioBannerCredit =
      'Lifex-AI | غازي سليم بكفلاوي | G0955531388@gmail.com';

  static const String builderAttributionAr =
      'تم بناء هذا النظام بواسطة المخترع غازي سليم بكفلاوي وشريكته رباب محمود الحايك. '
      'الملكية الفكرية للمشروع مناصفة بينهما: 50% لغازي سليم بكفلاوي و50% لرباب محمود الحايك.';

  static const String humanitarianExemptionStatementAr =
      'يُعفى ذوو الإعاقة بعد بطاقة من بلد صاحب الحساب، والمرضى الدائمون '
      'في الملف، والمكفوفون: لا أجور ولا رسوم. اشتراك الأفراد 100 دولار '
      'سنوياً عادي بلا إعلانات ولا خدمات خاصة. الوحدة الصحية 300 والمستشفى 600.';

  /// نص الإسناد والملكية الرسمي — يجب عرضه في كل شاشة "حول التطبيق"،
  /// كل بانر ترحيبي/شاشة افتتاحية (Splash)، وكل رسالة صادرة من النظام
  /// (طوارئ، تراسل، شهادات تبرع) التي تحمل توقيعاً أو تذييلاً رسمياً.
  /// لا يجوز تعديل هذا النص أو اختصاره في أي مكان يظهر فيه.
  static const String ownershipStatement =
      'المالكان المشتركان لمنظومة Lifex-AI هما غازي سليم بكفلاوي ورباب محمود الحايك '
      'بحصتين متساويتين: 50% لكل منهما. يتمتع كلاهما بصفة المالك وصلاحيات الإدارة '
      'والتكوين والتطوير والتشغيل على قدم المساواة، مع بقاء خصوصية المرضى '
      'وسلامة السجلات والموافقات الطبية ضوابط مستقلة واجبة الاحترام.';

  /// نص مختصر يُستخدم في الأماكن الضيقة (تذييل رسالة، شريط سفلي) حيث
  /// لا تتسع المساحة للنص الكامل أعلاه.
  static const String ownershipStatementShort =
      'Lifex-AI — ملكية مناصفة: 50% لغازي سليم بكفلاوي و50% لرباب محمود الحايك.';

  static const String developerCredit = 'غازي سليم بكفلاوي والمرشدة رباب الحايك';

  // ---------------------------------------------------------------
  // حساب المالك (Owner) — يُستخدم حصرياً لتفعيل صلاحية المالك تلقائياً
  // في GlobalAdminManager عند تسجيل الدخول بأحد هذين المعرّفين. لا يُستخدم
  // لأي غرض آخر، ولا يجوز أن يمنح أي مستخدم آخر نفسه هذه الصلاحية.
  // ---------------------------------------------------------------
  static const String ownerEmail = 'g0955531388@gmail.com';
  static const String ownerPhoneNumber = '+963955531388';
  static const List<String> ownerEmails = [
    'g0955531388@gmail.com',
    'G095553388@gmail.com',
  ];

  // ---------------------------------------------------------------
  // الترخيص
  // ---------------------------------------------------------------
  /// الشهر المجاني للمشترك الجديد: خدمات أقل من الكاملة.
  static const int trialPeriodDays = 30;

  /// نسخة الإهداء من مشترك نظامي: مرة واحدة، ثم تتوقف حتى التخصيص.
  static const int giftCopyDays = 15;

  // ---------------------------------------------------------------
  // الحسابات والملفات الصحية
  // ---------------------------------------------------------------
  static const int maxHealthProfilesDefault = 8;
  static const int minUserAgeYears = 0;
  static const int maxUserAgeYears = 130;

  // ---------------------------------------------------------------
  // اللغات المدعومة (أكواد ISO 639-1)
  // ---------------------------------------------------------------
  static const String defaultLanguageCode = 'ar';
  static const List<String> supportedLanguageCodes = ['ar', 'en'];

  // ---------------------------------------------------------------
  // مستويات الخطورة الموحدة (تُستخدم في الطوارئ، التبرعات، التنبيهات)
  // ---------------------------------------------------------------
  static const String riskLevelLow = 'low';
  static const String riskLevelMedium = 'medium';
  static const String riskLevelHigh = 'high';
  static const String riskLevelCritical = 'critical';

  // ---------------------------------------------------------------
  // حدود زمنية عامة
  // ---------------------------------------------------------------
  static const int defaultSessionTimeoutMinutes = 30;
  static const int emergencyResponseTimeoutSeconds = 60;

  // ---------------------------------------------------------------
  // مفاتيح التخزين المحلي (Keys) — تُستخدم مع أي طبقة تخزين لاحقاً
  // ---------------------------------------------------------------
  static const String storageKeyLicense = 'lifex_license';
  static const String storageKeyAppConfig = 'lifex_app_config';
  static const String storageKeyActiveProfileId = 'lifex_active_profile_id';
  static const String storageKeyLastSyncTimestamp = 'lifex_last_sync_ts';
}
