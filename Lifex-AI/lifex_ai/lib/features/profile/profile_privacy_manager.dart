/// =============================================================
/// Lifex-AI — الهوية الصحية والملفات الشخصية
/// الملف: profile_privacy_manager.dart
/// المسار: lib/features/profile/profile_privacy_manager.dart
/// الوصف: التحكم الدقيق في من يرى ماذا من بيانات الملف الصحي. هذا الملف
/// هو نقطة العبور الإلزامية لأي وحدة تريد قراءة/عرض بيانات صحية لمستخدم
/// آخر (طبيب، صيدلية، عائلة، متبرع...).
/// =============================================================
library;

/// الفئات التي يمكن منحها مستوى وصول مختلف لبيانات الملف الصحي.
enum ViewerCategory {
  self, // صاحب الملف نفسه
  family,
  approvedDoctor,
  hospital,
  pharmacy,
  laboratory,
  emergencyResponder,
  donor,
  publicSearch, // أي شخص يبحث عبر المنصة بدون علاقة مسبقة
}

/// مستوى تفصيل البيانات الممنوح لفئة معيّنة.
enum DataVisibilityLevel {
  none, // لا يرى شيئاً إطلاقاً
  aliasOnly, // يرى الاسم المستعار فقط بدون أي بيانات صحية
  basicInfo, // معلومات عامة غير حساسة (مثلاً وجود حالة طوارئ فقط)
  medicalSummary, // ملخص طبي (حساسية، فصيلة دم، حالات مزمنة)
  fullAccess, // وصول كامل لكل تفاصيل الملف الصحي
}

/// قاعدة خصوصية واحدة: أي فئة → أي مستوى ظهور.
class PrivacyRule {
  final ViewerCategory category;
  DataVisibilityLevel visibilityLevel;

  PrivacyRule({
    required this.category,
    required this.visibilityLevel,
  });

  Map<String, dynamic> toJson() => {
        'category': category.name,
        'visibilityLevel': visibilityLevel.name,
      };

  factory PrivacyRule.fromJson(Map<String, dynamic> json) => PrivacyRule(
        category: ViewerCategory.values.firstWhere(
          (e) => e.name == json['category'],
        ),
        visibilityLevel: DataVisibilityLevel.values.firstWhere(
          (e) => e.name == json['visibilityLevel'],
        ),
      );
}

/// الإعدادات الافتراضية المتّبعة عند إنشاء ملف صحي جديد — آمنة بشكل
/// افتراضي (Privacy by default): لا أحد يرى شيئاً حساساً إلا بموافقة
/// صريحة من المستخدم، باستثناء حالات الطوارئ التي تحصل على ملخص طبي
/// أساسي فقط لإنقاذ الحياة.
class ProfilePrivacyManager {
  ProfilePrivacyManager({
    required this.profileId,
    List<PrivacyRule>? initialRules,
  }) {
    if (initialRules != null) {
      for (final rule in initialRules) {
        _rules[rule.category] = rule;
      }
    } else {
      _applyDefaultRules();
    }
  }

  final String profileId;
  final Map<ViewerCategory, PrivacyRule> _rules = {};

  void _applyDefaultRules() {
    _rules[ViewerCategory.self] = PrivacyRule(
      category: ViewerCategory.self,
      visibilityLevel: DataVisibilityLevel.fullAccess,
    );
    _rules[ViewerCategory.family] = PrivacyRule(
      category: ViewerCategory.family,
      visibilityLevel: DataVisibilityLevel.medicalSummary,
    );
    _rules[ViewerCategory.approvedDoctor] = PrivacyRule(
      category: ViewerCategory.approvedDoctor,
      visibilityLevel: DataVisibilityLevel.fullAccess,
    );
    _rules[ViewerCategory.hospital] = PrivacyRule(
      category: ViewerCategory.hospital,
      visibilityLevel: DataVisibilityLevel.medicalSummary,
    );
    _rules[ViewerCategory.pharmacy] = PrivacyRule(
      category: ViewerCategory.pharmacy,
      visibilityLevel: DataVisibilityLevel.basicInfo,
    );
    _rules[ViewerCategory.laboratory] = PrivacyRule(
      category: ViewerCategory.laboratory,
      visibilityLevel: DataVisibilityLevel.basicInfo,
    );
    // الاستجابة للطوارئ تحصل دائماً على ملخص طبي أساسي على الأقل،
    // لأن هذا قد ينقذ حياة المستخدم — لا يجوز أن يكون none هنا.
    _rules[ViewerCategory.emergencyResponder] = PrivacyRule(
      category: ViewerCategory.emergencyResponder,
      visibilityLevel: DataVisibilityLevel.medicalSummary,
    );
    _rules[ViewerCategory.donor] = PrivacyRule(
      category: ViewerCategory.donor,
      visibilityLevel: DataVisibilityLevel.aliasOnly,
    );
    _rules[ViewerCategory.publicSearch] = PrivacyRule(
      category: ViewerCategory.publicSearch,
      visibilityLevel: DataVisibilityLevel.none,
    );
  }

  /// كل القواعد الحالية (للقراءة فقط).
  List<PrivacyRule> get rules => List.unmodifiable(_rules.values);

  /// تحديث مستوى الظهور لفئة معينة. يمنع تخفيض صلاحيات
  /// [ViewerCategory.emergencyResponder] إلى أقل من [medicalSummary]
  /// حمايةً لسلامة المستخدم في حالات الطوارئ.
  bool setVisibility(ViewerCategory category, DataVisibilityLevel level) {
    if (category == ViewerCategory.emergencyResponder &&
        level.index < DataVisibilityLevel.medicalSummary.index) {
      return false;
    }
    _rules[category] = PrivacyRule(category: category, visibilityLevel: level);
    return true;
  }

  /// الاستعلام: ما هو مستوى الظهور الممنوح لفئة معينة؟
  DataVisibilityLevel visibilityFor(ViewerCategory category) {
    return _rules[category]?.visibilityLevel ?? DataVisibilityLevel.none;
  }

  /// هل يُسمح لفئة معينة برؤية مستوى معين على الأقل من التفاصيل؟
  bool isAllowed(ViewerCategory category, DataVisibilityLevel requiredLevel) {
    final granted = visibilityFor(category);
    return granted.index >= requiredLevel.index;
  }

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'rules': _rules.values.map((r) => r.toJson()).toList(),
      };

  factory ProfilePrivacyManager.fromJson(Map<String, dynamic> json) {
    final rules = (json['rules'] as List<dynamic>)
        .map((e) => PrivacyRule.fromJson(e as Map<String, dynamic>))
        .toList();
    return ProfilePrivacyManager(
      profileId: json['profileId'] as String,
      initialRules: rules,
    );
  }
}

/// سجل قواعد الخصوصية لكل ملف صحي — يُبقي الإعدادات حيّة بين الشاشات
/// بدل إعادة ضبطها للافتراضي عند كل فتح لشاشة الخصوصية.
class ProfilePrivacyRegistry {
  ProfilePrivacyRegistry._internal();
  static final ProfilePrivacyRegistry instance =
      ProfilePrivacyRegistry._internal();

  final Map<String, ProfilePrivacyManager> _byProfileId = {};

  ProfilePrivacyManager forProfile(String profileId) {
    return _byProfileId.putIfAbsent(
      profileId,
      () => ProfilePrivacyManager(profileId: profileId),
    );
  }

  /// إعادة السجل لحالته الأولية — للاختبارات فقط.
  void resetForTesting() {
    _byProfileId.clear();
  }
}
