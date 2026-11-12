/// =============================================================
/// Lifex-AI — التراسل والاتصالات الاجتماعية
/// الملف: privacy_ghost_mode.dart
/// المسار: lib/features/messaging/privacy_ghost_mode.dart
/// الوصف: وضع "الإخفاء الكامل" — إخفاء حالة الاتصال (متصل الآن/آخر
/// ظهور) وإشعارات القراءة عن الطرف الآخر بالكامل.
/// =============================================================
library;

class GhostModeSettings {
  bool hideOnlineStatus;
  bool hideLastSeen;
  bool hideReadReceipts;

  GhostModeSettings({
    this.hideOnlineStatus = false,
    this.hideLastSeen = false,
    this.hideReadReceipts = false,
  });

  bool get isFullyActive =>
      hideOnlineStatus && hideLastSeen && hideReadReceipts;
}

/// مدير وضع الإخفاء الكامل لكل ملف صحي.
class PrivacyGhostMode {
  PrivacyGhostMode();

  final Map<String, GhostModeSettings> _settings = {};

  GhostModeSettings settingsFor(String profileId) {
    return _settings.putIfAbsent(profileId, () => GhostModeSettings());
  }

  void enableFullGhostMode(String profileId) {
    _settings[profileId] = GhostModeSettings(
      hideOnlineStatus: true,
      hideLastSeen: true,
      hideReadReceipts: true,
    );
  }

  void disableFullGhostMode(String profileId) {
    _settings[profileId] = GhostModeSettings();
  }

  bool shouldShowOnlineStatus(String profileId) =>
      !settingsFor(profileId).hideOnlineStatus;

  bool shouldShowLastSeen(String profileId) =>
      !settingsFor(profileId).hideLastSeen;

  bool shouldShowReadReceipts(String profileId) =>
      !settingsFor(profileId).hideReadReceipts;
}
