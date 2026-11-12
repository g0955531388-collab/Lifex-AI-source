/// =============================================================
/// Lifex-AI — التراسل والاتصالات الاجتماعية
/// الملف: messaging_permissions_manager.dart
/// المسار: lib/features/messaging/messaging_permissions_manager.dart
/// الوصف: من يُسمح له بمراسلة من — قائمة حظر، وقيود على من يمكنه بدء
/// محادثة جديدة (مثلاً منع الغرباء تماماً من مراسلة حساب طفل).
/// =============================================================
library;

class MessagingPermissionsManager {
  MessagingPermissionsManager();

  final Map<String, Set<String>> _blockLists = {};

  /// حسابات مسموح لها ببدء محادثة حتى مع من لم يوافق عليهم صراحة —
  /// افتراضياً فارغة (Opt-in) لحماية الحسابات الحساسة مثل حسابات الأطفال.
  final Map<String, bool> _allowMessagesFromStrangers = {};

  void blockUser({required String profileId, required String blockedLifexId}) {
    _blockLists.putIfAbsent(profileId, () => {}).add(blockedLifexId);
  }

  void unblockUser({required String profileId, required String blockedLifexId}) {
    _blockLists[profileId]?.remove(blockedLifexId);
  }

  bool isBlocked({required String profileId, required String otherLifexId}) {
    return _blockLists[profileId]?.contains(otherLifexId) ?? false;
  }

  void setAllowStrangers(String profileId, bool allow) {
    _allowMessagesFromStrangers[profileId] = allow;
  }

  bool allowsMessagesFromStrangers(String profileId) {
    return _allowMessagesFromStrangers[profileId] ?? false;
  }

  /// التحقق الشامل: هل يُسمح لـ [senderLifexId] ببدء محادثة مع
  /// [recipientProfileId]؟
  bool canSendMessage({
    required String senderLifexId,
    required String recipientProfileId,
    required bool isExistingContact,
  }) {
    if (isBlocked(profileId: recipientProfileId, otherLifexId: senderLifexId)) {
      return false;
    }
    if (isExistingContact) return true;
    return allowsMessagesFromStrangers(recipientProfileId);
  }
}
