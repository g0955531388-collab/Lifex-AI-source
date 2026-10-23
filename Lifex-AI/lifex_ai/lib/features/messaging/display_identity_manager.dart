/// =============================================================
/// Lifex-AI — التراسل والاتصالات الاجتماعية
/// الملف: display_identity_manager.dart
/// المسار: lib/features/messaging/display_identity_manager.dart
/// الوصف: تحديد الاسم/الهوية الظاهرة في الدردشة حسب سياق المحادثة —
/// اسم حقيقي مع طبيب موثوق، اسم مستعار مع متبرع غير معروف شخصياً.
/// =============================================================
library;

enum DisplayIdentityMode { realName, aliasOnly, anonymous }

class DisplayIdentitySetting {
  final String profileId;
  final String contextKey; // مثال: "doctor_context" أو "donor_context"
  DisplayIdentityMode mode;
  final String? aliasName;

  DisplayIdentitySetting({
    required this.profileId,
    required this.contextKey,
    required this.mode,
    this.aliasName,
  });
}

/// مدير الهوية الظاهرة.
class DisplayIdentityManager {
  DisplayIdentityManager();

  final Map<String, DisplayIdentitySetting> _settings = {};

  String _key(String profileId, String contextKey) => '$profileId::$contextKey';

  void setIdentityMode({
    required String profileId,
    required String contextKey,
    required DisplayIdentityMode mode,
    String? aliasName,
  }) {
    _settings[_key(profileId, contextKey)] = DisplayIdentitySetting(
      profileId: profileId,
      contextKey: contextKey,
      mode: mode,
      aliasName: aliasName,
    );
  }

  /// الاسم الذي يجب عرضه فعلياً حسب السياق، مع افتراض آمن (مستعار) إن
  /// لم يُحدَّد المستخدم إعداداً صريحاً.
  String resolveDisplayName({
    required String profileId,
    required String contextKey,
    required String realName,
  }) {
    final setting = _settings[_key(profileId, contextKey)];

    if (setting == null) return 'مستخدم Lifex-AI'; // افتراضي آمن

    switch (setting.mode) {
      case DisplayIdentityMode.realName:
        return realName;
      case DisplayIdentityMode.aliasOnly:
        return setting.aliasName ?? 'مستخدم Lifex-AI';
      case DisplayIdentityMode.anonymous:
        return 'مستخدم مجهول';
    }
  }
}
