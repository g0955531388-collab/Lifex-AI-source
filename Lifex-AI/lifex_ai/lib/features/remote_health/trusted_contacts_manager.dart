/// =============================================================
/// Lifex-AI — المراقبة الصحية عن بعد
/// الملف: trusted_contacts_manager.dart
/// المسار: lib/features/remote_health/trusted_contacts_manager.dart
/// الوصف: إدارة قائمة جهات الثقة لكل مستخدم — من يُبلَّغ في حالات
/// الطوارئ، ومن يُسمح له بالمراقبة عن بعد، بمستويات صلاحية مختلفة.
/// =============================================================
library;

enum TrustedContactPermission {
  emergencyNotifyOnly, // يُبلَّغ فقط عند الطوارئ، لا مراقبة يومية
  remoteMonitoring, // يمكنه رؤية ملخص صحي دوري
  fullDelegate, // وصول موسّع (مثلاً لولي أمر قاصر أو شخص معتمد كلياً)
}

class TrustedContact {
  final String contactLifexId;
  final String displayName;
  TrustedContactPermission permission;
  final DateTime addedAt;

  TrustedContact({
    required this.contactLifexId,
    required this.displayName,
    required this.permission,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();
}

/// مدير جهات الثقة لملف صحي واحد.
class TrustedContactsManager {
  TrustedContactsManager({required this.profileId});

  final String profileId;
  final List<TrustedContact> _contacts = [];

  List<TrustedContact> get contacts => List.unmodifiable(_contacts);

  void addContact(TrustedContact contact) {
    _contacts.removeWhere((c) => c.contactLifexId == contact.contactLifexId);
    _contacts.add(contact);
  }

  bool removeContact(String contactLifexId) {
    final before = _contacts.length;
    _contacts.removeWhere((c) => c.contactLifexId == contactLifexId);
    return _contacts.length < before;
  }

  bool updatePermission(
    String contactLifexId,
    TrustedContactPermission newPermission,
  ) {
    final contact = _contacts
        .where((c) => c.contactLifexId == contactLifexId)
        .toList();
    if (contact.isEmpty) return false;
    contact.first.permission = newPermission;
    return true;
  }

  /// كل جهات الثقة التي يجب إبلاغها فوراً عند حالة طوارئ (كل المستويات
  /// تشمل هذا الإبلاغ، حتى لو لم تُمنح مراقبة يومية).
  List<TrustedContact> emergencyNotificationList() =>
      List.unmodifiable(_contacts);

  List<TrustedContact> remoteMonitoringAllowedList() {
    return _contacts
        .where((c) =>
            c.permission == TrustedContactPermission.remoteMonitoring ||
            c.permission == TrustedContactPermission.fullDelegate)
        .toList();
  }
}
