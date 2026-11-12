/// =============================================================
/// Lifex-AI — الهوية الصحية والملفات الشخصية
/// الملف: multi_profile_engine.dart
/// المسار: lib/features/profile/multi_profile_engine.dart
/// الوصف: محرك "الحسابات الصحية المتعددة" — يسمح لحساب واحد على الجهاز
/// بضم عدة ملفات صحية مستقلة (أفراد عائلة واحدة)، كل ملف بخصوصيته الكاملة.
/// =============================================================
library;

import '../../core/app_constants.dart';
import '../../core/error_handler.dart';
import '../../core/health_event_manager.dart';
import 'health_profile.dart';

/// دور صاحب الملف داخل الحساب العائلي الواحد.
enum ProfileRole {
  primaryOwner, // صاحب الحساب الرئيسي (من أنشأ الحساب)
  spouse,
  child,
  parent,
  otherRelative,
  dependent, // شخص تحت الرعاية (بدون قدرة تسجيل دخول مستقلة)
}

/// ربط بين ملف صحي ودوره داخل الحساب العائلي، بالإضافة لإعدادات
/// الوصول الخاصة به.
class FamilyProfileLink {
  final String profileId;
  final ProfileRole role;

  /// هل يملك هذا الفرد كلمة مرور/قفل مستقل لفتح ملفه فقط؟
  bool hasIndependentLock;

  DateTime addedAt;

  FamilyProfileLink({
    required this.profileId,
    required this.role,
    this.hasIndependentLock = false,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'role': role.name,
        'hasIndependentLock': hasIndependentLock,
        'addedAt': addedAt.toIso8601String(),
      };

  factory FamilyProfileLink.fromJson(Map<String, dynamic> json) =>
      FamilyProfileLink(
        profileId: json['profileId'] as String,
        role: ProfileRole.values.firstWhere(
          (e) => e.name == json['role'],
          orElse: () => ProfileRole.otherRelative,
        ),
        hasIndependentLock: json['hasIndependentLock'] as bool? ?? false,
        addedAt: DateTime.parse(json['addedAt'] as String),
      );
}

/// نتيجة عملية إضافة ملف صحي جديد للحساب.
class AddProfileResult {
  final bool success;
  final String? errorMessage;
  final FamilyProfileLink? link;

  AddProfileResult.ok(this.link)
      : success = true,
        errorMessage = null;

  AddProfileResult.failure(this.errorMessage)
      : success = false,
        link = null;
}

/// محرك إدارة الملفات الصحية المتعددة داخل حساب واحد.
///
/// كل جهاز/حساب يحمل نسخة واحدة من هذا المحرك، وهو المسؤول عن: من هم
/// الأفراد المضافون، من هو الملف النشط حالياً، وحدود العدد المسموح به.
class MultiProfileEngine {
  MultiProfileEngine({
    int? maxProfiles,
  }) : maxProfiles = maxProfiles ?? AppConstants.maxHealthProfilesDefault;

  final int maxProfiles;

  final List<FamilyProfileLink> _links = [];
  final Map<String, HealthProfile> _profilesById = {};

  String? _activeProfileId;

  /// كل الروابط العائلية المسجلة حالياً (للقراءة فقط).
  List<FamilyProfileLink> get links => List.unmodifiable(_links);

  /// معرّف الملف النشط حالياً على الجهاز.
  String? get activeProfileId => _activeProfileId;

  /// الملف الصحي النشط حالياً، إن وُجد.
  HealthProfile? get activeProfile =>
      _activeProfileId != null ? _profilesById[_activeProfileId] : null;

