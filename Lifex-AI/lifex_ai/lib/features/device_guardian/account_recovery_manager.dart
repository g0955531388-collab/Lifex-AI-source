/// =============================================================
/// Lifex-AI — حماية الجهاز واستعادة الحساب
/// الملف: account_recovery_manager.dart
/// المسار: lib/features/device_guardian/account_recovery_manager.dart
/// الوصف: إجراءات استعادة الحساب بعد فقدان الجهاز — عبر التحقق البديل
/// (رقم هاتف احتياطي، جهة ثقة) بدلاً من الاعتماد على الجهاز المفقود فقط.
/// =============================================================
library;

enum RecoveryUrgency { normal, urgentTheftSuspected }

class RecoveryRequest {
  final String requestId;
  final String deviceId;
  final RecoveryUrgency urgency;
  bool completed;
  final DateTime createdAt;

  RecoveryRequest({
    required this.requestId,
    required this.deviceId,
    required this.urgency,
    this.completed = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// مدير استعادة الحساب.
class AccountRecoveryManager {
  AccountRecoveryManager();

  final List<RecoveryRequest> _requests = [];
  int _counter = 0;

  /// وضع علامة استعادة عاجلة على جهاز مُبلَّغ عنه كمسروق تحديداً (وليس
  /// مجرد مفقود)، لتفعيل مسار استعادة أسرع لاحقاً في طبقة الخادم.
  RecoveryRequest flagUrgentRecoveryNeeded(
    String deviceId, {
    required bool wasStolen,
  }) {
    _counter++;
    final request = RecoveryRequest(
      requestId: 'REC-$_counter',
      deviceId: deviceId,
      urgency: wasStolen
          ? RecoveryUrgency.urgentTheftSuspected
          : RecoveryUrgency.normal,
    );
    _requests.add(request);
    return request;
  }

  bool completeRecovery(String requestId) {
    final matches = _requests.where((r) => r.requestId == requestId).toList();
    if (matches.isEmpty) return false;
    matches.first.completed = true;
    return true;
  }

  List<RecoveryRequest> get pendingRequests =>
      _requests.where((r) => !r.completed).toList();
}