  /// إضافة ملف صحي جديد للحساب العائلي.
  AddProfileResult addProfile(
    HealthProfile profile, {
    required ProfileRole role,
    bool hasIndependentLock = false,
  }) {
    if (_links.length >= maxProfiles) {
      ErrorHandler.instance.report(
        'MULTI_PROFILE_LIMIT_REACHED',
        'تم الوصول إلى الحد الأقصى لعدد الملفات الصحية ($maxProfiles).',
        sourceModule: 'multi_profile_engine',
      );
      return AddProfileResult.failure(
        'الحد الأقصى لعدد الملفات هو $maxProfiles.',
      );
    }

    if (_profilesById.containsKey(profile.profileId)) {
      return AddProfileResult.failure('هذا الملف مضاف بالفعل.');
    }

    final link = FamilyProfileLink(
      profileId: profile.profileId,
      role: role,
      hasIndependentLock: hasIndependentLock,
    );

    _links.add(link);
    _profilesById[profile.profileId] = profile;

    // أول ملف يُضاف إلى الحساب يصبح النشط تلقائياً.
    _activeProfileId ??= profile.profileId;

    HealthEventManager.instance.emitQuick(
      HealthEventType.profileUpdated,
      sourceModule: 'multi_profile_engine',
      profileId: profile.profileId,
      data: {'updateType': 'profile_added_to_family', 'role': role.name},
    );

    return AddProfileResult.ok(link);
  }

  /// إزالة ملف من الحساب العائلي (لا يحذف بيانات الملف نفسه، فقط الرابط).
  bool removeProfile(String profileId) {
    final existed = _profilesById.containsKey(profileId);
    _links.removeWhere((l) => l.profileId == profileId);
    _profilesById.remove(profileId);

    if (_activeProfileId == profileId) {
      _activeProfileId = _links.isNotEmpty ? _links.first.profileId : null;
    }
    return existed;
  }

  /// التبديل إلى ملف صحي آخر داخل نفس الحساب.
  bool switchActiveProfile(String profileId) {
    if (!_profilesById.containsKey(profileId)) {
      ErrorHandler.instance.report(
        'PROFILE_NOT_FOUND',
        'محاولة التبديل إلى ملف غير موجود: $profileId',
        sourceModule: 'multi_profile_engine',
        severity: ErrorSeverity.warning,
      );
      return false;
    }
    _activeProfileId = profileId;
    return true;
  }

  /// استرجاع ملف صحي بمعرّفه.
  HealthProfile? getProfileById(String profileId) => _profilesById[profileId];

  List<HealthProfile> get allProfiles =>
      List.unmodifiable(_profilesById.values);

  /// كل الملفات التي تحمل دوراً معيناً (مثلاً كل الأطفال المسجلين).
  List<HealthProfile> profilesByRole(ProfileRole role) {
    return _links
        .where((l) => l.role == role)
        .map((l) => _profilesById[l.profileId])
        .whereType<HealthProfile>()
        .toList();
  }

  /// عدد المقاعد المتبقية قبل الوصول للحد الأقصى.
  int get remainingSlots => maxProfiles - _links.length;

  Map<String, dynamic> toJson() => {
        'activeProfileId': _activeProfileId,
        'links': _links.map((e) => e.toJson()).toList(),
        'profiles': _profilesById.values.map((e) => e.toJson()).toList(),
      };

  void restoreFromJson(Map<String, dynamic> json) {
    _links
      ..clear()
      ..addAll(
        ((json['links'] as List?) ?? [])
            .whereType<Map>()
            .map((item) =>
                FamilyProfileLink.fromJson(Map<String, dynamic>.from(item))),
      );
    _profilesById.clear();
    for (final raw in (json['profiles'] as List?) ?? []) {
      if (raw is! Map) continue;
      final profile =
          HealthProfile.fromJson(Map<String, dynamic>.from(raw));
      _profilesById[profile.profileId] = profile;
    }
    final active = json['activeProfileId'] as String?;
    if (active != null && _profilesById.containsKey(active)) {
      _activeProfileId = active;
    } else {
      _activeProfileId =
          _links.isNotEmpty ? _links.first.profileId : null;
    }
  }
}
